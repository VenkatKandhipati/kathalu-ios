import SwiftUI

/// Immersive paged reader. Tap a word once for pronunciation (inline + voice),
/// tap again for the meaning sheet — matching the design's 1a + 1b flow.
struct ReaderView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    let story: Story

    @State private var pageIndex = 0
    @State private var revealedTokens: Set<ReaderPage.Token.ID> = []
    @State private var tappedWords: Set<String> = []
    @State private var sheetWord: WordSheetItem?
    @State private var didFinish = false
    /// 0…1 reading progress for the continuous scroll reader.
    @State private var scrollProgress: CGFloat = 0
    /// All story paragraphs tokenized once, for the scroll reader.
    @State private var scrollParagraphs: [[ReaderPage.Token]] = []
    /// One-time coach hint letting readers know the sound toggle lives in "Aa".
    @State private var showSoundTip = false
    /// Reading time banked from completed (active) segments this session.
    @State private var timerAccumulated: TimeInterval = 0
    /// Start of the current active segment; nil while paused (backgrounded).
    @State private var timerSegmentStart: Date?

    private var pages: [ReaderPage] {
        ReaderPage.paginate(story: story, fontSize: model.fontSize.points)
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            progressBar
            reader
            if model.readingMode == .paged {
                bottomBar
            }
        }
        .background(Theme.pageBackground.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            if showSoundTip { soundTip }
        }
        .sheet(item: $sheetWord) { item in
            WordSheetView(word: item.word, story: story)
                .presentationDetents([.height(400)])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            resumeTimer()
            guard !model.hasSeenSoundTip else { return }
            withAnimation(.spring(response: 0.4).delay(0.6)) { showSoundTip = true }
        }
        .onDisappear { pauseTimer() }
        .onChange(of: scenePhase) {
            if scenePhase == .active { resumeTimer() } else { pauseTimer() }
        }
    }

    // MARK: Reading timer

    /// Seconds spent actively reading this session (paused while backgrounded).
    private var timerElapsed: TimeInterval {
        timerAccumulated + (timerSegmentStart.map { Date().timeIntervalSince($0) } ?? 0)
    }

    private func resumeTimer() {
        guard timerSegmentStart == nil else { return }
        timerSegmentStart = Date()
    }

    private func pauseTimer() {
        guard let start = timerSegmentStart else { return }
        timerAccumulated += Date().timeIntervalSince(start)
        timerSegmentStart = nil
    }

    /// A muted, ticking stopwatch label — `m:ss`, rolling to `h:mm:ss` past an hour.
    private var readingTimer: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            Text(formatted(timerElapsed))
                .font(Theme.latinSerif(12))
                .monospacedDigit()
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private func formatted(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    /// A one-time callout under the "Aa" button explaining the sound toggle.
    /// Tapping it (or the auto-dismiss timer) marks it as seen.
    private var soundTip: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Word sound is on")
                    .font(Theme.latinSerif(13, weight: .semibold))
                    .foregroundStyle(Theme.textHeading)
                Text("Tap **Aa** to turn it off or on.")
                    .font(Theme.latinSerif(12))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.card)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.cardBorder))
        .frame(maxWidth: 230, alignment: .leading)
        .padding(.trailing, 12)
        .padding(.top, 4)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onTapGesture { dismissSoundTip() }
        .task {
            try? await Task.sleep(for: .seconds(5))
            dismissSoundTip()
        }
    }

    private func dismissSoundTip() {
        guard showSoundTip else { return }
        model.hasSeenSoundTip = true
        withAnimation(.easeOut(duration: 0.25)) { showSoundTip = false }
    }

    @ViewBuilder
    private var reader: some View {
        switch model.readingMode {
        case .paged: pagedReader
        case .scroll: scrollReader
        }
    }

    // MARK: Chrome

    private var navBar: some View {
        HStack {
            Button {
                finishIfNeeded()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 34, height: 34)
            }
            if model.showReadingTimer {
                readingTimer
            }
            Spacer()
            Text(story.title)
                .font(Theme.serif(14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            fontSizeMenu
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    private var fontSizeMenu: some View {
        Menu {
            Picker("Reading mode", selection: Binding(
                get: { model.readingMode },
                set: { model.readingMode = $0 })) {
                ForEach(AppModel.ReadingMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.systemImage).tag(mode)
                }
            }
            Divider()
            Picker("Reading font size", selection: Binding(
                get: { model.fontSize },
                set: { model.fontSize = $0 })) {
                ForEach(AppModel.ReadingFontSize.allCases) { size in
                    Text(size.label).tag(size)
                }
            }
            Divider()
            Toggle(isOn: Binding(
                get: { model.soundEnabled },
                set: { model.soundEnabled = $0 })) {
                Label("Pronounce words aloud", systemImage: "speaker.wave.2.fill")
            }
            Toggle(isOn: Binding(
                get: { model.showReadingTimer },
                set: { model.showReadingTimer = $0 })) {
                Label("Show reading timer", systemImage: "stopwatch")
            }
        } label: {
            Text("Aa")
                .font(Theme.latinSerif(13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 34, height: 30)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.divider))
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(Theme.accent)
                .frame(width: geo.size.width * progressFraction)
                .animation(.snappy, value: progressFraction)
        }
        .frame(height: 2)
        .background(Theme.divider)
    }

    /// Filled portion of the progress bar for the current reading mode.
    private var progressFraction: CGFloat {
        switch model.readingMode {
        case .paged: return CGFloat(pageIndex + 1) / CGFloat(max(1, pages.count))
        case .scroll: return scrollProgress
        }
    }

    /// Continuous, infinite-scroll reader (the default).
    private var scrollReader: some View {
        GeometryReader { outer in
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    titleBlock
                    ForEach(Array(scrollParagraphs.enumerated()), id: \.offset) { _, tokens in
                        paragraphView(tokens)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.top, 26)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    GeometryReader { content in
                        Color.clear.preference(
                            key: ScrollMetricsKey.self,
                            value: ScrollMetrics(
                                offset: content.frame(in: .named(Self.scrollSpace)).minY,
                                contentHeight: content.size.height))
                    })
            }
            .coordinateSpace(name: Self.scrollSpace)
            .onPreferenceChange(ScrollMetricsKey.self) { metrics in
                updateScrollProgress(metrics, viewportHeight: outer.size.height)
            }
        }
        .onAppear {
            if scrollParagraphs.isEmpty {
                scrollParagraphs = ReaderPage.allParagraphs(story: story)
            }
        }
    }

    private static let scrollSpace = "readerScroll"

    /// Derives reading progress from scroll offset; finishes the story once the
    /// bottom is reached (or immediately if the whole story fits on screen).
    private func updateScrollProgress(_ metrics: ScrollMetrics, viewportHeight: CGFloat) {
        guard metrics.contentHeight > 0 else { return }
        let scrollable = metrics.contentHeight - viewportHeight
        if scrollable <= 1 {
            scrollProgress = 1
            finishIfNeeded()
            return
        }
        let progress = min(1, max(0, -metrics.offset / scrollable))
        scrollProgress = progress
        if progress >= 0.99 { finishIfNeeded() }
    }

    private var pagedReader: some View {
        TabView(selection: $pageIndex) {
            ForEach(pages) { page in
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        if page.index == 0 { titleBlock }
                        ForEach(Array(page.paragraphs.enumerated()), id: \.offset) { _, tokens in
                            paragraphView(tokens)
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 26)
                    .padding(.bottom, 30)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .tag(page.index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: pageIndex) {
            if pageIndex == pages.count - 1 { finishIfNeeded() }
        }
        .onAppear {
            if pages.count == 1 { finishIfNeeded() }
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 4) {
            Text(story.title)
                .font(Theme.serif(22, weight: .bold))
                .foregroundStyle(Theme.textHeading)
            Text(story.titleEn)
                .font(Theme.latinSerif(14))
                .italic()
                .foregroundStyle(Theme.textSecondary)
            Text(story.collection)
                .font(Theme.serif(13))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 6)
    }

    private func paragraphView(_ tokens: [ReaderPage.Token]) -> some View {
        FlowLayout(horizontalSpacing: 0, verticalSpacing: model.fontSize.points * 0.9) {
            ForEach(tokens) { token in
                WordTokenView(
                    token: token,
                    fontSize: model.fontSize.points,
                    state: tokenState(token),
                    inDeck: token.teluguWord.map { model.data.cards[$0] != nil } ?? false)
                .onTapGesture { tap(token) }
            }
        }
    }

    private var bottomBar: some View {
        HStack {
            Button {
                withAnimation { pageIndex = max(0, pageIndex - 1) }
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18))
                    .foregroundStyle(pageIndex > 0 ? Theme.textSecondary : Theme.textTertiary.opacity(0.5))
                    .frame(width: 44, height: 44)
            }
            .disabled(pageIndex == 0)
            Spacer()
            Text("\(pageIndex + 1) / \(pages.count)")
                .font(Theme.latinSerif(13))
                .foregroundStyle(Theme.textTertiary)
            Spacer()
            Button {
                withAnimation { pageIndex = min(pages.count - 1, pageIndex + 1) }
            } label: {
                Image(systemName: "arrow.right")
                    .font(.system(size: 18))
                    .foregroundStyle(pageIndex < pages.count - 1 ? Theme.textSecondary : Theme.textTertiary.opacity(0.5))
                    .frame(width: 44, height: 44)
            }
            .disabled(pageIndex == pages.count - 1)
        }
        .padding(.horizontal, 20)
        .frame(height: 58)
        .background(Theme.pageBackground.opacity(0.92))
        .overlay(alignment: .top) { Divider().overlay(Theme.divider) }
    }

    // MARK: Interaction

    private func tokenState(_ token: ReaderPage.Token) -> WordTokenView.RevealState {
        revealedTokens.contains(token.id) ? .phonetic : .hidden
    }

    private func tap(_ token: ReaderPage.Token) {
        guard let word = token.teluguWord else { return }
        if revealedTokens.contains(token.id) {
            // Second tap: meaning sheet.
            sheetWord = WordSheetItem(word: word)
        } else {
            revealedTokens.insert(token.id)
            tappedWords.insert(word)
            model.recordLookup(word: word, storyIdx: story.index)
            if model.soundEnabled { model.speech.speak(word) }
        }
    }

    private func finishIfNeeded() {
        guard !didFinish else { return }
        didFinish = true
        let total = max(1, story.wordCount)
        let pct = max(0, 100 - Int((Double(tappedWords.count) / Double(total) * 100).rounded()))
        model.finishReading(storyIdx: story.index, proficiencyPct: pct)
    }
}

