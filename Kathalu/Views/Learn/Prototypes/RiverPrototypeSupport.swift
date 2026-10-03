#if DEBUG
import SwiftUI

// Throwaway visual prototypes for the Journey tab's river concept (roadmap
// feature #2 phase 5). DEBUG-only: nothing here ships or touches real state.
// The trip follows real Godavari landmarks — the journey begins where Telugu
// literacy traditionally begins (అక్షరాభ్యాసం at Basara's Saraswati temple)
// and ends where the river meets the sea at Antarvedi.

// MARK: - Fake journey data

enum ProtoStopKind {
    case village(letters: String)                       // lesson: a few new letters
    case milestone(telugu: String, title: String)        // "you can now read…" reward
    case temple(telugu: String, name: String, caption: String)  // section checkpoint
}

struct ProtoStop: Identifiable {
    let id: String
    let kind: ProtoStopKind

    /// The glyph a village marker leads with (first of its letters).
    var primary: String {
        if case .village(let letters) = kind {
            return String(letters.split(separator: " ").first ?? "")
        }
        return ""
    }
}

struct ProtoSection: Identifiable {
    let telugu: String
    let name: String
    let stops: [ProtoStop]
    var id: String { name }
}

enum RiverProtoData {
    static let sections: [ProtoSection] = [
        ProtoSection(telugu: "అచ్చులు", name: "Vowels", stops: [
            ProtoStop(id: "v1", kind: .village(letters: "అ ఆ ఇ ఈ")),
            ProtoStop(id: "v2", kind: .village(letters: "ఉ ఊ ఎ ఏ")),
            ProtoStop(id: "v3", kind: .village(letters: "ఐ ఒ ఓ ఔ")),
            ProtoStop(id: "v4", kind: .village(letters: "ఋ అం అః")),
            ProtoStop(id: "t1", kind: .temple(telugu: "బాసర", name: "Basara",
                caption: "Where children write their first letters")),
        ]),
        ProtoSection(telugu: "హల్లులు", name: "Consonants", stops: [
            ProtoStop(id: "c1", kind: .village(letters: "క ఖ గ ఘ ఙ")),
            ProtoStop(id: "c2", kind: .village(letters: "చ ఛ జ ఝ ఞ")),
            ProtoStop(id: "c3", kind: .village(letters: "ట ఠ డ ఢ ణ")),
            ProtoStop(id: "c4", kind: .village(letters: "త థ ద ధ న")),
            ProtoStop(id: "c5", kind: .village(letters: "ప ఫ బ భ మ")),
            ProtoStop(id: "c6", kind: .village(letters: "య ర ల వ")),
            ProtoStop(id: "c7", kind: .village(letters: "శ ష స హ ళ")),
            ProtoStop(id: "m1", kind: .milestone(telugu: "మొదటి పదాలు", title: "Your first words")),
            ProtoStop(id: "t2", kind: .temple(telugu: "ధర్మపురి", name: "Dharmapuri",
                caption: "Temple town above the gorge")),
        ]),
        ProtoSection(telugu: "గుణింతాలు", name: "Vowel signs", stops: [
            ProtoStop(id: "g1", kind: .village(letters: "కా కి కీ")),
            ProtoStop(id: "g2", kind: .village(letters: "కు కూ")),
            ProtoStop(id: "g3", kind: .village(letters: "కె కే కై")),
            ProtoStop(id: "g4", kind: .village(letters: "కొ కో కౌ కం")),
            ProtoStop(id: "m2", kind: .milestone(telugu: "పద ప్రవాహం", title: "120 new words open up")),
            ProtoStop(id: "t3", kind: .temple(telugu: "భద్రాచలం", name: "Bhadrachalam",
                caption: "Rama's temple on the river bend")),
        ]),
        ProtoSection(telugu: "వత్తులు", name: "Conjuncts", stops: [
            ProtoStop(id: "o1", kind: .village(letters: "క్క ల్ల మ్మ")),
            ProtoStop(id: "o2", kind: .village(letters: "త్త ద్ద న్న")),
            ProtoStop(id: "o3", kind: .village(letters: "ప్ప బ్బ జ్జ")),
            ProtoStop(id: "o4", kind: .village(letters: "ప్ర క్ర ద్ర")),
            ProtoStop(id: "o5", kind: .village(letters: "స్త క్ష ష్ణ")),
            ProtoStop(id: "t4", kind: .temple(telugu: "రాజమహేంద్రవరం", name: "Rajahmundry",
                caption: "Birthplace of Telugu letters")),
        ]),
        ProtoSection(telugu: "సాగర సంగమం", name: "The sea", stops: [
            ProtoStop(id: "m3", kind: .milestone(telugu: "మీ మొదటి కథ", title: "Read your first story")),
            ProtoStop(id: "t5", kind: .temple(telugu: "అంతర్వేది", name: "Antarvedi",
                caption: "Where the Godavari meets the sea")),
        ]),
    ]

    static var stops: [ProtoStop] { sections.flatMap(\.stops) }

    /// Fake progress: vowels done, partway into the consonant hills.
    static let currentIndex = 7

