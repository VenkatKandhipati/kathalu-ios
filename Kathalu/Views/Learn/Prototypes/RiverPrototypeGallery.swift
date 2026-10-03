#if DEBUG
import SwiftUI

/// DEBUG-only gallery comparing the Journey tab river prototypes side by side.
/// Reached from a debug row at the bottom of the Learn tab. Delete the whole
/// Prototypes folder once a direction is chosen.
struct RiverPrototypeGallery: View {
    enum Style: String, CaseIterable, Identifiable {
        case ink = "Ink map"
        case watercolor = "Watercolor"
        case cartoon = "Cartoon"
        var id: String { rawValue }
    }

    @State private var style: Style = .cartoon

    var body: some View {
        Group {
            switch style {
            case .ink: InkMapRiverView()
            case .watercolor: WatercolorRiverView()
            case .cartoon: CartoonRiverView()
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("Style", selection: $style) {
                ForEach(Style.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.thinMaterial)
        }
        .navigationTitle("River prototypes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

#Preview {
    NavigationStack {
        RiverPrototypeGallery()
    }
}
#endif