struct WordSheetItem: Identifiable {
    let word: String
    var id: String { word }
}

/// Scroll offset + total content height, used to compute reading progress.
private struct ScrollMetrics: Equatable {
    var offset: CGFloat
    var contentHeight: CGFloat
}

private struct ScrollMetricsKey: PreferenceKey {
    static let defaultValue = ScrollMetrics(offset: 0, contentHeight: 0)
    static func reduce(value: inout ScrollMetrics, nextValue: () -> ScrollMetrics) {
        value = nextValue()
    }
}

/// One tappable chunk of story text (a Telugu word plus any attached punctuation).
struct WordTokenView: View {
    enum RevealState {
        case hidden, phonetic
    }

    let token: ReaderPage.Token
    let fontSize: CGFloat
    let state: RevealState
    let inDeck: Bool

    var body: some View {
        Text(token.display + " ")
            .font(Theme.serif(fontSize))
            .foregroundStyle(state == .phonetic ? Theme.accent : Theme.textBody)
            .overlay(alignment: .bottom) {
                if inDeck && state == .hidden {
                    DottedUnderline()
                        .offset(y: 2)
                }
            }
            .padding(.top, fontSize * 0.75)
            .overlay(alignment: .top) {
                if state == .phonetic, let word = token.teluguWord {
                    Text(Transliterator.transliterate(word))
                        .font(Theme.latinSerif(fontSize * 0.55))
                        .foregroundStyle(Theme.phonetic)
                        .fixedSize()
                }
            }
            .contentShape(Rectangle())
    }
}

