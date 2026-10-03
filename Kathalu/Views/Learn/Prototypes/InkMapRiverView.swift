#if DEBUG
import SwiftUI

/// Prototype style A — "ink map": the river drawn like the endpaper map of an
/// old storybook. One teal ink wash over the app's paper background, thin edge
/// line, and typographic markers. Ahead of the traveler the course is only a
/// dotted survey line.
struct InkMapRiverView: View {
    private let ink = Color(proto: 0x3E6E78, dark: 0x7FA8B0)

    var body: some View {
        GeometryReader { geo in
            let layout = RiverLayout(width: geo.size.width)
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        riverLayers(layout)
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
        .background(Theme.background)
    }

    // MARK: River

    @ViewBuilder
    private func riverLayers(_ layout: RiverLayout) -> some View {
        // The unexplored course: a faint dotted line, like a surveyor's mark.
        RiverSpine(path: layout.river)
            .stroke(ink.opacity(0.35), style: StrokeStyle(lineWidth: 1.6, dash: [2, 7]))
        // The traveled river: a wide soft wash plus a solid edge line — the
        // double stroke is what makes it read as ink rather than a blue worm.
        RiverSpine(path: layout.river)
            .trim(from: 0, to: layout.progress)
            .stroke(ink.opacity(0.16), style: StrokeStyle(lineWidth: 22, lineCap: .round))
        RiverSpine(path: layout.river)
            .trim(from: 0, to: layout.progress)
            .stroke(ink.opacity(0.55), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    }

    private func boat(at point: CGPoint) -> some View {
        Image(systemName: "sailboat.fill")
            .font(.system(size: 15))
            .foregroundStyle(ink)
            .modifier(ProtoBobbing())
            .position(point)
    }

    // MARK: Banners

    private func bannerView(_ banner: RiverBanner, width: CGFloat) -> some View {
        HStack(spacing: 10) {
            line
            HStack(spacing: 7) {
                Text(banner.section.telugu)
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Text(banner.section.name.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.7)
                    .foregroundStyle(Theme.textTertiary)
            }
            .fixedSize()
            line
        }
        .frame(width: width - 60)
        .opacity(banner.locked ? 0.45 : 1)
        .position(x: width / 2, y: banner.y)
    }

    private var line: some View {
        Rectangle()
            .fill(Theme.divider)
            .frame(height: 1)
    }

    // MARK: Markers

    @ViewBuilder
    private func markerView(_ node: RiverNode) -> some View {
        switch node.stop.kind {
        case .village:
            villageMarker(node)
                .position(node.point)
                .id(node.id)
        case .milestone:
            milestoneMarker(node)
                .position(node.point)
                .id(node.id)
        case .temple:
            templeMarker(node)
                .position(node.point)
                .id(node.id)
        }
    }

    private func villageMarker(_ node: RiverNode) -> some View {
        ZStack {
            if node.state == .current {
                ProtoPulseRing(color: Theme.accent, size: 48)
            }
            Circle()
                .fill(node.state == .done ? ink.opacity(0.12) : Theme.card)
                .frame(width: 48, height: 48)
                .overlay(
                    Circle().strokeBorder(
                        node.state == .current ? Theme.accent
                            : node.state == .done ? ink.opacity(0.7) : Theme.cardBorder,
                        lineWidth: node.state == .locked ? 1 : 1.5))
            Text(node.stop.primary)
                .font(Theme.serif(19, weight: .semibold))
                .foregroundStyle(node.state == .locked ? Theme.textTertiary : Theme.textHeading)
        }
        .opacity(node.state == .locked ? 0.5 : 1)
    }

    private func milestoneMarker(_ node: RiverNode) -> some View {
        ZStack {
            Circle()
                .fill(Theme.card)
                .frame(width: 46, height: 46)
                .overlay(Circle().strokeBorder(
                    node.state == .locked ? Theme.cardBorder : Theme.gold, lineWidth: 1.5))
            Image(systemName: "book.closed")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(node.state == .locked ? Theme.textTertiary : Theme.gold)
        }
        .opacity(node.state == .locked ? 0.5 : 1)
    }

    private func templeMarker(_ node: RiverNode) -> some View {
        ZStack {
            // Ghat steps spanning the river behind the landmark.
            VStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Rectangle()
                        .fill(ink.opacity(0.4))
                        .frame(width: 96 - CGFloat(i) * 18, height: 1.2)
                }
            }
            .offset(y: 34)
            Circle()
                .fill(Theme.card)
                .frame(width: 58, height: 58)
                .overlay(Circle().strokeBorder(
                    node.state == .done ? ink.opacity(0.7) : Theme.cardBorder, lineWidth: 1.5))
            GopuramGlyph()
                .fill(node.state == .locked ? Theme.textTertiary : ink)
                .frame(width: 24, height: 27)
        }
        .opacity(node.state == .locked ? 0.55 : 1)
    }

    // MARK: Captions

    @ViewBuilder
    private func captionView(_ node: RiverNode) -> some View {
        switch node.stop.kind {
        case .village(let letters):
            Text(letters)
                .font(Theme.serif(12))
                .foregroundStyle(node.state == .locked ? Theme.textTertiary.opacity(0.7) : Theme.textSecondary)
                .position(x: node.point.x, y: node.point.y + 42)
        case .milestone(let telugu, let title):
            VStack(spacing: 1) {
                Text(telugu)
                    .font(Theme.sans(12, weight: .semibold))
                    .foregroundStyle(node.state == .locked ? Theme.textTertiary : Theme.gold)
                Text(title)
                    .font(Theme.latinSerif(11))
                    .italic()
                    .foregroundStyle(Theme.textTertiary)
            }
            .position(x: node.point.x, y: node.point.y + 48)
        case .temple(let telugu, let name, let caption):
            VStack(spacing: 2) {
                Text(telugu)
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundStyle(node.state == .locked ? Theme.textTertiary : Theme.textHeading)
                Text("\(name) — \(caption)")
                    .font(Theme.latinSerif(11))
                    .italic()
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(width: 230)
            }
            .position(x: node.point.x, y: node.point.y + 68)
        }
    }
}

#Preview {
    InkMapRiverView()
}
#endif
