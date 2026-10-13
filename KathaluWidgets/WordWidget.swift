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
    private static let slotHours = 1

    func placeholder(in context: Context) -> WordEntry {
        WordEntry(date: .now, pick: nil, showRomanization: true)
    }

    func snapshot(for configuration: WordWidgetConfig, in context: Context) async -> WordEntry {
        entry(at: .now, config: configuration)
    }

    /// A new word every hour over the next half-day. Each pick is fixed by its
    /// slot, so reloads don't reshuffle the word on screen.
    func timeline(for configuration: WordWidgetConfig, in context: Context) async -> Timeline<WordEntry> {
        let dates = SlotPicker.entryDates(from: .now, hours: Self.slotHours, count: 12)
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
            // Lock Screen: the system renders it monochrome, so no custom
            // colors. The slot's size is fixed — scale the text up to fill it.
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.word)
                    .font(WidgetPalette.telugu(34).weight(.bold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                if entry.showRomanization {
                    Text(entry.trans)
                        .font(.system(size: 17, weight: .medium, design: .serif))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
        .description("A new Telugu word from the stories every hour. Edit the widget to hide romanization.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
