import Foundation

/// What a daily reminder says. Days alternate between two kinds, both drawn
/// from that day's story:
///
/// - **word**: one short word from the story with its dictionary meaning
/// - **story**: just the story's name and reading time
///
/// On streak milestones (the next reminder only — later days' streaks aren't
/// known yet) the title becomes "Day N 📖" and the rotated content moves into
/// the body. Picks are a pure function of the date, so rescheduling never
/// changes a day's message.
struct ReminderContent {
    enum Kind: CaseIterable { case word, story }

    let title: String
    let body: String

    static let milestones: Set<Int> = [7, 14, 30, 50, 100, 150, 200, 250, 300, 365, 500, 730, 1000]

    static func make(for date: Date, story: Story, milestone: Int? = nil, kind: Kind? = nil) -> ReminderContent {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        let kind = kind ?? Kind.allCases[day % Kind.allCases.count]
        let content = (kind == .word ? word(from: story, day: day) : nil) ?? storyCard(story)
        guard let milestone else { return content }
        return ReminderContent(title: "Day \(milestone) 📖", body: content.title + "\n" + content.body)
    }

    /// e.g. **పాపం · pāpaṁ** / "poor thing!" — from The Crow and the Swans
    private static func word(from story: Story, day: Int) -> ReminderContent? {
        var seen = Set<String>()
        // Short words (2–4 letters) with a one- or two-word meaning.
        let candidates = story.words.filter { word in
            guard (2...4).contains(word.count), seen.insert(word).inserted,
                  let meaning = DictionaryService.entry(for: word)?.meaning else { return false }
            return meaning.split(separator: " ").count <= 2
        }
        guard !candidates.isEmpty else { return nil }
        let word = candidates[(day * 7) % candidates.count]
        let meaning = DictionaryService.entry(for: word)?.meaning ?? ""
        return ReminderContent(
            title: "\(word) · \(Transliterator.transliterate(word))",
            body: "“\(meaning)” — from \(story.titleEn)")
    }

    /// e.g. **Today's story** / The Crow and the Swans · 7 min
    private static func storyCard(_ story: Story) -> ReminderContent {
        ReminderContent(title: "Today's story", body: "\(story.titleEn) · \(story.readingMinutes) min")
    }
}
