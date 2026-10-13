import WidgetKit
import SwiftUI
import UIKit

// MARK: - Shared data

/// The widget's view of app data: the streak (via the shared App Group) and a
/// random word mined from the bundled story corpus (no App Group needed — the
/// widget target bundles its own copy of stories.json).
enum WidgetData {
    static let appGroupID = "group.me.kathalu.app"

    static func streak() -> (streak: Int, readToday: Bool) {
        let defaults = UserDefaults(suiteName: appGroupID)
        return (defaults?.integer(forKey: "streak") ?? 0,
                defaults?.bool(forKey: "readToday") ?? false)
    }

    static func stories() -> [Story] {
        guard let url = Bundle.main.url(forResource: "stories", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              var list = try? JSONDecoder().decode([Story].self, from: data)
        else { return [] }
        // Index == catalog order, matching StoryStore in the app, so deep links
        // (kathalu://story/<idx>) land on the right story.
        for i in list.indices { list[i].index = i }
        return list
    }

    static func randomWord() -> (word: String, trans: String, story: String, index: Int)? {
        let pool = stories().flatMap { story in
            story.words
                .filter { $0.count >= 2 }
                .map { (word: $0, story: story.titleEn, index: story.index) }
        }
        guard let pick = pool.randomElement() else { return nil }
        return (pick.word, Transliterator.transliterate(pick.word), pick.story, pick.index)
    }
}

// MARK: - Palette

private enum WidgetPalette {
    static let accent = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.83, green: 0.45, blue: 0.23, alpha: 1)   // #D4743A
        : UIColor(red: 0.71, green: 0.33, blue: 0.10, alpha: 1) }) // #B5531A
    static let background = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1)
        : UIColor(red: 0.96, green: 0.94, blue: 0.89, alpha: 1) })
    static func telugu(_ size: CGFloat) -> Font { .custom("Noto Serif Telugu", size: size) }
}

// MARK: - Streak widget

struct StreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let readToday: Bool
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: .now, streak: 5, readToday: true)
    }
    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        let s = WidgetData.streak()
        completion(StreakEntry(date: .now, streak: s.streak, readToday: s.readToday))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let s = WidgetData.streak()
        let entry = StreakEntry(date: .now, streak: s.streak, readToday: s.readToday)
        // Refresh just after midnight so "read today" visually resets.
        let next = Calendar.current.nextDate(after: .now,
            matching: DateComponents(hour: 0, minute: 5), matchingPolicy: .nextTime)
            ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct StreakWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StreakEntry

    var body: some View {
        content
            .containerBackground(WidgetPalette.background, for: .widget)
            .widgetURL(URL(string: "kathalu://story/0"))
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryInline:
            Label("\(entry.streak) day streak", systemImage: "flame.fill")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "flame.fill").font(.system(size: 12))
                    Text("\(entry.streak)").font(.system(size: 20, weight: .bold, design: .rounded))
                }
            }
        default:
            VStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(WidgetPalette.accent)
                Text("\(entry.streak)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("day streak")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(entry.readToday ? "Read today ✓" : "Not read yet")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(entry.readToday ? WidgetPalette.accent : .secondary)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KathaluStreak", provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Reading Streak")
        .description("Your current day streak.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryInline])
    }
}

// MARK: - Word-to-read widget

struct WordEntry: TimelineEntry {
    let date: Date
    let word: String
    let trans: String
    let story: String
    let index: Int
    let showRomanization: Bool
}

struct WordProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WordEntry {
        WordEntry(date: .now, word: "కథ", trans: "katha", story: "", index: 0, showRomanization: false)
    }
    func snapshot(for configuration: WordWidgetConfig, in context: Context) async -> WordEntry {
        make(configuration)
    }
    func timeline(for configuration: WordWidgetConfig, in context: Context) async -> Timeline<WordEntry> {
        // A fresh word every 3 hours across the next half-day.
        var entries: [WordEntry] = []
        for offset in stride(from: 0, through: 12, by: 3) {
            let date = Calendar.current.date(byAdding: .hour, value: offset, to: .now) ?? .now
            entries.append(make(configuration, date: date))
        }
        return Timeline(entries: entries, policy: .atEnd)
    }
    private func make(_ config: WordWidgetConfig, date: Date = .now) -> WordEntry {
        let w = WidgetData.randomWord()
        return WordEntry(date: date,
                         word: w?.word ?? "కథ",
                         trans: w?.trans ?? "katha",
                         story: w?.story ?? "",
                         index: w?.index ?? 0,
                         showRomanization: config.showRomanization)
    }
}

struct WordWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordEntry

    private var medium: Bool { family == .systemMedium }

    var body: some View {
        VStack(spacing: medium ? 8 : 5) {
            Text(entry.word)
                .font(WidgetPalette.telugu(medium ? 46 : 34).weight(.bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
            if entry.showRomanization {
                Text(entry.trans)
                    .font(.system(size: medium ? 16 : 13, weight: .medium, design: .serif))
                    .foregroundStyle(WidgetPalette.accent)
                    .lineLimit(1)
            }
            if medium, !entry.story.isEmpty {
                Text("from “\(entry.story)”")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(WidgetPalette.background, for: .widget)
        .widgetURL(URL(string: "kathalu://story/\(entry.index)"))
    }
}

struct WordWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "KathaluWord", intent: WordWidgetConfig.self, provider: WordProvider()) { entry in
            WordWidgetView(entry: entry)
        }
        .configurationDisplayName("Word to Read")
        .description("A random Telugu word from the stories. Edit the widget to show romanization.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
