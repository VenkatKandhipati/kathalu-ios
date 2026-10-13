import WidgetKit
import SwiftUI

struct LetterEntry: TimelineEntry {
    let date: Date
    let akshara: Akshara
    let group: AksharaGroup
}

struct LetterProvider: TimelineProvider {
    func placeholder(in context: Context) -> LetterEntry { entry(at: .now) }

    func getSnapshot(in context: Context, completion: @escaping (LetterEntry) -> Void) {
        completion(entry(at: .now))
    }

    /// Today's letter, then tomorrow's at midnight.
    func getTimeline(in context: Context, completion: @escaping (Timeline<LetterEntry>) -> Void) {
        let midnight = WidgetData.nextMidnight(after: .now)
        completion(Timeline(entries: [entry(at: .now), entry(at: midnight)], policy: .atEnd))
    }

    private func entry(at date: Date) -> LetterEntry {
        let pick = WidgetData.letter(for: date)
        return LetterEntry(date: date, akshara: pick.akshara, group: pick.group)
    }
}

struct LetterWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LetterEntry

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(WidgetPalette.background, for: .widget)
            .widgetURL(WidgetShared.Link.letter(entry.akshara.letter))
    }

    @ViewBuilder private var content: some View {
        if family == .systemMedium {
            HStack(spacing: 16) {
                glyph(size: 72)
                    .frame(width: 110)
                VStack(alignment: .leading, spacing: 4) {
                    WidgetCaption(text: "Letter of the day")
                    Text(entry.akshara.trans)
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .foregroundStyle(WidgetPalette.accent)
                    Text(entry.akshara.soundHint)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                    Text("\(entry.group.telugu) · \(entry.group.name)")
                        .font(.system(size: 10.5, design: .serif).italic())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        } else {
            VStack(spacing: 2) {
                WidgetCaption(text: "Letter of the day")
                glyph(size: 58)
                Text(entry.akshara.trans)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(WidgetPalette.accent)
            }
        }
    }

    private func glyph(size: CGFloat) -> some View {
        Text(entry.akshara.letter)
            .font(WidgetPalette.telugu(size).weight(.bold))
            .foregroundStyle(.primary)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }
}

struct LetterWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetShared.Kind.letter, provider: LetterProvider()) { entry in
            LetterWidgetView(entry: entry)
        }
        .configurationDisplayName("Letter of the Day")
        .description("One Telugu letter a day, through the whole alphabet. Tap to hear it.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
