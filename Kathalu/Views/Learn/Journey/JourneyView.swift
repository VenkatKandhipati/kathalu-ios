import SwiftUI

/// The Learn tab's default mode: the Godavari journey map. Stops derive their
/// state from the SM-2 ledger (`AppModel.journeyStates`); tapping the current
/// village starts its lesson, tapping a completed village re-practices it
/// (with a strengthen badge when letters are due), and tapping a reachable
/// temple starts its checkpoint quiz.
struct JourneyView: View {
    @Environment(AppModel.self) private var model
    @State private var session: JourneySession?
    /// Returning from a lesson shouldn't replay the opening flyover — just
    /// settle gently on the (possibly advanced) current stop.
    @State private var suppressNextFlyover = false
    /// Drives the scroll offset directly (iOS 18+). We compute the exact
    /// content-y for the current stop ourselves, so we never depend on
    /// `scrollTo`'s anchor resolution against `.position`ed views.
    @State private var scrollPos = ScrollPosition(edge: .top)

    var body: some View {
        GeometryReader { geo in
            let states = model.journeyStates
            let currentIndex = model.journeyCurrentIndex
            let layout = JourneyLayout(width: geo.size.width, states: states, currentIndex: currentIndex)
            ScrollView(showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    LinearGradient(colors: [JourneyPalette.meadowTop, JourneyPalette.meadowBottom],
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
            .scrollPosition($scrollPos)
            .onAppear {
                positionForCurrentStop(layout: layout, viewportHeight: geo.size.height)
            }
        }
        .background(JourneyPalette.meadowBottom)
        .fullScreenCover(item: $session) { session in
            switch session {
            case .lesson(let unit): LessonSessionView(mode: .lesson(unit))
            case .practice(let unit): LessonSessionView(mode: .practice(unit))
            case .checkpoint(let section): LessonSessionView(mode: .checkpoint(section))
            }
        }
    }

    // MARK: Scroll positioning

    /// Places the current stop ~72% down the viewport. On a normal open this
    /// flies down from the sea (the goal) so the traveler glimpses how much
    /// river is left; returning from a lesson just settles there without the
    /// reveal. The offset is computed from our own layout, so it lands exactly
    /// regardless of how the `.position`ed markers report their frames.
    private func positionForCurrentStop(layout: JourneyLayout, viewportHeight: CGFloat) {
        let node = layout.nodes[min(model.journeyCurrentIndex, layout.nodes.count - 1)]
        let maxOffset = max(0, layout.height - viewportHeight)
        let targetY = min(max(0, node.point.y - viewportHeight * 0.72), maxOffset)

        if suppressNextFlyover {
            suppressNextFlyover = false
            scrollPos.scrollTo(y: targetY)
        } else {
            scrollPos.scrollTo(edge: .top)
            Task {
                // Let the top position commit, then glide down the river.
                try? await Task.sleep(for: .seconds(0.4))
                withAnimation(.easeInOut(duration: 1.4)) {
                    scrollPos.scrollTo(y: targetY)
                }
            }
        }
    }

    // MARK: Routing

    private func tap(_ node: JourneyNode) {
        switch node.stop.kind {
        case .village(let unit):
            if node.state == .current {
                suppressNextFlyover = true
                session = .lesson(unit)
            } else if node.state == .done {
                suppressNextFlyover = true
                session = .practice(unit)
            }
        case .temple:
            if node.state == .current,
               let section = LearnPath.section(containing: node.stop.id) {
                suppressNextFlyover = true
                session = .checkpoint(section)
            }
        case .milestone:
            break
        }
    }

    private func isTappable(_ node: JourneyNode) -> Bool {
        guard LearnPath.builtStops.contains(where: { $0.id == node.stop.id }) else { return false }
        switch node.stop.kind {
        case .village: return node.state != .locked
        case .temple: return node.state == .current
        case .milestone: return false
        }
    }

    // MARK: Scenery

    @ViewBuilder
    private func riverLayers(_ layout: JourneyLayout) -> some View {
        JourneySpine(path: layout.river)
            .stroke(JourneyPalette.waterEdge, style: StrokeStyle(lineWidth: 68, lineCap: .round))
        JourneySpine(path: layout.river)
            .stroke(JourneyPalette.waterBody, style: StrokeStyle(lineWidth: 58, lineCap: .round))
        JourneySpine(path: layout.river)
            .stroke(JourneyPalette.waterLight.opacity(0.7), style: StrokeStyle(lineWidth: 30, lineCap: .round))
        // The current, drawn as a lazy dashed line down the middle.
        JourneySpine(path: layout.river)
            .stroke(Color.white.opacity(0.75),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [16, 24]))
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
            let j = JourneyLayout.jitter(i + 90)
            let left = i % 2 == 1
            let x = left ? -24 + j * 30 : width + 24 - j * 30
            items.append(Hill(id: i, point: CGPoint(x: x, y: y),
                              size: CGSize(width: 200 + j * 90, height: 64 + j * 26)))
            y += 440 + j * 170
            i += 1
        }
        return ForEach(items) { hill in
            Ellipse()
                .fill(JourneyPalette.hillGreen)
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

    /// Trees and the odd house along the banks, deterministically scattered
    /// so the scene is stable across launches.
    private func decorations(width: CGFloat, height: CGFloat) -> some View {
        var items: [Decor] = []
        var y: CGFloat = 150
        var i = 0
        while y < height - 100 {
            let j = JourneyLayout.jitter(i + 40)
            let left = i % 2 == 0
            let x = left ? 24 + j * 20 : width - 26 - j * 20
            let house = i % 4 == 3
            items.append(Decor(
                id: i,
                point: CGPoint(x: x, y: y),
                symbol: house ? "house.fill" : "tree.fill",
                size: house ? 20 : 18 + j * 8,
                color: house ? JourneyPalette.earthBrown
                    : (i % 3 == 0 ? JourneyPalette.treeDark : JourneyPalette.treeGreen)))
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

    /// The Bay of Bengal across the top of the map — where the journey ends.
    private func seaBand(width: CGFloat) -> some View {
        ZStack {
            LinearGradient(colors: [JourneyPalette.waterEdge, JourneyPalette.waterBody],
                           startPoint: .top, endPoint: .bottom)
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

    /// A light morning haze over the unexplored upstream.
    private func mist(_ layout: JourneyLayout, width: CGFloat) -> some View {
        let f = max(0.08, layout.boatPoint.y / layout.height)
        return Rectangle()
            .fill(LinearGradient(
                stops: [.init(color: JourneyPalette.fog.opacity(0.35), location: 0),
                        .init(color: JourneyPalette.fog.opacity(0.2), location: max(0, f - 0.25)),
                        .init(color: .clear, location: f)],
                startPoint: .top, endPoint: .bottom))
            .frame(width: width, height: layout.height)
            .allowsHitTesting(false)
    }

    private func boat(at point: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 38, height: 38)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            Image(systemName: "sailboat.fill")
                .font(.system(size: 18))
                .foregroundStyle(JourneyPalette.waterEdge)
        }
        .modifier(JourneyBobbing())
        .position(point)
        .allowsHitTesting(false)
    }

    // MARK: Banners

    private func bannerView(_ banner: JourneyBanner, width: CGFloat) -> some View {
        HStack(spacing: 7) {
            Text(banner.section.telugu)
                .font(Theme.sans(14, weight: .bold))
                .foregroundStyle(banner.locked ? JourneyPalette.lockedText : Theme.accentDeep)
            Text(banner.section.name)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(banner.locked ? JourneyPalette.lockedText : Theme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.white.opacity(banner.locked ? 0.85 : 0.95), in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        .position(x: width / 2, y: banner.y)
    }

    // MARK: Markers

    @ViewBuilder
    private func markerView(_ node: JourneyNode) -> some View {
        Button {
            tap(node)
        } label: {
            switch node.stop.kind {
            case .village(let unit): villageMarker(node, unit: unit)
            case .milestone: milestoneMarker(node)
            case .temple: templeMarker(node)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isTappable(node))
        // Stable identity per stop so the breathing/advance animations track
        // the right marker as journey state changes.
        .id(node.stop.id)
        .position(node.point)
    }

    private func fill(for state: JourneyStopState) -> Color {
        switch state {
        case .done: return JourneyPalette.doneGreen
        case .current: return JourneyPalette.currentGold
        case .locked: return JourneyPalette.lockedFill
        }
    }

    private func villageMarker(_ node: JourneyNode, unit: PathUnit) -> some View {
        let dueCount = node.state == .done ? model.unitDueCount(unit) : 0
        return ZStack {
            Circle()
                .fill(fill(for: node.state))
                .frame(width: 58, height: 58)
                .overlay(Circle().strokeBorder(.white, lineWidth: 4))
                .shadow(color: fill(for: node.state).opacity(0.45), radius: 6, y: 3)
            Text(unit.primary)
                .font(Theme.serif(21, weight: .bold))
                .foregroundStyle(node.state == .locked ? JourneyPalette.lockedText : .white)
            if node.state == .done {
                // Due letters flip the badge from "done" to "strengthen me".
                Image(systemName: dueCount > 0 ? "bolt.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white, dueCount > 0 ? JourneyPalette.currentGold : JourneyPalette.doneGreen)
                    .background(Circle().fill(.white).padding(1))
                    .offset(x: 21, y: -21)
            }
            if node.state == .current {
                Text("START")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(JourneyPalette.currentGold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white, in: Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                    .offset(y: -42)
            }
        }
        .modifier(node.state == .current ? JourneyBreathing() : JourneyBreathing(still: true))
    }

    private func milestoneMarker(_ node: JourneyNode) -> some View {
        ZStack {
            Circle()
                .fill(node.state == .locked ? JourneyPalette.lockedFill : Theme.gold)
                .frame(width: 54, height: 54)
                .overlay(Circle().strokeBorder(.white, lineWidth: 4))
                .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
            Image(systemName: "book.fill")
                .font(.system(size: 19))
                .foregroundStyle(node.state == .locked ? JourneyPalette.lockedText : .white)
        }
    }

    private func templeMarker(_ node: JourneyNode) -> some View {
        ZStack {
            // Ghat platform bridging the river, with a lower step into the water.
            Capsule()
                .fill(JourneyPalette.ghatSandLow)
                .frame(width: 104, height: 9)
                .offset(y: 40)
            Capsule()
                .fill(JourneyPalette.ghatSand)
                .frame(width: 148, height: 15)
                .overlay(Capsule().strokeBorder(JourneyPalette.ghatBorder, lineWidth: 2))
                .offset(y: 30)
            JourneyTemple(locked: node.state == .locked, flag: node.state == .done)
                .offset(y: -8)
            if node.state == .current {
                Text("CHECKPOINT")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(JourneyPalette.currentGold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white, in: Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                    .offset(y: -52)
            }
        }
        .modifier(node.state == .current ? JourneyBreathing() : JourneyBreathing(still: true))
    }

    // MARK: Captions

    @ViewBuilder
    private func captionView(_ node: JourneyNode) -> some View {
        switch node.stop.kind {
        case .village(let unit):
            Text(unit.letters)
                .font(Theme.serif(12, weight: .semibold))
                .foregroundStyle(node.state == .locked ? JourneyPalette.lockedText : JourneyPalette.earthBrown)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.white.opacity(0.85), in: Capsule())
                .position(x: node.point.x, y: node.point.y + 48)
        case .milestone(let telugu, let title):
            VStack(spacing: 1) {
                Text(telugu)
                    .font(Theme.sans(12, weight: .bold))
                    .foregroundStyle(node.state == .locked ? JourneyPalette.lockedText : Theme.accentDeep)
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(JourneyPalette.earthBrown)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 10))
            .position(x: node.point.x, y: node.point.y + 52)
        case .temple(let telugu, let name, _):
            HStack(spacing: 6) {
                Text(telugu)
                    .font(Theme.sans(13, weight: .bold))
                    .foregroundStyle(node.state == .locked ? JourneyPalette.lockedText : Theme.accentDeep)
                Text(name)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(JourneyPalette.earthBrown)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(.white.opacity(0.9), in: Capsule())
            .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
            .position(x: node.point.x, y: node.point.y + 68)
        }
    }
}

/// A session launched from the map.
enum JourneySession: Identifiable {
    case lesson(PathUnit)
    case practice(PathUnit)
    case checkpoint(PathSection)

    var id: String {
        switch self {
        case .lesson(let unit): return "lesson-\(unit.id)"
        case .practice(let unit): return "practice-\(unit.id)"
        case .checkpoint(let section): return "checkpoint-\(section.id)"
        }
    }
}

#Preview {
    JourneyView()
        .environment(AppModel())
}
