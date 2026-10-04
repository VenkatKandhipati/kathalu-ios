import SwiftUI
import PencilKit

/// A trace-over worksheet: a few letters per page, each repeated across a row
/// of faint guide cells to trace with finger or Pencil. Pure practice — no
/// grading; flip pages to work through the deck. Ink is kept per page for the
/// session (in memory, not saved to disk).
struct WorksheetView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let title: String
    let aksharas: [Akshara]

    private let perPage = 3
    private let cellsPerRow = 4

    @State private var page = 0
    @State private var canvas = PKCanvasView()
    /// Strokes drawn on each page, so flipping back and forth keeps your work.
    @State private var pageInk: [Int: PKDrawing] = [:]

    private var pageCount: Int { max(1, (aksharas.count + perPage - 1) / perPage) }

    private var rows: [Akshara] {
        let start = page * perPage
        return Array(aksharas[start..<min(start + perPage, aksharas.count)])
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sheet
                Spacer(minLength: 0)
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

    /// The faint guide rows with a single ink surface laid over them, so you can
    /// write across the whole sheet like paper.
    private var sheet: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 14) {
                ForEach(rows) { row($0) }
            }
            .padding(20)
            WritingCanvasView(canvas: canvas)
                .padding(20)
        }
        .readableColumn(640)
    }

    private func row(_ akshara: Akshara) -> some View {
        HStack(spacing: 10) {
            VStack(spacing: 2) {
                Text(akshara.letter)
                    .font(Theme.serif(30, weight: .bold))
                    .foregroundStyle(Theme.textHeading)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(akshara.trans)
                    .font(Theme.latinSerif(12))
                    .foregroundStyle(Theme.accent)
            }
            .frame(width: 58)
            ForEach(0..<cellsPerRow, id: \.self) { _ in
                guideCell(akshara.letter)
            }
        }
    }

    private func guideCell(_ letter: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(Theme.card)
            RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.cardBorder)
            Text(letter)
                .font(Theme.serif(44))
                .foregroundStyle(Theme.textTertiary.opacity(0.28))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 84)
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

    private func clearPage() {
        canvas.drawing = PKDrawing()
        pageInk[page] = nil
    }
}

#Preview {
    WorksheetView(title: "అచ్చులు · Worksheet", aksharas: AksharaData.vowels.aksharas)
        .environment(AppModel())
}