    static var currentID: String { stops[currentIndex].id }
}

enum ProtoState {
    case done, current, locked
}

// MARK: - Shared layout engine

struct RiverNode: Identifiable {
    let stop: ProtoStop
    let index: Int
    let sectionIndex: Int
    let point: CGPoint
    let state: ProtoState
    var id: String { stop.id }
}

struct RiverBanner: Identifiable {
    let section: ProtoSection
    let y: CGFloat
    let locked: Bool
    var id: String { section.id }
}

/// Shared geometry for every prototype style: stop positions meandering up the
/// scroll (journey starts at the bottom, the sea is at the top), one
/// Catmull-Rom spline threaded through them (the river), and the trim fraction
/// of the current position. All styles render from the same layout so the
/// comparison is purely about visual treatment.
struct RiverLayout {
    let nodes: [RiverNode]
    let banners: [RiverBanner]
    let river: Path
    let height: CGFloat
    /// Trim fraction of the river up to the current stop.
    let progress: CGFloat
    /// A point on the river slightly upstream of the current stop — where the
    /// traveler's boat sits (taken from the trimmed path so it's always on water).
    let boatPoint: CGPoint

    init(width: CGFloat, currentIndex: Int = RiverProtoData.currentIndex) {
        var nodes: [RiverNode] = []
        var banners: [RiverBanner] = []
        var y: CGFloat = 84
        var index = 0

        for (sectionIndex, section) in RiverProtoData.sections.enumerated() {
            banners.append(RiverBanner(section: section, y: y - 40, locked: index > currentIndex))
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
                let state: ProtoState = index < currentIndex ? .done
                    : index == currentIndex ? .current : .locked
                nodes.append(RiverNode(stop: stop, index: index, sectionIndex: sectionIndex,
                                       point: CGPoint(x: x, y: y), state: state))
                switch stop.kind {
                case .temple: y += 190
                case .milestone: y += 156
                case .village: y += 148
                }
                index += 1
            }
            y += 26
        }

        // The journey flows upward — you start at the bottom of the map and
        // travel toward the sea at the top, so completed stops sit beneath you
        // and the unexplored course rises above. Flip the downward layout.
        let totalHeight = y + 40
        height = totalHeight
        let flipped = nodes.map {
            RiverNode(stop: $0.stop, index: $0.index, sectionIndex: $0.sectionIndex,
                      point: CGPoint(x: $0.point.x, y: totalHeight - $0.point.y),
                      state: $0.state)
        }
        self.nodes = flipped
        self.banners = banners.map {
            RiverBanner(section: $0.section, y: totalHeight - $0.y, locked: $0.locked)
        }
        let pts = [CGPoint(x: flipped[0].point.x, y: totalHeight + 80)]
            + flipped.map(\.point)
            + [CGPoint(x: flipped[flipped.count - 1].point.x, y: -80)]
        let path = Self.spline(through: pts)
        river = path

        // Trim fractions via chord-length approximation: segments are roughly
        // evenly spaced, so straight-line distances track path length closely
        // enough for a prototype.
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
            ?? nodes[currentIndex].point
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

/// Wraps the absolute-coordinate river path so styles can stroke and trim it
/// as a Shape. The hosting view's frame must match the layout's size.
struct RiverSpine: Shape {
    let path: Path
    func path(in rect: CGRect) -> Path { path }
}

// MARK: - Shared marker pieces

/// A south-Indian temple tower silhouette: stacked tapering tiers on a plinth
/// with a kalasham on top. Pure Path — no image assets.
struct GopuramGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let tiers = 4
        let baseH = rect.height * 0.16
        let capH = rect.height * 0.14
        let tierH = (rect.height - baseH - capH) / CGFloat(tiers)
        for i in 0..<tiers {
            let inset = rect.width * 0.36 * (CGFloat(i) / CGFloat(tiers))
            let yTop = rect.maxY - baseH - tierH * CGFloat(i + 1)
            p.addRect(CGRect(x: rect.minX + inset, y: yTop,
                             width: rect.width - inset * 2, height: tierH - 1.5))
        }
        p.addRect(CGRect(x: rect.minX, y: rect.maxY - baseH, width: rect.width, height: baseH))
        let capW = min(rect.width * 0.2, 7)
        p.addEllipse(in: CGRect(x: rect.midX - capW / 2, y: rect.minY,
                                width: capW, height: capH))
        return p
    }
}

/// Expanding-and-fading ring marking the current stop.
struct ProtoPulseRing: View {
    let color: Color
    let size: CGFloat
    @State private var expanded = false

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 2)
            .frame(width: size, height: size)
            .scaleEffect(expanded ? 1.4 : 1)
            .opacity(expanded ? 0 : 0.8)
            .onAppear {
                withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    expanded = true
                }
            }
    }
}

/// Gentle vertical bob for the boat marker.
struct ProtoBobbing: ViewModifier {
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

extension Color {
    /// Light/dark hex pair — prototype-local copy of Theme's private helper.
    init(proto light: UInt32, dark: UInt32) {
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
#endif
