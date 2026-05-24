// Theme · color tokens shared across every screen
//
// Mirrors the web app's CSS variables. Three themes (dark / midnight / paper)
// pick a different palette; views read from `Theme.current` reactively.

import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case dark, midnight, paper
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dark:     return "DARK"
        case .midnight: return "MIDNIGHT"
        case .paper:    return "PAPER"
        }
    }
}

struct Palette {
    let bg: Color
    let bg2: Color
    let surface: Color
    let surface2: Color
    let surface3: Color
    let line: Color
    let line2: Color
    let line3: Color
    let line4: Color
    let text: Color
    let text2: Color
    let text3: Color
    let text4: Color
    let hi: Color
    let hiDim: Color

    static let dark = Palette(
        bg:      Color(hex: 0x0a0a0a),
        bg2:     Color(hex: 0x0e0e0e),
        surface: Color(hex: 0x141414),
        surface2: Color(hex: 0x1a1a1a),
        surface3: Color(hex: 0x222222),
        line:     Color(hex: 0x1d1d1d),
        line2:    Color(hex: 0x2a2a2a),
        line3:    Color(hex: 0x3a3a3a),
        line4:    Color(hex: 0x555555),
        text:     Color(hex: 0xfafafa),
        text2:    Color(hex: 0x9a9a9a),
        text3:    Color(hex: 0x5a5a5a),
        text4:    Color(hex: 0x333333),
        hi:       Color(hex: 0xffffff),
        hiDim:    Color(hex: 0xc8c8c8)
    )

    static let midnight = Palette(
        bg:      Color(hex: 0x050505),
        bg2:     Color(hex: 0x080808),
        surface: Color(hex: 0x0e0e0e),
        surface2: Color(hex: 0x131313),
        surface3: Color(hex: 0x1a1a1a),
        line: dark.line, line2: dark.line2, line3: dark.line3, line4: dark.line4,
        text: dark.text, text2: dark.text2, text3: dark.text3, text4: dark.text4,
        hi: dark.hi, hiDim: dark.hiDim
    )

    static let paper = Palette(
        bg:      Color(hex: 0xf5f5f5),
        bg2:     Color(hex: 0xefefef),
        surface: Color(hex: 0xffffff),
        surface2: Color(hex: 0xfafafa),
        surface3: Color(hex: 0xececec),
        line:     Color(hex: 0xe2e2e2),
        line2:    Color(hex: 0xd4d4d4),
        line3:    Color(hex: 0xb8b8b8),
        line4:    Color(hex: 0x909090),
        text:     Color(hex: 0x0a0a0a),
        text2:    Color(hex: 0x4a4a4a),
        text3:    Color(hex: 0x707070),
        text4:    Color(hex: 0xb0b0b0),
        hi:       Color(hex: 0x0a0a0a),
        hiDim:    Color(hex: 0x2a2a2a)
    )
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xff) / 255
        let g = Double((hex >> 8) & 0xff) / 255
        let b = Double(hex & 0xff) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// EnvironmentKey so any view can read the current palette.
private struct PaletteKey: EnvironmentKey {
    static let defaultValue: Palette = .dark
}
extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

extension AppTheme {
    var palette: Palette {
        switch self {
        case .dark:     return .dark
        case .midnight: return .midnight
        case .paper:    return .paper
        }
    }
}

// MARK: - App font

/// Global text design. Combines a `Font.Design` (system / rounded / serif /
/// mono) with an optional `Font.Width` (default / condensed / expanded). Both
/// cascade through `.fontDesign(...)` and `.fontWidth(...)` so every system
/// font in the app re-renders when you switch options.
enum AppFont: String, CaseIterable, Identifiable, Codable {
    case system            // SF · default width  ← DEFAULT
    case systemCondensed   // SF · condensed
    case systemExpanded    // SF · expanded
    case rounded           // SF Rounded · default
    case roundedExpanded   // SF Rounded · expanded
    case serif             // New York · default
    case serifExpanded     // New York · expanded
    case mono              // SF Mono · default

    static let `default`: AppFont = .system

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system:           return "SYSTEM"
        case .systemCondensed:  return "CONDENSED"
        case .systemExpanded:   return "EXPANDED"
        case .rounded:          return "ROUNDED"
        case .roundedExpanded:  return "ROUNDED WIDE"
        case .serif:            return "SERIF"
        case .serifExpanded:    return "SERIF WIDE"
        case .mono:             return "MONO"
        }
    }

    var design: Font.Design {
        switch self {
        case .system, .systemCondensed, .systemExpanded:
            return .default
        case .rounded, .roundedExpanded:
            return .rounded
        case .serif, .serifExpanded:
            return .serif
        case .mono:
            return .monospaced
        }
    }

    var width: Font.Width {
        switch self {
        case .systemCondensed:
            return .condensed
        case .systemExpanded, .roundedExpanded, .serifExpanded:
            return .expanded
        default:
            return .standard
        }
    }
}
