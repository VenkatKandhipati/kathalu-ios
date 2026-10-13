import WidgetKit
import SwiftUI

struct SentenceEntry: TimelineEntry {
    let date: Date
    let pick: WidgetData.Pick?
    let showRomanization: Bool
}

struct SentenceProvider: AppIntentTimelineProvider {
    private static let slotHours = 6

    func placeholder(in context: Context) -> SentenceEntry {
        SentenceEntry(date: .now, pick: WidgetData.sentencePool.first, showRomanization: true)
    }

    func snapshot(for configuration: SentenceWidgetConfig, in context: Context) async -> SentenceEntry {
        entry(at: .now, config: configuration)
    }

    /// A new sentence every 6 hours, fixed per slot like the word widget.
    func timeline(for configuration: SentenceWidgetConfig, in context: Context) async -> Timeline<SentenceEntry> {
        let dates = SlotPicker.entryDates(from: .now, hours: Self.slotHours, count: 4)
        return Timeline(entries: dates.map { entry(at: $0, config: configuration) }, policy: .atEnd)
    }

    private func entry(at date: Date, config: SentenceWidgetConfig) -> SentenceEntry {
        let pool = WidgetData.sentencePool
        let slot = SlotPicker.slot(for: date, hours: Self.slotHours)
        let pick = pool.isEmpty ? nil : pool[SlotPicker.index(slot: slot, salt: 0x5E57, count: pool.count)]
        return SentenceEntry(date: date, pick: pick, showRomanization: config.showRomanization)
    }
}

struct SentenceWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SentenceEntry

    private var large: Bool { family == .systemLarge }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetCaption(text: "Sentence to read")
            // Spacers on both sides center the sentence between the caption and
            // the footer instead of leaving an empty band at the bottom.
            Spacer(minLength: large ? 10 : 4)
            VStack(alignment: .leading, spacing: large ? 12 : 6) {
                Text(entry.pick?.text ?? "కథలు చదువుదాం.")
                    .font(WidgetPalette.telugu(large ? 26 : 19).weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineSpacing(large ? 6 : 2)
                    .minimumScaleFactor(0.55)
                    .lineLimit(large ? 7 : 3)
                if entry.showRomanization, let pick = entry.pick {
                    Text(pick.trans)
                        .font(.system(size: large ? 15 : 12, weight: .medium, design: .serif))
                        .foregroundStyle(WidgetPalette.accent)
                        .minimumScaleFactor(0.7)
                        .lineLimit(large ? 5 : 2)
                }
            }
            Spacer(minLength: large ? 10 : 4)
            if let story = entry.pick?.story {
                Text("from “\(story)”")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(WidgetPalette.background, for: .widget)
        .widgetURL(WidgetShared.Link.story(entry.pick?.storyIndex ?? 0))
    }
}

struct SentenceWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetShared.Kind.sentence, intent: SentenceWidgetConfig.self, provider: SentenceProvider()) { entry in
            SentenceWidgetView(entry: entry)
        }
        .configurationDisplayName("Sentence to Read")
        .description("A full sentence from the stories. Edit the widget to hide romanization.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
