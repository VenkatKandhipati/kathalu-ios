import SwiftUI

// Rendering support for the Journey map — the cartoon Godavari locked in the
// design spike (ROADMAP feature #2 phase 5). Promoted from the DEBUG
// prototypes in Views/Learn/Prototypes/, which stay untouched until 5f
// deletes them; names here are distinct so both compile in DEBUG builds.

// MARK: - Palette

/// Spring-morning palette: pale meadow, bright water, warm sandstone for
/// locked stops — tuned for text contrast in light and dark mode.
enum JourneyPalette {
    static let meadowTop = Color(journey: 0xF3F9E4, dark: 0x2C3722)
    static let meadowBottom = Color(journey: 0xDFF2C2, dark: 0x232D1A)
    static let hillGreen = Color(journey: 0xCFEBA9, dark: 0x33401F)
    static let waterEdge = Color(journey: 0x74C4E4, dark: 0x3E7E9A)
    static let waterBody = Color(journey: 0xAAE0F5, dark: 0x4A8AA6)
    static let waterLight = Color(journey: 0xD4F1FC, dark: 0x5C9CB8)
    static let doneGreen = Color(journey: 0x7FC95B, dark: 0x69A94A)
    static let currentGold = Color(journey: 0xF6B03F, dark: 0xD98F2B)
    static let lockedFill = Color(journey: 0xEFEBDE, dark: 0x4A483E)
    static let lockedText = Color(journey: 0x8A7A5C, dark: 0xA89F8C)
    static let earthBrown = Color(journey: 0x5A4A2E, dark: 0xC9BCA0)
    static let treeGreen = Color(journey: 0x8CCB6E, dark: 0x567A48)
    static let treeDark = Color(journey: 0x6DB456, dark: 0x48663D)
    static let fog = Color(journey: 0xFFFFFF, dark: 0xAFC29A)
    static let ghatSand = Color(journey: 0xE2C48A, dark: 0x8A6E42)
    static let ghatSandLow = Color(journey: 0xD9BC80, dark: 0x7E6438)
    static let ghatBorder = Color(journey: 0xC9A75F, dark: 0x6B5432)
}

extension Color {
    /// Light/dark hex pair (Journey copy of Theme's private helper).
    init(journey light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1)
        })
    }
}

// MARK: - Layout

struct JourneyNode: Identifiable {
    let stop: PathStop
    let index: Int
    let sectionIndex: Int
    let point: CGPoint
    let state: JourneyStopState
    var id: String { stop.id }
}

struct JourneyBanner: Identifiable {
    let section: PathSection
    let y: CGFloat
    let locked: Bool
    var id: String { section.id }
}

/// Geometry for the Journey map: stop positions meandering up the scroll
/// (the journey starts at the bottom, the sea is at the top), one Catmull-Rom
/// spline threaded through them (the river), and the trim fraction of the
/// current position for the traveled-water effect.
struct JourneyLayout {
    let nodes: [JourneyNode]
    let banners: [JourneyBanner]
    let river: Path
    let height: CGFloat
    /// Trim fraction of the river up to the current stop.
    let progress: CGFloat
    /// A point on the river slightly upstream of the current stop — where the
    /// boat sits (taken from the trimmed path so it's always on water).
    let boatPoint: CGPoint

    init(width: CGFloat, states: [String: JourneyStopState], currentIndex: Int) {
        var nodes: [JourneyNode] = []
        var banners: [JourneyBanner] = []
        var y: CGFloat = 84
        var index = 0

        for (sectionIndex, section) in LearnPath.sections.enumerated() {
            let locked = section.stops.allSatisfy { states[$0.id] == .locked }
            banners.append(JourneyBanner(section: section, y: y - 40, locked: locked))
            y += 30
            for stop in section.stops {
                let x: CGFloat
                switch stop.kind {
                case .temple:
                    x = width * 0.5  // landmarks anchor the center of the map
                case .village, .milestone:
                    let sway = 0.27 * sin(CGFloat(index) * 1.15 + Self.jitter(index) * 0.9)
                    x = width * min(max(0.5 + sway, 0.24), 0.76)
                }
                nodes.append(JourneyNode(stop: stop, index: index, sectionIndex: sectionIndex,
                                         point: CGPoint(x: x, y: y),
                                         state: states[stop.id] ?? .locked))
                switch stop.kind {
                case .temple: y += 190
                case .milestone: y += 156
                case .village: y += 148
                }
                index += 1
            }
            y += 26
        }

        // The journey flows upward — flip the downward layout so completed
        // stops sit beneath the boat and the unexplored course rises above.
        let totalHeight = y + 40
        height = totalHeight
        let flipped = nodes.map {
            JourneyNode(stop: $0.stop, index: $0.index, sectionIndex: $0.sectionIndex,
                        point: CGPoint(x: $0.point.x, y: totalHeight - $0.point.y),
                        state: $0.state)
        }
        self.nodes = flipped
        self.banners = banners.map {
            JourneyBanner(section: $0.section, y: totalHeight - $0.y, locked: $0.locked)
        }
        let pts = [CGPoint(x: flipped[0].point.x, y: totalHeight + 80)]
            + flipped.map(\.point)
            + [CGPoint(x: flipped[flipped.count - 1].point.x, y: -80)]
        let path = Self.spline(through: pts)
        river = path

        // Trim fractions via chord-length approximation — segments are evenly
        // spaced enough that straight-line distances track path length.
        var total: CGFloat = 0
        var toCurrent: CGFloat = 0
        for i in 0..<(pts.count - 1) {
            let d = hypot(pts[i + 1].x - pts[i].x, pts[i + 1].y - pts[i].y)
            total += d
            if i <= currentIndex { toCurrent += d }
        }
        progress = toCurrent / total
        let boatFraction = max(0, (toCurrent - 74) / total)
        boatPoint = path.trimmedPath(from: 0, to: boatFraction).currentPoint
            ?? flipped[min(currentIndex, flipped.count - 1)].point
    }

