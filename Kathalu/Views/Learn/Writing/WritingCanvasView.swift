import SwiftUI
import PencilKit

/// A PencilKit canvas for tracing. The parent owns the `PKCanvasView` so it can
/// read the drawing for grading and clear it between letters; this configures
/// appearance, input policy, and reports stroke changes.
struct WritingCanvasView: UIViewRepresentable {
    let canvas: PKCanvasView
    var onChange: () -> Void = {}

    func makeUIView(context: Context) -> PKCanvasView {
        canvas.delegate = context.coordinator
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput          // Pencil on iPad, finger anywhere
        canvas.tool = PKInkingTool(.pen, color: UIColor(Theme.accent), width: 24)
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let onChange: () -> Void
        init(onChange: @escaping () -> Void) { self.onChange = onChange }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) { onChange() }
    }
}

/// Renders a Telugu glyph and scores how well a PencilKit trace covers it.
/// No stroke-order data is needed — grading is bitmap overlap on a coarse grid,
/// whose cells give built-in tolerance for small positional slips.
enum GlyphTracer {
    /// The bundled Telugu serif, falling back to a system face that still
    /// renders the script. The on-screen guide and the grading target use this
    /// same font + geometry, so they align exactly regardless of which resolves.
    static func teluguFont(size: CGFloat) -> UIFont {
        for name in ["Noto Serif Telugu", "NotoSerifTelugu-Regular", "NotoSerifTelugu", "Noto Sans Telugu"] {
            if let font = UIFont(name: name, size: size) { return font }
        }
        return .systemFont(ofSize: size)
    }

    /// The glyph centered in `size`. Used for both the faint on-screen guide and
    /// the (black) grading target.
    static func glyphImage(_ letter: String, size: CGSize, fontSize: CGFloat, color: UIColor) -> UIImage {
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: teluguFont(size: fontSize), .foregroundColor: color, .paragraphStyle: para,
        ]
        let str = NSAttributedString(string: letter, attributes: attrs)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let bounds = str.boundingRect(
                with: CGSize(width: size.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            let y = (size.height - bounds.height) / 2
            str.draw(with: CGRect(x: 0, y: y, width: size.width, height: ceil(bounds.height)),
                     options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        }
    }

    struct Result {
        /// % of the glyph you traced over (recall).
        let coverage: Int
        /// % of your ink that stayed on the glyph (precision).
        let accuracy: Int
        /// Overall score 0–100, weighted toward coverage (did you trace the
        /// shape?) and forgiving of some spillover — a committed trace should
        /// land encouragingly, not harshly.
        var overall: Int {
            Int((0.6 * Double(coverage) + 0.4 * Double(accuracy)).rounded())
        }
    }

    static func score(drawing: PKDrawing, letter: String, canvasSize: CGSize, fontSize: CGFloat) -> Result {
        let n = 30
        let target = occupancy(glyphImage(letter, size: canvasSize, fontSize: fontSize, color: .black), n: n)
        let userImage = drawing.image(from: CGRect(origin: .zero, size: canvasSize), scale: 1)
        let ink = occupancy(userImage, n: n)
        guard target.contains(true), ink.contains(true) else { return Result(coverage: 0, accuracy: 0) }
        var targetCount = 0, inkCount = 0, both = 0
        for k in 0..<(n * n) {
            if target[k] { targetCount += 1 }
            if ink[k] { inkCount += 1 }
            if target[k] && ink[k] { both += 1 }
        }
        return Result(
            coverage: targetCount > 0 ? both * 100 / targetCount : 0,
            accuracy: inkCount > 0 ? both * 100 / inkCount : 0)
    }

    /// Downsamples an image to an n×n grid of "has content" (alpha above a
    /// threshold). Reading the alpha channel detects glyph/ink over the clear
    /// background; the coarse grid forgives small positional slips.
    private static func occupancy(_ image: UIImage, n: Int) -> [Bool] {
        guard let cg = image.cgImage else { return [] }
        var bytes = [UInt8](repeating: 0, count: n * n * 4)
        guard let ctx = CGContext(
            data: &bytes, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return [] }
        ctx.interpolationQuality = .low
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: n, height: n))
        return (0..<(n * n)).map { bytes[$0 * 4 + 3] > 24 }
    }
}
