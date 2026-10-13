import WidgetKit
import SwiftUI

struct StreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let readToday: Bool
    let week: [WidgetData.WeekDay]
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        let sample: Set<String> = Set((0..<5).map { WidgetData.dayString(WidgetData.addDays(-$0, to: .now)) })
        return entry(at: .now, days: sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(entry(at: .now, days: WidgetData.readDays))
    }

    /// Entries for now and the next two midnights, so "read today", the streak,
    /// and the week strip roll over on time even if the app never opens.
    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let days = WidgetData.readDays
        let first = WidgetData.nextMidnight(after: .now)
        let dates = [Date.now, first, WidgetData.nextMidnight(after: first)]
        completion(Timeline(entries: dates.map { entry(at: $0, days: days) }, policy: .atEnd))
    }

    private func entry(at date: Date, days: Set<String>) -> StreakEntry {
        StreakEntry(date: date,
                    streak: WidgetData.streak(asOf: date, days: days),
                    readToday: days.contains(WidgetData.dayString(date)),
                    week: WidgetData.week(containing: date, days: days))
    }
}

struct StreakWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StreakEntry

    var body: some View {
        content
            .containerBackground(WidgetPalette.background, for: .widget)
            .widgetURL(WidgetShared.Link.story(WidgetData.catalog.index(for: entry.date)))
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
        case .systemMedium:
            HStack(spacing: 14) {
                streakBlock
                    .frame(width: 92)
                weekStrip
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        default:
            streakBlock
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var streakBlock: some View {
        VStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(.system(size: 30))
                .foregroundStyle(WidgetPalette.accent)
            Text("\(entry.streak)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("day streak")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text(entry.readToday ? "Read today ✓" : "Not read yet")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(entry.readToday ? WidgetPalette.accent : .secondary)
                .padding(.top, 2)
        }
    }

    /// The Read tab's Mon → Sun strip: green when read, accent outline for an
    /// unread today, days still to come dimmed.
    private var weekStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetCaption(text: "This week")
            HStack(spacing: 5) {
                ForEach(Array(entry.week.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 4) {
                        Text(day.letter)
                            .font(.system(size: 10, weight: day.isToday ? .bold : .semibold))
                            .foregroundStyle(day.isToday ? WidgetPalette.accent : .secondary)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(day.read ? WidgetPalette.green : (day.isToday ? .clear : WidgetPalette.heatEmpty))
                            .overlay {
                                if day.isToday && !day.read {
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(WidgetPalette.accent, lineWidth: 2)
                                }
                            }
                            .overlay {
                                if day.read {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(height: 34)
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(day.isFuture ? 0.4 : 1)
                }
            }
        }
    }
}

struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetShared.Kind.streak, provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Reading Streak")
        .description("Your day streak — the medium size adds this week's reading days.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryInline])
    }
}
