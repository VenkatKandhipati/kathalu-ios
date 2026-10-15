import SwiftUI

/// Library home: streak, week strip, graduation nudge, continue reading,
/// today's story (from the reader's level), then one bookshelf — shortest
/// stories first — that the level chips filter.
struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedStory: Story?
    /// nil = all levels.
    @State private var levelFilter: StoryLevel?
    @State private var unreadOnly = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    WeekStripView(days: model.weekStrip)
                        .padding(.vertical, 20)
                    if let graduation = model.graduation {
                        GraduationCard(from: graduation.from, to: graduation.to) {
                            withAnimation { model.dismissGraduation() }
                        }
                        .padding(.bottom, 18)
                    }
                    if !model.inProgressStories.isEmpty {
                        continueReading
                            .padding(.bottom, 22)
                    }
                    if let today = model.storyStore.today {
                        TodayStoryCard(story: today) { selectedStory = today }
                            .padding(.bottom, 26)
                    }
                    Text("ALL STORIES")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.7)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.bottom, 12)
                    filters
                        .padding(.bottom, 14)
                    shelf
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
            // A kathalu://story/<idx> deep link (widget or reminder) lands here;
            // `initial` catches one set during a cold launch, before this view.
            .onChange(of: model.deepLinkedStoryIndex, initial: true) { _, idx in
                if let idx, let story = model.story(at: idx) {
                    selectedStory = story
                    model.deepLinkedStoryIndex = nil
                }
            }
        }
    }

    // MARK: Continue reading

    private var continueReading: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CONTINUE READING")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.7)
                .foregroundStyle(Theme.textTertiary)
            ForEach(model.inProgressStories) { story in
                Button { selectedStory = story } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 34, height: 34)
                            .background(Theme.accent.opacity(0.1), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(story.title)
                                .font(Theme.serif(16, weight: .semibold))
                                .foregroundStyle(Theme.textHeading)
                                .lineLimit(1)
                            Text("\(story.titleEn) · \(continueLabel(story))")
                                .font(Theme.latinSerif(12.5))
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(12)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.cardBorder))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// "40% read" from the saved paragraph.
    private func continueLabel(_ story: Story) -> String {
        let total = max(1, story.paragraphs.count)
        let at = model.readingPosition(storyIdx: story.index) ?? 0
        return "\(Int((Double(at) / Double(total) * 100).rounded()))% read"
    }

    // MARK: Filters + shelves

    /// Levels that have at least one story.
    private var levels: [StoryLevel] {
        StoryLevel.allCases.filter { !model.storyStore.stories(at: $0).isEmpty }
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", selected: levelFilter == nil) { levelFilter = nil }
                ForEach(levels) { level in
                    chip("Level \(level.rawValue)", selected: levelFilter == level,
                         isYourLevel: level == model.currentLevel) {
                        levelFilter = levelFilter == level ? nil : level
                    }
                }
                Rectangle().fill(Theme.divider).frame(width: 1, height: 18)
                chip("Unread", selected: unreadOnly) { unreadOnly.toggle() }
            }
        }
        .scrollClipDisabled()
    }

    /// `isYourLevel` adds a small accent dot — the only "your level" marker.
    private func chip(_ title: String, selected: Bool, isYourLevel: Bool = false,
                      action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            HStack(spacing: 6) {
                if isYourLevel {
                    Circle()
                        .fill(selected ? .white : Theme.accent)
                        .frame(width: 6, height: 6)
                }
                Text(title)
            }
                .font(Theme.sans(13.5, weight: .medium))
                .foregroundStyle(selected ? .white : Theme.textSecondary)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(selected ? Theme.accent : Theme.card, in: Capsule())
                .overlay(Capsule().strokeBorder(selected ? Theme.accent : Theme.cardBorder))
        }
        .buttonStyle(.plain)
    }

    /// Shortest first (level, then length), narrowed by the chips.
    private var shelfStories: [Story] {
        model.storyStore.stories
            .filter { levelFilter == nil || $0.level == levelFilter }
            .filter { !unreadOnly || model.data.storyProgress[$0.index] == nil }
            .sorted { ($0.level.rawValue, $0.wordCount) < ($1.level.rawValue, $1.wordCount) }
    }

    @ViewBuilder
    private var shelf: some View {
        let stories = shelfStories
        if stories.isEmpty {
            Text(unreadOnly ? "You've read every story here." : "No stories here yet.")
                .font(Theme.sans(14))
                .foregroundStyle(Theme.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else {
            BookshelfView(
                stories: stories,
                progress: model.data.storyProgress,
                onSelect: { selectedStory = $0 })
                .padding(.horizontal, -22)  // full-bleed shelf; inset restored inside
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
                // The strip is the calendar week (Mon → Sun); days to come are dimmed.
                .opacity(entry.day > DayStamp.today ? 0.4 : 1)
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
                    Text("Level \(story.level.rawValue) · \(story.wordCount) పదాలు · \(story.readingMinutes) min")
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

/// "You've graduated" nudge after moving up a level. Nothing is locked —
/// it just points at the next shelf.
struct GraduationCard: View {
    let from: StoryLevel
    let to: StoryLevel
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("🎓")
                .font(.system(size: 28))
            VStack(alignment: .leading, spacing: 4) {
                Text("You've graduated from Level \(from.rawValue)!")
                    .font(Theme.latinSerif(16, weight: .semibold))
                    .foregroundStyle(Theme.textHeading)
                Text("You're ready for Level \(to.rawValue) · \(to.name) (\(to.lengthHint)). Today's story now comes from there.")
                    .font(Theme.sans(13.5))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Theme.gold.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.gold.opacity(0.5)))
    }
}

/// The wooden bookshelf of story spines, with a staggered pop-in and a
/// press-to-lift interaction. Books and plank scroll together as one shelf.
struct BookshelfView: View {
    let stories: [Story]
    let progress: [Int: StoryProgressEntry]
    let onSelect: (Story) -> Void

    @Environment(\.horizontalSizeClass) private var hSize

    private let spineHeights: [CGFloat] = [150, 172, 158, 176, 152, 166]
    private let baseSpineWidth: CGFloat = 48
    private let baseSpacing: CGFloat = 10
    private let sideInset: CGFloat = 22
    @State private var appeared = false

    /// Books are scaled up on iPad so the shelf feels substantial instead of
    /// huddling in a corner; iPhone keeps the original 1× proportions.
    private var scale: CGFloat { hSize == .regular ? 1.4 : 1 }

    var body: some View {
        Group {
            if hSize == .regular {
                // Centered on iPad: `minWidth: viewport` centers the shelf when
                // it fits and still scrolls if the library outgrows the width.
                GeometryReader { geo in
                    ScrollView(.horizontal, showsIndicators: false) {
                        shelf
                            .frame(minWidth: geo.size.width)
                    }
                }
                .frame(height: shelfHeight)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    shelf
                }
            }
        }
        .onAppear { appeared = true }
    }

    private var shelf: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: baseSpacing * scale) {
                ForEach(Array(stories.enumerated()), id: \.element.id) { idx, story in
                    Button {
                        onSelect(story)
                    } label: {
                        BookSpineView(
                            story: story,
                            height: spineHeights[story.index % spineHeights.count] * scale,
                            bestPct: progress[story.index]?.bestPct,
                            scale: scale)
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

    /// Natural width of the books row (spines + spacing + side insets). Giving
    /// the plank an explicit width keeps the shelf a definite size, so the
    /// `minWidth` centering can't balloon the plank to full width.
    private var booksRowWidth: CGFloat {
        let n = CGFloat(stories.count)
        return n * baseSpineWidth * scale + max(0, n - 1) * baseSpacing * scale + sideInset * 2
    }

    private var shelfHeight: CGFloat {
        (spineHeights.max() ?? 176) * scale + 16 + 14 * scale + 16
    }

    /// Wooden shelf plank with a lit top edge and a soft cast shadow.
    private var shelfPlank: some View {
        LinearGradient(
            colors: [Color(red: 0.74, green: 0.60, blue: 0.39),
                     Color(red: 0.53, green: 0.40, blue: 0.20)],
            startPoint: .top, endPoint: .bottom)
            .frame(width: booksRowWidth - 24, height: 14 * scale)
            .overlay(alignment: .top) {
                LinearGradient(colors: [.white.opacity(0.35), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 3)
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .shadow(color: .black.opacity(0.28), radius: 7, y: 6)
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
    var scale: CGFloat = 1

    private var width: CGFloat { 48 * scale }

    var body: some View {
        ZStack {
            // Spine body: colored gradient with a binding highlight and edge shading.
            Theme.spineGradient(for: story.index)
                .overlay(alignment: .leading) {
                    LinearGradient(colors: [.white.opacity(0.22), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: 7 * scale)
                }
                .overlay(alignment: .trailing) {
                    LinearGradient(colors: [.clear, .black.opacity(0.20)],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: 9 * scale)
                }
                .overlay(alignment: .top) {
                    Rectangle().fill(.white.opacity(0.16)).frame(height: 2)
                }

            // Rotated title: length constrained to the spine so it never overflows.
            Text(story.titleEn)
                .font(Theme.latinSerif(11.5 * scale, weight: .semibold))
                .foregroundStyle(.white.opacity(0.97))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .frame(width: height - 50 * scale, height: width - 8 * scale)
                .rotationEffect(.degrees(-90))
                .offset(y: -14 * scale)

            // Bottom emblem: reading-progress ring, or a small flourish.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                emblem.padding(.bottom, 11 * scale)
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
            ProficiencyRing(pct: pct, size: 22 * scale, lineWidth: 3 * scale)
                .padding(4 * scale)
                .background(Circle().fill(.black.opacity(0.22)))
        } else {
            Image(systemName: "sparkle")
                .font(.system(size: 10 * scale))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 2 * scale)
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
