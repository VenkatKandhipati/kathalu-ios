import SwiftUI
import PencilKit

/// Standalone writing practice: trace each letter over a faint guide, tap Check
/// for a coverage score, then move on. Base vowels/consonants only for now —
/// single glyphs grade cleanly; composite forms come in a later phase.
struct WritingPracticeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let title: String
    let aksharas: [Akshara]

    @State private var index = 0
    @State private var canvas = PKCanvasView()
    @State private var hasInk = false
    @State private var result: GlyphTracer.Result?
    @State private var canvasSide: CGFloat = 300

    private var current: Akshara { aksharas[min(index, aksharas.count - 1)] }
    private var fontSize: CGFloat { canvasSide * 0.68 }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    prompt
                    canvasArea
                    Spacer(minLength: 0)
                    controls
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear { canvasSide = resolvedSide(geo.size) }
                .onChange(of: geo.size) { canvasSide = resolvedSide(geo.size) }
            }
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
                ToolbarItem(placement: .topBarTrailing) { SoundToggleButton() }
            }
        }
    }

    private func resolvedSide(_ size: CGSize) -> CGFloat {
        min(size.width - 44, size.height * 0.5, 380)
    }

    // MARK: Prompt

    private var prompt: some View {
        VStack(spacing: 6) {
            Text("\(index + 1) of \(aksharas.count)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
            HStack(spacing: 12) {
                Text(current.trans)
                    .font(Theme.latinSerif(26, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Button { model.speech.speak(current.spokenText) } label: {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 40, height: 40)
                        .background(Theme.accent.opacity(0.1), in: Circle())
                }
            }
            Text("Trace the letter")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    // MARK: Canvas

    private var canvasArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24).fill(Theme.card)
            RoundedRectangle(cornerRadius: 24).strokeBorder(Theme.cardBorder)
            // Faint guide — same geometry as the grading target so a good trace
            // over the guide scores high.
            Image(uiImage: GlyphTracer.glyphImage(
                current.letter,
                size: CGSize(width: canvasSide, height: canvasSide),
                fontSize: fontSize,
                color: UIColor(Theme.textTertiary.opacity(0.35))))
                .allowsHitTesting(false)
            WritingCanvasView(canvas: canvas) {
                hasInk = !canvas.drawing.strokes.isEmpty
                result = nil   // further drawing invalidates the last grade
            }
        }
        .frame(width: canvasSide, height: canvasSide)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    // MARK: Controls

    @ViewBuilder
    private var controls: some View {
        VStack(spacing: 12) {
            if let result {
                feedback(result)
                Button { advance() } label: {
                    Text(index + 1 < aksharas.count ? "Next letter" : "Done")
                        .primaryButton()
                }
                .padding(.horizontal, 40)
            } else {
                HStack(spacing: 12) {
                    Button { clear() } label: {
                        Label("Clear", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.cardBorder))
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasInk)
                    .opacity(hasInk ? 1 : 0.5)
                    Button { check() } label: {
                        Text("Check").primaryButton().opacity(hasInk ? 1 : 0.5)
                    }
                    .disabled(!hasInk)
                }
                .padding(.horizontal, 22)
            }
        }
        .padding(.bottom, 18)
    }

    private func feedback(_ r: GlyphTracer.Result) -> some View {
        let tint = r.overall >= 65 ? Theme.green : (r.overall >= 45 ? Theme.gold : Theme.accent)
        let message = r.overall >= 80 ? "Beautiful!"
            : r.overall >= 65 ? "Nicely traced"
            : r.overall >= 45 ? "Getting there" : "Keep practicing"
        return HStack(spacing: 12) {
            Text("\(r.overall)%")
                .font(Theme.serif(32, weight: .bold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(message)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textHeading)
                Text("Covered \(r.coverage)% · stayed on the line \(r.accuracy)%")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: Actions

    private func clear() {
        canvas.drawing = PKDrawing()
        hasInk = false
        result = nil
    }

    private func check() {
        let r = GlyphTracer.score(
            drawing: canvas.drawing, letter: current.letter,
            canvasSize: CGSize(width: canvasSide, height: canvasSide), fontSize: fontSize)
        result = r
        UINotificationFeedbackGenerator().notificationOccurred(r.overall >= 45 ? .success : .warning)
        // Feed the writing SM-2 namespace only on a decent trace, never below 3,
        // so a rough attempt can't demote earlier progress.
        if r.overall >= 50 {
            model.rate(writing: current, quality: r.overall >= 80 ? 5 : (r.overall >= 65 ? 4 : 3))
        }
    }

    private func advance() {
        clear()
        if index + 1 < aksharas.count { index += 1 } else { dismiss() }
    }
}

#Preview {
    WritingPracticeView(title: "అచ్చులు · Write", aksharas: AksharaData.vowels.aksharas)
        .environment(AppModel())
}
