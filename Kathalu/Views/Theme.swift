import SwiftUI

/// Design tokens lifted from the Kathalu iOS design canvas and the web app's
/// CSS variables (light / dark pairs).
enum Theme {
    static let accent = Color(light: 0xB5531A, dark: 0xD4743A)
    static let accentDeep = Color(light: 0x983F13, dark: 0xB55E28)
    static let background = Color(light: 0xF7F3EA, dark: 0x1A1A1A)
    static let pageBackground = Color(light: 0xF5EFE3, dark: 0x252525)
    static let card = Color(light: 0xFEFCF7, dark: 0x2E2C28)
    static let cardBorder = Color(light: 0xEFE7D6, dark: 0x3D3A34)
    static let divider = Color(light: 0xEAE1CF, dark: 0x3D3A34)
    static let textHeading = Color(light: 0x3A2A10, dark: 0xE8DCC8)
    static let textBody = Color(light: 0x2A2622, dark: 0xE0DDD6)
    static let textSecondary = Color(light: 0x7A6E58, dark: 0xA89F8C)
    static let textTertiary = Color(light: 0xA79C89, dark: 0x8A8272)
    static let phonetic = Color(light: 0x8A6000, dark: 0xD4A830)
    static let meaning = Color(light: 0x1A6B3A, dark: 0x4AB870)
    static let green = Color(light: 0x6B8F3A, dark: 0x8AB450)
    static let gold = Color(light: 0xC8A96E, dark: 0xD4B478)
    static let heatEmpty = Color(light: 0xE7DECB, dark: 0x3A372F)

    // Flashcard rating buttons (from the design's review screen).
    static let rateAgain = Color(hex: 0xB5451A)
    static let rateHard = Color(hex: 0x9A8428)
    static let rateGood = Color(hex: 0x3A6A9E)
    static let rateEasy = Color(hex: 0x4E7F30)

    /// Book spine gradients rotated across the shelf (from library.html).
    static let spineGradients: [(Color, Color)] = [
        (Color(hex: 0x8B4513), Color(hex: 0xA0522D)),
        (Color(hex: 0x2C5F4A), Color(hex: 0x3A7D65)),
        (Color(hex: 0x4A3570), Color(hex: 0x6B4D8A)),
        (Color(hex: 0x8B2252), Color(hex: 0xA83268)),
        (Color(hex: 0x2E4A7A), Color(hex: 0x3D60A0)),
        (Color(hex: 0x9C7A48), Color(hex: 0xB5915A)),
    ]

    static func spineGradient(for index: Int) -> LinearGradient {
        let (from, to) = spineGradients[index % spineGradients.count]
        return LinearGradient(colors: [from, to], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func ringColor(pct: Int) -> Color {
        if pct >= 80 { return green }
        if pct >= 50 { return gold }
        return accent
    }

    // MARK: Fonts (bundled Noto Telugu variable fonts)

    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Noto Serif Telugu", size: size).weight(weight)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Noto Sans Telugu", size: size).weight(weight)
    }

    /// Georgia-style latin serif used for romanizations and numerals in the design.
    static func latinSerif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }

    init(light: UInt32, dark: UInt32) {
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
