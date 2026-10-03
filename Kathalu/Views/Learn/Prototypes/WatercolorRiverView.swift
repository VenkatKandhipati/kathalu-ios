#if DEBUG
import SwiftUI

/// Prototype style B — "watercolor": the middle ground between the ink map and
/// the cartoon. The river is layered translucent washes with blurred edges over
/// a sandy bank, markers keep the app's card language but pick up a soft tint
/// per section. Ahead of the traveler the washes fade to a ghost of the course.
struct WatercolorRiverView: View {
    private let water = Color(proto: 0x6FA8B5, dark: 0x578E9B)
    private let sand = Color(proto: 0xE6D9BC, dark: 0x37332A)

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
        // Ghost of the course ahead: the same washes at a fraction of the opacity.
        RiverSpine(path: layout.river)
            .stroke(water.opacity(0.10), style: StrokeStyle(lineWidth: 34, lineCap: .round))
            .blur(radius: 2)
        // Traveled river: sandy bank underneath, then two water washes and a
        // thin highlight down the middle. Blur softens the stroke edges into
        // something closer to a wet-brush line.
        RiverSpine(path: layout.river)
            .trim(from: 0, to: layout.progress)
            .stroke(sand.opacity(0.55), style: StrokeStyle(lineWidth: 56, lineCap: .round))
            .blur(radius: 4)
        RiverSpine(path: layout.river)
            .trim(from: 0, to: layout.progress)
            .stroke(water.opacity(0.35), style: StrokeStyle(lineWidth: 36, lineCap: .round))
            .blur(radius: 2.5)
        RiverSpine(path: layout.river)
            .trim(from: 0, to: layout.progress)
            .stroke(water.opacity(0.5), style: StrokeStyle(lineWidth: 20, lineCap: .round))
            .blur(radius: 1)
        RiverSpine(path: layout.river)
            .trim(from: 0, to: layout.progress)
            .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .blur(radius: 0.5)
    }

    private func boat(at point: CGPoint) -> some View {
        Image(systemName: "sailboat.fill")
            .font(.system(size: 16))
            .foregroundStyle(Theme.accentDeep)
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            .modifier(ProtoBobbing())
            .position(point)
    }

    /// Soft tint carried by a section's markers, borrowed from the bookshelf
    /// spine palette so the journey shares DNA with the Library.
    private func tint(_ sectionIndex: Int) -> Color {
        Theme.spineGradients[sectionIndex % Theme.spineGradients.count].0
    }

    // MARK: Banners

    private func bannerView(_ banner: RiverBanner, width: CGFloat) -> some View {
        VStack(spacing: 1) {
            Text(banner.section.telugu)
                .font(Theme.sans(15, weight: .semibold))
                .foregroundStyle(Theme.textHeading)
            Text(banner.section.name)
                .font(Theme.latinSerif(12))
                .italic()
                .foregroundStyle(Theme.textTertiary)
        }
        .opacity(banner.locked ? 0.45 : 1)
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

    private func villageMarker(_ node: RiverNode) -> some View {
        ZStack {
            if node.state == .current {
                ProtoPulseRing(color: Theme.accent, size: 52)
            }
            Circle()
                .fill(Theme.card)
                .frame(width: 52, height: 52)
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
            Circle()
                .strokeBorder(
                    node.state == .current ? Theme.accent
                        : node.state == .done ? tint(node.sectionIndex).opacity(0.75)
                        : Theme.divider,
                    lineWidth: 4)
                .frame(width: 52, height: 52)
            Text(node.stop.primary)
                .font(Theme.serif(19, weight: .semibold))
                .foregroundStyle(node.state == .locked ? Theme.textTertiary : Theme.textHeading)
        }
        .opacity(node.state == .locked ? 0.55 : 1)
    }

    private func milestoneMarker(_ node: RiverNode) -> some View {
        ZStack {
            Circle()
                .fill(Theme.card)
                .frame(width: 50, height: 50)
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
            Circle()
                .strokeBorder(node.state == .locked ? Theme.divider : Theme.gold, lineWidth: 4)
                .frame(width: 50, height: 50)
            Image(systemName: "book.closed.fill")
                .font(.system(size: 17))
                .foregroundStyle(node.state == .locked ? Theme.textTertiary : Theme.gold)
        }
        .opacity(node.state == .locked ? 0.55 : 1)
    }

    private func templeMarker(_ node: RiverNode) -> some View {
        ZStack {
            Circle()
                .fill(Theme.card)
                .frame(width: 64, height: 64)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            Circle()
                .strokeBorder(
                    node.state == .done ? tint(node.sectionIndex).opacity(0.75) : Theme.divider,
                    lineWidth: 4)
                .frame(width: 64, height: 64)
            GopuramGlyph()
                .fill(node.state == .locked ? Theme.textTertiary : tint(node.sectionIndex))
                .frame(width: 26, height: 30)
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
                .position(x: node.point.x, y: node.point.y + 44)
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
            .position(x: node.point.x, y: node.point.y + 50)
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
            .position(x: node.point.x, y: node.point.y + 72)
        }
    }
}

#Preview {
    WatercolorRiverView()
}
#endif
