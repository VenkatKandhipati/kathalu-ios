import SwiftUI
import PencilKit

/// A trace-over worksheet: letters down the page, each repeated across a row of
/// faint guide cells to trace with finger or Pencil. Pure practice — no grading.
/// The layout is geometry-driven: rows size to fill the available height and
/// cells fill the width, so it fills the screen in both orientations. Flip pages
/// to work through the deck; ink is kept per page for the session (in memory).
struct WorksheetView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let title: String
    let aksharas: [Akshara]

    private let cellsPerRow = 3
    private let minRowHeight: CGFloat = 170
    private let rowSpacing: CGFloat = 14
    private let vPad: CGFloat = 18
    private let hPad: CGFloat = 20

    @State private var page = 0
    @State private var rowsPerPage = 3
    @State private var canvas = PKCanvasView()
    /// Strokes drawn on each page, so flipping back and forth keeps your work.
    @State private var pageInk: [Int: PKDrawing] = [:]

    private var pageCount: Int { max(1, (aksharas.count + rowsPerPage - 1) / rowsPerPage) }

    private func rows(perPage: Int) -> [Akshara] {
        let start = page * perPage
        guard start < aksharas.count else { return [] }
        return Array(aksharas[start..<min(start + perPage, aksharas.count)])
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    let perPage = max(1, Int((geo.size.height - vPad * 2 + rowSpacing)
                                             / (minRowHeight + rowSpacing)))
                    let rowHeight = (geo.size.height - vPad * 2 - rowSpacing * CGFloat(perPage - 1))
                        / CGFloat(perPage)
                    sheet(rowHeight: rowHeight, perPage: perPage)
                        .onAppear { updatePerPage(perPage) }
                        .onChange(of: perPage) { _, new in updatePerPage(new) }
                }
                pager
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.pageBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { clearPage() } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
    }

    /// Faint guide rows with a single ink surface laid over them, so you can
    /// write across the whole sheet like paper.
    private func sheet(rowHeight: CGFloat, perPage: Int) -> some View {
        ZStack(alignment: .top) {
            VStack(spacing: rowSpacing) {
                ForEach(rows(perPage: perPage)) { row($0, height: rowHeight) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.vertical, vPad)
            .padding(.horizontal, hPad)

            WritingCanvasView(canvas: canvas)
                .padding(.vertical, vPad)
                .padding(.horizontal, hPad)
        }
    }

    private func row(_ akshara: Akshara, height: CGFloat) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(akshara.letter)
                    .font(Theme.serif(34, weight: .bold))
                    .foregroundStyle(Theme.textHeading)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(akshara.trans)
                    .font(Theme.latinSerif(13))
                    .foregroundStyle(Theme.accent)
            }
            .frame(width: 64)
            ForEach(0..<cellsPerRow, id: \.self) { _ in
                guideCell(akshara.letter, height: height)
            }
        }
        .frame(height: height)
    }

    private func guideCell(_ letter: String, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14).fill(Theme.card)
            RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.cardBorder)
            Text(letter)
                .font(Theme.serif(height * 0.56))
                .foregroundStyle(Theme.textTertiary.opacity(0.28))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }

    private var pager: some View {
        HStack {
            Button { go(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(page > 0 ? Theme.accent : Theme.textTertiary.opacity(0.5))
                    .frame(width: 44, height: 44)
            }
            .disabled(page == 0)
            Spacer()
            Text("Page \(page + 1) of \(pageCount)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Button { go(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(page < pageCount - 1 ? Theme.accent : Theme.textTertiary.opacity(0.5))
                    .frame(width: 44, height: 44)
            }
            .disabled(page == pageCount - 1)
        }
        .padding(.horizontal, 20)
        .frame(height: 58)
        .background(Theme.pageBackground.opacity(0.95))
        .overlay(alignment: .top) { Divider().overlay(Theme.divider) }
    }

    private func go(_ delta: Int) {
        let next = page + delta
        guard next >= 0, next < pageCount else { return }
        pageInk[page] = canvas.drawing            // bank the current page's ink
        page = next
        canvas.drawing = pageInk[next] ?? PKDrawing()
    }

    /// Rows-per-page changes with the viewport (e.g. rotation). Retained ink no
    /// longer aligns with the re-flowed grid, so reset it and clamp the page.
    private func updatePerPage(_ newValue: Int) {
        guard newValue != rowsPerPage else { return }
        rowsPerPage = newValue
        pageInk = [:]
        canvas.drawing = PKDrawing()
        page = min(page, pageCount - 1)
    }

    private func clearPage() {
        canvas.drawing = PKDrawing()
        pageInk[page] = nil
    }
}

#Preview {
    WorksheetView(title: "అచ్చులు · Worksheet", aksharas: AksharaData.vowels.aksharas)
        .environment(AppModel())
}
