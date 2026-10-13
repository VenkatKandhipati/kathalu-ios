import WidgetKit
import SwiftUI
import UIKit

// MARK: - Palette (mirrors Theme in the app; Theme itself isn't shared)

enum WidgetPalette {
    static let accent = dynamic(light: (0.71, 0.33, 0.10), dark: (0.83, 0.45, 0.23))      // #B5531A / #D4743A
    static let accentDeep = dynamic(light: (0.60, 0.25, 0.07), dark: (0.71, 0.37, 0.16))  // #983F13 / #B55E28
    static let background = dynamic(light: (0.96, 0.94, 0.89), dark: (0.10, 0.10, 0.10))
    static let green = dynamic(light: (0.42, 0.56, 0.23), dark: (0.54, 0.71, 0.31))       // #6B8F3A / #8AB450
    static let heatEmpty = dynamic(light: (0.91, 0.87, 0.80), dark: (0.23, 0.22, 0.18))   // #E7DECB / #3A372F

    static func telugu(_ size: CGFloat) -> Font { .custom("Noto Serif Telugu", size: size) }

    private static func dynamic(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
}

// MARK: - Deterministic slot picks

/// Timelines get reloaded often (the app reloads data-driven widgets on every
/// change, the system reloads on its own budget). Picks are a pure function of
/// the time slot, so a reload inside the same slot shows the same word/sentence
/// instead of reshuffling under the user.
enum SlotPicker {
    static func slot(for date: Date, hours: Int) -> Int {
        Int(date.timeIntervalSince1970 / Double(hours * 3600))
    }

    static func start(ofSlot slot: Int, hours: Int) -> Date {
        Date(timeIntervalSince1970: Double(slot * hours * 3600))
    }

    /// SplitMix64 of (slot, salt) → index in 0..<count. Swift's `hashValue` is
    /// re-seeded per process, so it can't be used here.
    static func index(slot: Int, salt: UInt64, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var z = UInt64(bitPattern: Int64(slot)) &+ salt &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Int(z % UInt64(count))
    }

    /// Timeline entry dates: now, then the start of each following slot.
    static func entryDates(from now: Date, hours: Int, count: Int) -> [Date] {
        let first = slot(for: now, hours: hours)
        return [now] + (1..<count).map { start(ofSlot: first + $0, hours: hours) }
    }
}

// MARK: - Data

enum WidgetData {
    /// The bundled catalog, decoded once per extension process.
    static let catalog = StoryStore()

    // Reading days / streak — recomputed here from raw days (mirrors
    // UserData.streak) so the widget stays right past midnight.

    static var readDays: Set<String> {
        Set(WidgetShared.defaults?.stringArray(forKey: WidgetShared.Key.readDays) ?? [])
    }

    /// Matches DayStamp.description ("yyyy-MM-dd", current calendar).
    static func dayString(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func streak(asOf date: Date, days: Set<String>) -> Int {
        guard !days.isEmpty else { return 0 }
        var cursor = date
        if !days.contains(dayString(cursor)) {
            cursor = addDays(-1, to: cursor)      // streak survives until today is missed
            guard days.contains(dayString(cursor)) else { return 0 }
        }
        var count = 0
        while days.contains(dayString(cursor)) {
            count += 1
            cursor = addDays(-1, to: cursor)
        }
        return count
    }

    struct WeekDay: Hashable {
        let letter: String
        let read: Bool
        let isToday: Bool
    }

    /// The trailing 7 days ending on `date`, oldest first (the Read tab's strip).
    static func week(endingOn date: Date, days: Set<String>) -> [WeekDay] {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return (0..<7).reversed().map { offset in
            let day = addDays(-offset, to: date)
            let weekday = Calendar.current.component(.weekday, from: day)
            return WeekDay(letter: symbols[weekday - 1], read: days.contains(dayString(day)), isToday: offset == 0)
        }
    }

    static func nextMidnight(after date: Date) -> Date {
        Calendar.current.startOfDay(for: addDays(1, to: date))
    }

    static func addDays(_ n: Int, to date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: n, to: date) ?? date
    }

    static func bestPct(storyIndex: Int) -> Int? {
        let best = WidgetShared.defaults?.dictionary(forKey: WidgetShared.Key.storyBest) as? [String: Int]
        return best?[String(storyIndex)]
    }

    // Words & sentences mined from the stories.

    struct Pick: Hashable {
        let text: String
        let story: String
        let storyIndex: Int
        var trans: String { Transliterator.transliterate(text) }
    }

    static let wordPool: [Pick] = catalog.stories.flatMap { story in
        story.words.filter { $0.count >= 2 }.map { Pick(text: $0, story: story.titleEn, storyIndex: story.index) }
    }

    /// Readable sentences: 3–16 Telugu words, short enough for a widget.
    static let sentencePool: [Pick] = catalog.stories.flatMap { story in
        story.paragraphs.flatMap(sentences(in:)).compactMap { sentence in
            let words = TeluguText.words(in: sentence).count
            guard (3...16).contains(words), sentence.count <= 130 else { return nil }
            return Pick(text: sentence, story: story.titleEn, storyIndex: story.index)
        }
    }

    /// Splits a paragraph at . ! ? — but never inside quotes (dialogue stays
    /// whole), and ".." is a mid-sentence pause in these stories, not an end.
    static func sentences(in paragraph: String) -> [String] {
        let chars = Array(paragraph)
        var result: [String] = []
        var current = ""
        var quoteDepth = 0
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            current.append(ch)
            switch ch {
            case "‘", "“": quoteDepth += 1
            case "’", "”": quoteDepth = max(0, quoteDepth - 1)
            case "'", "\"": quoteDepth = quoteDepth > 0 ? quoteDepth - 1 : 1
            default: break
            }
            if ".!?".contains(ch) {
                var run = 1
                while i + 1 < chars.count, ".!?".contains(chars[i + 1]) {
                    i += 1
                    run += 1
                    current.append(chars[i])
                }
                let isEllipsis = run >= 2 && chars[i] == "."
                let atBreak = i + 1 >= chars.count || chars[i + 1].isWhitespace
                if quoteDepth == 0, !isEllipsis, atBreak {
                    result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                    current = ""
                }
            }
            i += 1
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { result.append(tail) }
        return result
    }

    // Letter of the Day — walks the alphabet one letter per day.

    static let alphabet: [(akshara: Akshara, group: AksharaGroup)] =
        ([AksharaData.vowels] + AksharaData.consonantGroups).flatMap { group in
            group.aksharas.map { (akshara: $0, group: group) }
        }

    static func letter(for date: Date) -> (akshara: Akshara, group: AksharaGroup) {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return alphabet[day % alphabet.count]
    }

    // Flashcards — the user's deck, else words from the stories.

    static var deck: [FlashcardSnapshot] {
        guard let data = WidgetShared.defaults?.data(forKey: WidgetShared.Key.flashcards),
              let cards = try? JSONDecoder().decode([FlashcardSnapshot].self, from: data)
        else { return [] }
        return cards
    }
}

// MARK: - Shared bits of chrome

/// Small uppercase caption used at the top of several widgets.
struct WidgetCaption: View {
    let text: String
    var color: Color = .secondary

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}