    /// Stable pseudo-random in 0..<1 so the meander is organic but identical
    /// across launches.
    static func jitter(_ i: Int) -> CGFloat {
        let v = sin(Double(i) * 12.9898) * 43758.5453
        return CGFloat(v - v.rounded(.down))
    }

    /// Catmull-Rom spline through the points, as cubic Béziers.
    static func spline(through pts: [CGPoint]) -> Path {
        var path = Path()
        guard pts.count > 1 else { return path }
        path.move(to: pts[0])
        for i in 0..<(pts.count - 1) {
            let p0 = i == 0 ? pts[0] : pts[i - 1]
            let p1 = pts[i]
            let p2 = pts[i + 1]
            let p3 = i + 2 < pts.count ? pts[i + 2] : p2
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
    }
}

/// Wraps the absolute-coordinate river path so it can be stroked and trimmed
/// as a Shape. The hosting view's frame must match the layout's size.
struct JourneySpine: Shape {
    let path: Path
    func path(in rect: CGRect) -> Path { path }
}

// MARK: - Temple

/// A playful south-Indian temple built from shapes: three tapering gopuram
/// tiers with highlight bands, a kalasham finial, and a white sanctum wall
/// with an arched door. Completed temples fly a pennant; locked temples are
/// pale sandstone awaiting their colors, not gray ruins.
struct JourneyTemple: View {
    let locked: Bool
    let flag: Bool

    private var tierStyle: AnyShapeStyle {
        locked
            ? AnyShapeStyle(Color(journey: 0xE7DFC9, dark: 0x55503F))
            : AnyShapeStyle(LinearGradient(
                colors: [Color(journey: 0xF0B04A, dark: 0xC98E36),
                         Color(journey: 0xD9822B, dark: 0xA96A22)],
                startPoint: .top, endPoint: .bottom))
    }

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(locked
                      ? AnyShapeStyle(Color(journey: 0xD5CDB8, dark: 0x5C5748))
                      : AnyShapeStyle(Color(journey: 0xF2C94C, dark: 0xD9AF35)))
                .frame(width: 7, height: 7)
                .offset(y: 1)
            ForEach(0..<3, id: \.self) { tier in
                JourneyTrapezoid()
                    .fill(tierStyle)
                    .frame(width: 24 + CGFloat(tier) * 13, height: 12)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(.white.opacity(locked ? 0.15 : 0.3))
                            .frame(height: 2.5)
                            .padding(.horizontal, 7)
                    }
            }
            ZStack(alignment: .bottom) {
                UnevenRoundedRectangle(cornerRadii: .init(topLeading: 3, topTrailing: 3))
                    .fill(locked
                          ? AnyShapeStyle(Color(journey: 0xF2EDDD, dark: 0x4A473C))
                          : AnyShapeStyle(Color(journey: 0xFBF3E2, dark: 0xC9BFA6)))
                    .frame(width: 58, height: 17)
                UnevenRoundedRectangle(cornerRadii: .init(topLeading: 5, topTrailing: 5))
                    .fill(locked
                          ? Color(journey: 0xC2B79E, dark: 0x6B6555)
                          : Color(journey: 0x6B4226, dark: 0x4A2E1A))
                    .frame(width: 10, height: 12)
            }
        }
        .overlay(alignment: .top) {
            if flag && !locked {
                HStack(alignment: .top, spacing: 0) {
                    Rectangle()
                        .fill(Color(journey: 0x8A6238, dark: 0x6B4C2B))
                        .frame(width: 1.5, height: 13)
                    JourneyPennant()
                        .fill(Color(journey: 0xD9542B, dark: 0xC24A26))
                        .frame(width: 10, height: 7)
                }
                .offset(x: 13, y: -10)
            }
        }
        .shadow(color: .black.opacity(locked ? 0.08 : 0.18), radius: 4, y: 2)
    }
}

/// A gopuram tier: flat base, tapered top.
private struct JourneyTrapezoid: Shape {
    var inset: CGFloat = 0.16
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * inset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * inset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// The little triangular temple flag.
private struct JourneyPennant: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Motion

/// Gentle vertical bob for the boat marker.
struct JourneyBobbing: ViewModifier {
    @State private var up = false
    func body(content: Content) -> some View {
        content
            .offset(y: up ? -2.5 : 2.5)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    up = true
                }
            }
    }
}

/// Slow breathing scale for the current stop; `still` renders children
/// unanimated so call sites can stay unconditional.
struct JourneyBreathing: ViewModifier {
    var still = false
    @State private var big = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(still ? 1 : (big ? 1.06 : 0.97))
            .onAppear {
                guard !still else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    big = true
                }
            }
    }
}
