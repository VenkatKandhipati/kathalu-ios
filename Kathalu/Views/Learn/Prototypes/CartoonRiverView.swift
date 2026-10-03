#if DEBUG
import SwiftUI

/// Prototype style C — "cartoon": a still, playful storybook illustration.
/// Light-blue water with a dashed current line, a green meadow, scattered
/// trees and houses, big candy-colored stops, and a bobbing boat. The whole
/// river is always visible; progress reads from the marker colors.
struct CartoonRiverView: View {
    // Spring-morning palette: pale meadow, bright water, warm sandstone for
    // the not-yet-reached stops — nothing murkier than the earth-brown text.
    private let meadowTop = Color(proto: 0xF3F9E4, dark: 0x2C3722)
    private let meadowBottom = Color(proto: 0xDFF2C2, dark: 0x232D1A)
    private let hillGreen = Color(proto: 0xCFEBA9, dark: 0x33401F)
    private let waterEdge = Color(proto: 0x74C4E4, dark: 0x3E7E9A)
    private let waterBody = Color(proto: 0xAAE0F5, dark: 0x4A8AA6)
    private let waterLight = Color(proto: 0xD4F1FC, dark: 0x5C9CB8)
    private let doneGreen = Color(proto: 0x7FC95B, dark: 0x69A94A)
    private let currentGold = Color(proto: 0xF6B03F, dark: 0xD98F2B)
    private let lockedFill = Color(proto: 0xEFEBDE, dark: 0x4A483E)
    private let lockedText = Color(proto: 0x8A7A5C, dark: 0xA89F8C)
    private let earthBrown = Color(proto: 0x5A4A2E, dark: 0xC9BCA0)
    private let treeGreen = Color(proto: 0x8CCB6E, dark: 0x567A48)
    private let treeDark = Color(proto: 0x6DB456, dark: 0x48663D)

