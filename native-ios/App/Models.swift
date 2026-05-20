import SwiftUI

/// A design = compact pill content for the Dynamic Island, with a stable id.
/// Adding a new design = one struct entry in DesignCatalog + one `case` in `Designs.view`.
struct Design: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String

    static func == (l: Design, r: Design) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Display order of categories (matches the HTML prototype).
enum DesignCategory {
    static let order: [String] = ["DEVICE", "MEDIA", "WEATHER", "HEALTH", "TIME", "FUN"]
}

/// Theme tokens — matches the monochrome JetBrains Mono aesthetic.
enum Theme {
    static let bg          = Color(hex: 0x0A0A0A)
    static let bg2         = Color(hex: 0x0E0E0E)
    static let surface     = Color(hex: 0x141414)
    static let surface2    = Color(hex: 0x1A1A1A)
    static let surface3    = Color(hex: 0x222222)
    static let line        = Color(hex: 0x1D1D1D)
    static let line2       = Color(hex: 0x2A2A2A)
    static let line3       = Color(hex: 0x3A3A3A)
    static let line4       = Color(hex: 0x555555)
    static let text        = Color(hex: 0xFAFAFA)
    static let text2       = Color(hex: 0x9A9A9A)
    static let text3       = Color(hex: 0x5A5A5A)
    static let text4       = Color(hex: 0x333333)
    static let hi          = Color(hex: 0xFFFFFF)
    static let hiDim       = Color(hex: 0xC8C8C8)

    static let monoFont = "JetBrainsMono-Regular"
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // Use system monospaced if JetBrains Mono isn't bundled.
        // Drop the .ttf into Resources and add to Info.plist UIAppFonts to use the named font.
        return .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