struct DottedUnderline: View {
    var body: some View {
        Line()
            .stroke(Theme.gold, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            .frame(height: 1)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
            return path
        }
    }
}

/// A page of story content: paragraphs of tappable tokens.
struct ReaderPage: Identifiable {
    struct Token: Identifiable, Hashable {
        /// Position-stable id: page/paragraph/offset.
        let id: String
        /// What is drawn (word plus trailing punctuation).
        let display: String
        /// The Telugu core used for lookup; nil for pure punctuation chunks.
        let teluguWord: String?
    }

    let index: Int
    let paragraphs: [[Token]]

    var id: Int { index }

    /// Splits a story into pages by paragraph, keeping each page under a
    /// character budget scaled by font size (larger text → fewer chars/page).
    static func paginate(story: Story, fontSize: CGFloat) -> [ReaderPage] {
        let budget = Int(14000 / fontSize)
        var pages: [[String]] = []
        var current: [String] = []
        var currentCount = story.title.count + 100  // title block on page 1

        for paragraph in story.paragraphs {
            if !current.isEmpty && currentCount + paragraph.count > budget {
                pages.append(current)
                current = []
                currentCount = 0
            }
            current.append(paragraph)
            currentCount += paragraph.count
        }
        if !current.isEmpty { pages.append(current) }

        return pages.enumerated().map { pageIdx, paragraphs in
            ReaderPage(
                index: pageIdx,
                paragraphs: paragraphs.enumerated().map { paraIdx, text in
                    tokenize(text, pageIdx: pageIdx, paraIdx: paraIdx)
                })
        }
    }