    var body: some View {
        GeometryReader { geo in
            let layout = RiverLayout(width: geo.size.width)
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        LinearGradient(colors: [meadowTop, meadowBottom],
                                       startPoint: .top, endPoint: .bottom)
                        hillsLayer(width: geo.size.width, height: layout.height)
                        decorations(width: geo.size.width, height: layout.height)
                        riverLayers(layout)
                        seaBand(width: geo.size.width)
                        mist(layout, width: geo.size.width)
                        ForEach(layout.banners) { banner in
                            bannerView(banner, width: geo.size.width)
                        }
                        ForEach(layout.nodes) { node in
                            markerView(node)
                            captionView(node)
                        }
                        boat(at: layout.boatPoint)
                    }
                    .frame(width: geo.size.width, height: layout.height)
                }
                .defaultScrollAnchor(.bottom)
                .onAppear {
                    Task {
                        proxy.scrollTo(RiverProtoData.currentID,
                                       anchor: UnitPoint(x: 0.5, y: 0.7))
                    }
                }
            }
        }
        .background(meadowBottom)
    }

    // MARK: Scenery

    @ViewBuilder
    private func riverLayers(_ layout: RiverLayout) -> some View {
        RiverSpine(path: layout.river)
            .stroke(waterEdge, style: StrokeStyle(lineWidth: 68, lineCap: .round))
        RiverSpine(path: layout.river)
            .stroke(waterBody, style: StrokeStyle(lineWidth: 58, lineCap: .round))
        RiverSpine(path: layout.river)
            .stroke(waterLight.opacity(0.7), style: StrokeStyle(lineWidth: 30, lineCap: .round))
        // The current, drawn as a lazy dashed line down the middle.
        RiverSpine(path: layout.river)
            .stroke(Color.white.opacity(0.75),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [16, 24]))
    }

    /// The Bay of Bengal across the top of the map — where the journey ends.
    private func seaBand(width: CGFloat) -> some View {
        ZStack {
            LinearGradient(colors: [waterEdge, waterBody], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 15) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 30) {
                        ForEach(0..<4, id: \.self) { _ in
                            Capsule()
                                .fill(.white.opacity(0.45))
                                .frame(width: 32, height: 3)
                        }
                    }
                    .offset(x: row % 2 == 0 ? 0 : 22)
                }
            }
        }
        .frame(width: width, height: 175)
        .mask(LinearGradient(
            stops: [.init(color: .white, location: 0),
                    .init(color: .white, location: 0.5),
                    .init(color: .clear, location: 1)],
            startPoint: .top, endPoint: .bottom))
        .position(x: width / 2, y: 87)
    }

    /// Upstream haze: the course above the boat fades toward the unexplored
    /// north, so "what's ahead" reads at a glance while scrolling up.
    private func mist(_ layout: RiverLayout, width: CGFloat) -> some View {
        // A light morning haze, not a gloom — the upstream should invite.
        let fog = Color(proto: 0xFFFFFF, dark: 0xAFC29A)
        let f = max(0.08, layout.boatPoint.y / layout.height)
        return Rectangle()
            .fill(LinearGradient(
                stops: [.init(color: fog.opacity(0.35), location: 0),
                        .init(color: fog.opacity(0.2), location: max(0, f - 0.25)),
                        .init(color: .clear, location: f)],
                startPoint: .top, endPoint: .bottom))
            .frame(width: width, height: layout.height)
            .allowsHitTesting(false)
    }

    private struct Hill: Identifiable {
        let id: Int
        let point: CGPoint
        let size: CGSize
    }

    /// Soft rolling hills peeking in from the banks, half off-screen so they
    /// read as horizon bumps rather than blobs.
    private func hillsLayer(width: CGFloat, height: CGFloat) -> some View {
        var items: [Hill] = []
        var y: CGFloat = 240
        var i = 0
        while y < height - 160 {
            let j = RiverLayout.jitter(i + 90)
            let left = i % 2 == 1
            let x = left ? -24 + j * 30 : width + 24 - j * 30
            items.append(Hill(id: i, point: CGPoint(x: x, y: y),
                              size: CGSize(width: 200 + j * 90, height: 64 + j * 26)))
            y += 440 + j * 170
            i += 1
        }
        return ForEach(items) { hill in
            Ellipse()
                .fill(hillGreen)
                .frame(width: hill.size.width, height: hill.size.height)
                .position(hill.point)
        }
    }

    private struct Decor: Identifiable {
        let id: Int
        let point: CGPoint
        let symbol: String
        let size: CGFloat
        let color: Color
    }

    /// Trees and the odd house along the banks, deterministically scattered so
    /// the scene is stable across launches. Kept to the margins, clear of the
    /// river's maximum meander.
    private func decorations(width: CGFloat, height: CGFloat) -> some View {
        var items: [Decor] = []
        var y: CGFloat = 150
        var i = 0
        while y < height - 100 {
            let j = RiverLayout.jitter(i + 40)
            let left = i % 2 == 0
            let x = left ? 24 + j * 20 : width - 26 - j * 20
            let house = i % 4 == 3
            items.append(Decor(
                id: i,
                point: CGPoint(x: x, y: y),
                symbol: house ? "house.fill" : "tree.fill",
                size: house ? 20 : 18 + j * 8,
                color: house ? earthBrown : (i % 3 == 0 ? treeDark : treeGreen)))
            y += 175 + j * 70
            i += 1
        }
        return ForEach(items) { item in
            Image(systemName: item.symbol)
                .font(.system(size: item.size))
                .foregroundStyle(item.color)
                .position(item.point)
        }
    }

    private func boat(at point: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 38, height: 38)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            Image(systemName: "sailboat.fill")
                .font(.system(size: 18))
                .foregroundStyle(waterEdge)
        }
        .modifier(ProtoBobbing())
        .position(point)
    }

    // MARK: Banners

    private func bannerView(_ banner: RiverBanner, width: CGFloat) -> some View {
        HStack(spacing: 7) {
            Text(banner.section.telugu)
                .font(Theme.sans(14, weight: .bold))
                .foregroundStyle(banner.locked ? lockedText : Theme.accentDeep)
            Text(banner.section.name)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(banner.locked ? lockedText : Theme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.white.opacity(banner.locked ? 0.85 : 0.95), in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        .position(x: width / 2, y: banner.y)
    }

    // MARK: Markers

    @ViewBuilder
    private func markerView(_ node: RiverNode) -> some View {
        Group {
            switch node.stop.kind {
            case .village: villageMarker(node)
            case .milestone: milestoneMarker(node)
            case .temple: templeMarker(node)
            }
        }
        .position(node.point)
        .id(node.id)
    }

    private func fill(for state: ProtoState) -> Color {
        switch state {
        case .done: return doneGreen
        case .current: return currentGold
        case .locked: return lockedFill
        }
    }

    private func villageMarker(_ node: RiverNode) -> some View {
        ZStack {
            Circle()
                .fill(fill(for: node.state))
                .frame(width: 58, height: 58)
                .overlay(Circle().strokeBorder(.white, lineWidth: 4))
                .shadow(color: fill(for: node.state).opacity(0.45), radius: 6, y: 3)
            Text(node.stop.primary)
                .font(Theme.serif(21, weight: .bold))
                .foregroundStyle(node.state == .locked ? lockedText : .white)
            if node.state == .done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white, doneGreen)
                    .background(Circle().fill(.white).padding(1))
                    .offset(x: 21, y: -21)
            }
            if node.state == .current {
                Text("START")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(currentGold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white, in: Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                    .offset(y: -42)
            }
        }
        .modifier(node.state == .current ? ProtoBreathing() : ProtoBreathing(still: true))
    }

    private func milestoneMarker(_ node: RiverNode) -> some View {
        ZStack {
            Circle()
                .fill(node.state == .locked ? lockedFill : Theme.gold)
                .frame(width: 54, height: 54)
                .overlay(Circle().strokeBorder(.white, lineWidth: 4))
                .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
            Image(systemName: "book.fill")
                .font(.system(size: 19))
                .foregroundStyle(node.state == .locked ? lockedText : .white)
        }
    }

    private func templeMarker(_ node: RiverNode) -> some View {
        ZStack {
            // Ghat platform bridging the river, with a lower step into the water.
            Capsule()
                .fill(Color(proto: 0xD9BC80, dark: 0x7E6438))
                .frame(width: 104, height: 9)
                .offset(y: 40)
            Capsule()
                .fill(Color(proto: 0xE2C48A, dark: 0x8A6E42))
                .frame(width: 148, height: 15)
                .overlay(Capsule().strokeBorder(Color(proto: 0xC9A75F, dark: 0x6B5432), lineWidth: 2))
                .offset(y: 30)
            CartoonTemple(locked: node.state == .locked, flag: node.state == .done)
                .offset(y: -8)
        }
    }

    // MARK: Captions

    @ViewBuilder
    private func captionView(_ node: RiverNode) -> some View {
        switch node.stop.kind {
        case .village(let letters):
            Text(letters)
                .font(Theme.serif(12, weight: .semibold))
                .foregroundStyle(node.state == .locked ? lockedText : earthBrown)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.white.opacity(0.85), in: Capsule())
                .position(x: node.point.x, y: node.point.y + 48)
        case .milestone(let telugu, let title):
            VStack(spacing: 1) {
                Text(telugu)
                    .font(Theme.sans(12, weight: .bold))
                    .foregroundStyle(node.state == .locked ? lockedText : Theme.accentDeep)
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(earthBrown)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 10))
            .position(x: node.point.x, y: node.point.y + 52)
        case .temple(let telugu, let name, _):
            HStack(spacing: 6) {
                Text(telugu)
                    .font(Theme.sans(13, weight: .bold))
                    .foregroundStyle(node.state == .locked ? lockedText : Theme.accentDeep)
                Text(name)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(earthBrown)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(.white.opacity(0.9), in: Capsule())
            .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
            .position(x: node.point.x, y: node.point.y + 68)
        }
    }
}

