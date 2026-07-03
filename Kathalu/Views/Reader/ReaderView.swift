import SwiftUI

/// Immersive paged reader. Tap a word once for pronunciation (inline + voice),
/// tap again for the meaning sheet — matching the design's 1a + 1b flow.
struct ReaderView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let story: Story

    @State private var pageIndex = 0
    @State private var revealedTokens: Set<ReaderPage.Token.ID> = []
    @State private var tappedWords: Set<String> = []
    @State private var sheetWord: WordSheetItem?
    @State private var didFinish = false

    private var pages: [ReaderPage] {
        ReaderPage.paginate(story: story, fontSize: model.fontSize.points)
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            progressBar
            pager
            bottomBar
        }
        .background(Theme.pageBackground.ignoresSafeArea())
        .sheet(item: $sheetWord) { item in
            WordSheetView(word: item.word, story: story)
                .presentationDetents([.height(400)])
                .presentationDragIndicator(.visible)
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
            Picker("Reading font size", selection: Binding(
                get: { model.fontSize },
                set: { model.fontSize = $0 })) {
                ForEach(AppModel.ReadingFontSize.allCases) { size in
                    Text(size.label).tag(size)
                }
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
                .frame(width: geo.size.width * CGFloat(pageIndex + 1) / CGFloat(max(1, pages.count)))
                .animation(.snappy, value: pageIndex)
        }
        .frame(height: 2)
        .background(Theme.divider)
    }

    private var pager: some View {
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
            model.speech.speak(word)
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
