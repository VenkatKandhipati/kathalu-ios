import WidgetKit
import SwiftUI

struct WordEntry: TimelineEntry {
    let date: Date
    let pick: WidgetData.Pick?
    let showRomanization: Bool

    var word: String { pick?.text ?? "కథ" }
    var trans: String { pick?.trans ?? "katha" }
}

struct WordProvider: AppIntentTimelineProvider {
    private static let slotHours = 3

    func placeholder(in context: Context) -> WordEntry {
        WordEntry(date: .now, pick: nil, showRomanization: false)
    }

    func snapshot(for configuration: WordWidgetConfig, in context: Context) async -> WordEntry {
        entry(at: .now, config: configuration)
    }

    /// A new word every 3 hours over the next half-day. Each pick is fixed by
    /// its slot, so reloads don't reshuffle the word on screen.
    func timeline(for configuration: WordWidgetConfig, in context: Context) async -> Timeline<WordEntry> {
        let dates = SlotPicker.entryDates(from: .now, hours: Self.slotHours, count: 5)
        return Timeline(entries: dates.map { entry(at: $0, config: configuration) }, policy: .atEnd)
    }

    private func entry(at date: Date, config: WordWidgetConfig) -> WordEntry {
        let pool = WidgetData.wordPool
        let slot = SlotPicker.slot(for: date, hours: Self.slotHours)
        let pick = pool.isEmpty ? nil : pool[SlotPicker.index(slot: slot, salt: 0xA11CE, count: pool.count)]
        return WordEntry(date: date, pick: pick, showRomanization: config.showRomanization)
    }
}

struct WordWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordEntry

    var body: some View {
        content
            .containerBackground(WidgetPalette.background, for: .widget)
            .widgetURL(WidgetShared.Link.story(entry.pick?.storyIndex ?? 0))
    }

    @ViewBuilder private var content: some View {
        if family == .accessoryRectangular {
            // Lock Screen: rendered monochrome by the system, so no custom colors.
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.word)
                    .font(WidgetPalette.telugu(22).weight(.bold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                if entry.showRomanization {
                    Text(entry.trans)
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .lineLimit(1)
                } else {
                    Text("Word to read")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            let medium = family == .systemMedium
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
                if medium, let story = entry.pick?.story {
                    Text("from “\(story)”")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct WordWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetShared.Kind.word, intent: WordWidgetConfig.self, provider: WordProvider()) { entry in
            WordWidgetView(entry: entry)
        }
        .configurationDisplayName("Word to Read")
        .description("A Telugu word from the stories. Edit the widget to show romanization.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