/// A playful south-Indian temple built from shapes: three tapering gopuram
/// tiers with highlight bands, a kalasham finial, and a white sanctum wall
/// with an arched door. Completed temples fly a pennant.
private struct CartoonTemple: View {
    let locked: Bool
    let flag: Bool

    private let gold = Color(proto: 0xF2C94C, dark: 0xD9AF35)
    private let cream = Color(proto: 0xFBF3E2, dark: 0xC9BFA6)
    private let door = Color(proto: 0x6B4226, dark: 0x4A2E1A)
    private let flagRed = Color(proto: 0xD9542B, dark: 0xC24A26)
    private let pole = Color(proto: 0x8A6238, dark: 0x6B4C2B)

    private var tierStyle: AnyShapeStyle {
        // Locked temples are pale sandstone awaiting their colors, not gray ruins.
        locked
            ? AnyShapeStyle(Color(proto: 0xE7DFC9, dark: 0x55503F))
            : AnyShapeStyle(LinearGradient(
                colors: [Color(proto: 0xF0B04A, dark: 0xC98E36),
                         Color(proto: 0xD9822B, dark: 0xA96A22)],
                startPoint: .top, endPoint: .bottom))
    }

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(locked ? AnyShapeStyle(Color(proto: 0xD5CDB8, dark: 0x5C5748)) : AnyShapeStyle(gold))
                .frame(width: 7, height: 7)
                .offset(y: 1)
            ForEach(0..<3, id: \.self) { tier in
                Trapezoid()
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
                    .fill(locked ? AnyShapeStyle(Color(proto: 0xF2EDDD, dark: 0x4A473C)) : AnyShapeStyle(cream))
                    .frame(width: 58, height: 17)
                UnevenRoundedRectangle(cornerRadii: .init(topLeading: 5, topTrailing: 5))
                    .fill(locked ? Color(proto: 0xC2B79E, dark: 0x6B6555) : door)
                    .frame(width: 10, height: 12)
            }
        }
        .overlay(alignment: .top) {
            if flag && !locked {
                HStack(alignment: .top, spacing: 0) {
                    Rectangle()
                        .fill(pole)
                        .frame(width: 1.5, height: 13)
                    Pennant()
                        .fill(flagRed)
                        .frame(width: 10, height: 7)
                }
                .offset(x: 13, y: -10)
            }
        }
        .shadow(color: .black.opacity(locked ? 0.08 : 0.18), radius: 4, y: 2)
    }
}

/// A gopuram tier: flat base, tapered top.
private struct Trapezoid: Shape {
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
private struct Pennant: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Slow breathing scale for the current stop; `still` renders children
/// unanimated so call sites can stay unconditional.
struct ProtoBreathing: ViewModifier {
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

#Preview {
    CartoonRiverView()
}
#endif
