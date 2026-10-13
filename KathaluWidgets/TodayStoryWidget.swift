import WidgetKit
import SwiftUI

struct TodayStoryEntry: TimelineEntry {
    let date: Date
    let story: Story?
    let bestPct: Int?
}

struct TodayStoryProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayStoryEntry {
        TodayStoryEntry(date: .now, story: WidgetData.catalog.stories.first, bestPct: 72)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayStoryEntry) -> Void) {
        completion(entry(at: .now))
    }

    /// Today's story, then tomorrow's at midnight (same dayOfYear rule as the app).
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayStoryEntry>) -> Void) {
        let midnight = WidgetData.nextMidnight(after: .now)
        completion(Timeline(entries: [entry(at: .now), entry(at: midnight)], policy: .atEnd))
    }

    private func entry(at date: Date) -> TodayStoryEntry {
        let catalog = WidgetData.catalog
        let index = catalog.index(for: date)
        let story = catalog.stories.indices.contains(index) ? catalog.stories[index] : nil
        return TodayStoryEntry(date: date, story: story, bestPct: story.flatMap { WidgetData.bestPct(storyIndex: $0.index) })
    }
}

struct TodayStoryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayStoryEntry

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            details
            if family == .systemMedium {
                Spacer(minLength: 0)
                scoreRing
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            LinearGradient(colors: [WidgetPalette.accent, WidgetPalette.accentDeep],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .widgetURL(WidgetShared.Link.story(entry.story?.index ?? 0))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 3) {
            WidgetCaption(text: "నేటి కథ · Today", color: .white.opacity(0.8))
                .padding(.bottom, 3)
            Text(entry.story?.title ?? "కథలు")
                .font(WidgetPalette.telugu(family == .systemMedium ? 22 : 18).weight(.bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(2)
            Text(entry.story?.titleEn ?? "")
                .font(.system(size: 12, design: .serif).italic())
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(meta)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
        }
    }

    private var meta: String {
        guard let story = entry.story else { return "" }
        return family == .systemMedium
            ? "\(story.collection) · \(story.readingMinutes) min"
            : "\(story.readingMinutes) min read"
    }

    /// Best proficiency ring (read without help), or a "New" badge if unread.
    private var scoreRing: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.25), lineWidth: 7)
            if let pct = entry.bestPct {
                Circle()
                    .trim(from: 0, to: CGFloat(pct) / 100)
                    .stroke(.white, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(pct)%").font(.system(size: 17, weight: .bold, design: .rounded))
                    Text("best").font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(.white)
            } else {
                Text("New")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 70, height: 70)
    }
}

struct TodayStoryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetShared.Kind.todayStory, provider: TodayStoryProvider()) { entry in
            TodayStoryWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Story")
        .description("The story of the day, with your best score. Tap to start reading.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
