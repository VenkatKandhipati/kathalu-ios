import SwiftUI

/// Library home: streak, week strip, today's story hero card, bookshelf.
struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedStory: Story?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    WeekStripView(days: model.weekStrip)
                        .padding(.vertical, 20)
                    if let today = model.storyStore.today {
                        TodayStoryCard(story: today) { selectedStory = today }
                            .padding(.bottom, 26)
                    }
                    Text("ALL STORIES")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.7)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.bottom, 16)
                    BookshelfView(
                        stories: model.storyStore.stories,
                        progress: model.data.storyProgress,
                        onSelect: { selectedStory = $0 })
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .fullScreenCover(item: $selectedStory) { story in
                ReaderView(story: story)
            }
            .onAppear {
                #if DEBUG
                // Debug hook: `simctl launch … -openStory 0` opens a story at launch.
                if let raw = UserDefaults.standard.string(forKey: "openStory"),
                   let idx = Int(raw), let story = model.story(at: idx) {
                    UserDefaults.standard.removeObject(forKey: "openStory")
                    selectedStory = story
                }
                #endif
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Library")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Theme.textHeading)
                Text("పుస్తకాలయం")
                    .font(Theme.sans(14))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            if model.data.streak > 0 {
                StreakBadge(count: model.data.streak)
                    .padding(.top, 8)
            }
        }
    }
}

struct StreakBadge: View {
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14))
            Text("\(count)")
                .font(.system(size: 15, weight: .bold))
        }
        .foregroundStyle(Theme.accent)
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(Theme.accent.opacity(0.1))
        .clipShape(Capsule())
    }
}

/// Trailing 7 days; green when read, outlined accent for an unread today.
struct WeekStripView: View {
    let days: [(day: DayStamp, didRead: Bool, isToday: Bool)]
    private let letters = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.day) { entry in
                VStack(spacing: 5) {
                    Text(letters[(Calendar.current.component(.weekday, from: entry.day.date) - 1) % 7])
                        .font(.system(size: 10, weight: entry.isToday ? .bold : .semibold))
                        .foregroundStyle(entry.isToday ? Theme.accent : Theme.textTertiary)
                    Text("\(entry.day.day)")
                        .font(.system(size: 11, weight: entry.isToday ? .bold : .semibold))
                        .foregroundStyle(cellForeground(entry))
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(cellBackground(entry))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .overlay {
                            if entry.isToday && !entry.didRead {
                                RoundedRectangle(cornerRadius: 7)
                                    .strokeBorder(Theme.accent, lineWidth: 2)
                            }
                        }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func cellBackground(_ entry: (day: DayStamp, didRead: Bool, isToday: Bool)) -> Color {
        entry.didRead ? Theme.green : (entry.isToday ? .clear : Theme.heatEmpty)
    }

    private func cellForeground(_ entry: (day: DayStamp, didRead: Bool, isToday: Bool)) -> Color {
        if entry.didRead { return .white }
        return entry.isToday ? Theme.accent : Theme.textTertiary
    }
}

/// The accent-gradient "Today's story" hero card.
struct TodayStoryCard: View {
    let story: Story
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                Text("నేటి కథ · Today's story")
                    .font(Theme.sans(11))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom, 12)
                Text(story.title)
                    .font(Theme.serif(24, weight: .bold))
                    .foregroundStyle(.white)
                Text(story.titleEn)
                    .font(Theme.latinSerif(14))
                    .italic()
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 3)
                HStack(alignment: .bottom) {
                    Text("\(story.collection) · \(story.wordCount) పదాలు · \(story.readingMinutes) min")
                        .font(Theme.sans(12.5))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 44, height: 44)
                        .background(.white, in: Circle())
                }
                .padding(.top, 18)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Theme.accent, Theme.accentDeep],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: 130, height: 130)
                    .offset(x: 30, y: -30)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: Theme.accent.opacity(0.5), radius: 17, y: 9)
        }
        .buttonStyle(.plain)
    }
}

/// The wooden bookshelf of story spines.
struct BookshelfView: View {
    let stories: [Story]
    let progress: [Int: StoryProgressEntry]
    let onSelect: (Story) -> Void

    private let spineHeights: [CGFloat] = [148, 168, 158, 172, 150, 164]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 11) {
                    ForEach(stories) { story in
                        BookSpineView(
                            story: story,
                            height: spineHeights[story.index % spineHeights.count],
                            bestPct: progress[story.index]?.bestPct)
                        .onTapGesture { onSelect(story) }
                    }
                }
                .padding(.horizontal, 4)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
            }
            // Wooden shelf plank.
            LinearGradient(
                colors: [Color(red: 0.71, green: 0.57, blue: 0.35), Color(red: 0.53, green: 0.41, blue: 0.24)],
                startPoint: .top, endPoint: .bottom)
                .frame(height: 13)
                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4))
                .shadow(color: .black.opacity(0.3), radius: 5, y: 5)
        }
    }
}

struct BookSpineView: View {
    let story: Story
    let height: CGFloat
    let bestPct: Int?

    var body: some View {
        VStack(spacing: 0) {
            Text(story.titleEn)
                .font(Theme.latinSerif(11, weight: .semibold))
                .lineLimit(2)
                .rotationEffect(.degrees(90))
                .fixedSize()
                .frame(maxHeight: .infinity)
            Text("✦")
                .font(.system(size: 10))
                .opacity(0.5)
                .padding(.bottom, 12)
        }
        .foregroundStyle(.white.opacity(0.9))
        .frame(width: 44, height: height)
        .background(Theme.spineGradient(for: story.index))
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 3, bottomLeadingRadius: 3,
            bottomTrailingRadius: 6, topTrailingRadius: 6))
        .shadow(color: .black.opacity(0.24), radius: 4, x: 2, y: 3)
        .overlay(alignment: .bottomTrailing) {
            if let pct = bestPct {
                ProficiencyRing(pct: pct, size: 20, lineWidth: 3)
                    .background(Circle().fill(Theme.card).padding(-2))
                    .offset(x: 5, y: 5)
            }
        }
    }
}

/// Small circular progress badge; color follows the web app's thresholds.
struct ProficiencyRing: View {
    let pct: Int
    var size: CGFloat = 20
    var lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.heatEmpty, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(pct) / 100)
                .stroke(Theme.ringColor(pct: pct), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    LibraryView()
        .environment(AppModel())
}