    /// Tokenizes every paragraph of a story into one flat list, for the
    /// continuous scroll reader (no pagination). Ids stay globally unique
    /// because the paragraph index spans the whole story.
    static func allParagraphs(story: Story) -> [[Token]] {
        story.paragraphs.enumerated().map { paraIdx, text in
            tokenize(text, pageIdx: 0, paraIdx: paraIdx)
        }
    }

    private static func tokenize(_ paragraph: String, pageIdx: Int, paraIdx: Int) -> [Token] {
        paragraph.split(separator: " ").enumerated().map { offset, chunk in
            let display = String(chunk)
            return Token(
                id: "\(pageIdx)-\(paraIdx)-\(offset)",
                display: display,
                teluguWord: TeluguText.words(in: display).first)
        }
    }
}

/// Left-aligned wrapping layout for word tokens.
struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 0
    var verticalSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = layoutRows(subviews: subviews, maxWidth: width)
        let height = rows.reduce(0) { $0 + $1.height } + verticalSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width == .infinity ? rows.map(\.width).max() ?? 0 : width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = layoutRows(subviews: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + row.height - size.height),
                    proposal: .unspecified)
                x += size.width + horizontalSpacing
            }
            y += row.height + verticalSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func layoutRows(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let nextWidth = row.width + (row.indices.isEmpty ? 0 : horizontalSpacing) + size.width
            if !row.indices.isEmpty && nextWidth > maxWidth {
                rows.append(row)
                row = Row()
            }
            row.width += (row.indices.isEmpty ? 0 : horizontalSpacing) + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}

#Preview {
    let model = AppModel()
    return ReaderView(story: model.storyStore.stories[0])
        .environment(model)
}
