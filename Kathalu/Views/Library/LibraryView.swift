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
                        .padding(.horizontal, -22)  // full-bleed shelf; inset restored inside
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

/// The wooden bookshelf of story spines, with a staggered pop-in and a
/// press-to-lift interaction. Books and plank scroll together as one shelf.
struct BookshelfView: View {
    let stories: [Story]
    let progress: [Int: StoryProgressEntry]
    let onSelect: (Story) -> Void

    private let spineHeights: [CGFloat] = [150, 172, 158, 176, 152, 166]
    private let sideInset: CGFloat = 22
    @State private var appeared = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(Array(stories.enumerated()), id: \.element.id) { idx, story in
                        Button {
                            onSelect(story)
                        } label: {
                            BookSpineView(
                                story: story,
                                height: spineHeights[story.index % spineHeights.count],
                                bestPct: progress[story.index]?.bestPct)
                        }
                        .buttonStyle(BookSpineButtonStyle())
                        .scaleEffect(appeared ? 1 : 0.72, anchor: .bottom)
                        .opacity(appeared ? 1 : 0)
                        .animation(
                            .spring(response: 0.55, dampingFraction: 0.7)
                                .delay(Double(idx) * 0.07),
                            value: appeared)
                    }
                }
                .padding(.horizontal, sideInset)
                .padding(.top, 16)

                shelfPlank
            }
        }
        .onAppear { appeared = true }
    }

    /// Wooden shelf plank with a lit top edge and a soft cast shadow.
    private var shelfPlank: some View {
        LinearGradient(
            colors: [Color(red: 0.74, green: 0.60, blue: 0.39),
                     Color(red: 0.53, green: 0.40, blue: 0.20)],
            startPoint: .top, endPoint: .bottom)
            .frame(height: 14)
            .overlay(alignment: .top) {
                LinearGradient(colors: [.white.opacity(0.35), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 3)
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .shadow(color: .black.opacity(0.28), radius: 7, y: 6)
            .padding(.horizontal, sideInset - 10)
    }
}

/// Lifts a book off the shelf when pressed, like pulling it out to open.
struct BookSpineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1, anchor: .bottom)
            .offset(y: configuration.isPressed ? -9 : 0)
            .animation(.spring(response: 0.32, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

struct BookSpineView: View {
    let story: Story
    let height: CGFloat
    let bestPct: Int?

    private let width: CGFloat = 48

    var body: some View {
        ZStack {
            // Spine body: colored gradient with a binding highlight and edge shading.
            Theme.spineGradient(for: story.index)
                .overlay(alignment: .leading) {
                    LinearGradient(colors: [.white.opacity(0.22), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: 7)
                }
                .overlay(alignment: .trailing) {
                    LinearGradient(colors: [.clear, .black.opacity(0.20)],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: 9)
                }
                .overlay(alignment: .top) {
                    Rectangle().fill(.white.opacity(0.16)).frame(height: 2)
                }

            // Rotated title: length constrained to the spine so it never overflows.
            Text(story.titleEn)
                .font(Theme.latinSerif(11.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.97))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .frame(width: height - 50, height: width - 8)
                .rotationEffect(.degrees(-90))
                .offset(y: -14)

            // Bottom emblem: reading-progress ring, or a small flourish.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                emblem.padding(.bottom, 11)
            }
        }
        .frame(width: width, height: height)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 4, bottomLeadingRadius: 4,
            bottomTrailingRadius: 7, topTrailingRadius: 7))
        .shadow(color: .black.opacity(0.24), radius: 5, x: 2, y: 4)
    }

    @ViewBuilder
    private var emblem: some View {
        if let pct = bestPct {
            ProficiencyRing(pct: pct, size: 22, lineWidth: 3)
                .padding(4)
                .background(Circle().fill(.black.opacity(0.22)))
        } else {
            Image(systemName: "sparkle")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 2)
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
