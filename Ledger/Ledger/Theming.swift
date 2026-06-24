//
//  Theming.swift
//  Ledger
//
//  Runtime-switchable themes. The whole app reads its colors through `DS`
//  (DesignSystem.swift) and its fonts through `Typography`. Both of those now
//  resolve against the *active theme's* palette, which lives here.
//
//  Design goals:
//    • Zero churn at call sites — `DS.gold`, `DS.surface`, `Typography.serif(…)`
//      etc. are unchanged everywhere. Only their backing values move.
//    • No real performance cost — the active palette is built once per theme
//      switch and cached; every `DS.x` access is just a struct property read.
//    • Light + dark per theme — every color is a `Color(light:dark:)`, so each
//      theme follows the system appearance automatically.
//
//  Adding a theme = add a `case` and one `palette` entry. Nothing else changes.
//

import SwiftUI

// MARK: - Font style

/// Which type system a theme uses. `editorial` is the original Playfair +
/// DM Mono look; `system` uses the platform's font (SF) with monospaced digits
/// for figures — the clean, native feel.
enum ThemeFontStyle {
    case editorial
    case system
}

// MARK: - Palette

/// A complete set of resolved color tokens for one theme. Each `Color` is a
/// dynamic light/dark color, so a single palette covers both appearances.
struct ThemePalette {
    let background: Color
    let surface: Color
    let surfaceHigh: Color
    let hairline: Color
    let text: Color
    let textMuted: Color
    let accent: Color       // primary accent / tint (the "gold" slot)
    let accentDim: Color    // dimmed accent (section labels — the "goldDim" slot)
    let needs: Color
    let savings: Color
    let wants: Color
    let over: Color         // over-budget alarm — its own color, not a category's
    let fontStyle: ThemeFontStyle
}

/// Light/dark color from two hex values — local shorthand used by the palettes.
private func c(_ light: UInt32, _ dark: UInt32) -> Color {
    Color(light: Color(hex: light), dark: Color(hex: dark))
}

// MARK: - Themes

/// The user-selectable themes. `ledger` is the default and reproduces the
/// original editorial look exactly.
enum AppTheme: String, CaseIterable, Identifiable {
    case ledger
    case minimal
    case modern

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ledger:  return "Ledger"
        case .minimal: return "Minimal"
        case .modern:  return "Modern"
        }
    }

    var subtitle: String {
        switch self {
        case .ledger:  return "The original — warm, editorial, serif"
        case .minimal: return "Quiet monochrome, system font"
        case .modern:  return "Clean and colorful, like the system apps"
        }
    }

    /// Builds the palette for this theme. Called only by `ThemeManager` (once per
    /// switch); the result is cached, so this is never on a hot path.
    var palette: ThemePalette {
        switch self {

        // The current design, unchanged.
        case .ledger:
            return ThemePalette(
                background:  c(0xF6F1E6, 0x141210),
                surface:     c(0xFFFFFF, 0x1E1B17),
                surfaceHigh: c(0xEFE8D8, 0x2A251F),
                hairline:    c(0xE2D8C6, 0x3A332B),
                text:        c(0x2A211A, 0xEDE6DA),
                textMuted:   c(0x7C6F5C, 0x9A8F7E),
                accent:      c(0xA9842F, 0xCBA85A),
                accentDim:   c(0x8A6B25, 0x8A7338),
                needs:       c(0xA85F37, 0xB5734A),
                savings:     c(0x5E6E4D, 0x7F8F6E),
                wants:       c(0xB1872C, 0xCBA85A),
                over:        c(0xC0392B, 0xDA5A47),
                fontStyle:   .editorial
            )

        // Minimal & monochrome: greys only, near-black/near-white accent.
        case .minimal:
            return ThemePalette(
                background:  c(0xF4F4F5, 0x09090B),
                surface:     c(0xFFFFFF, 0x18181B),
                surfaceHigh: c(0xE4E4E7, 0x27272A),
                hairline:    c(0xE4E4E7, 0x27272A),
                text:        c(0x18181B, 0xFAFAFA),
                textMuted:   c(0x71717A, 0xA1A1AA),
                accent:      c(0x18181B, 0xFAFAFA),
                accentDim:   c(0x52525B, 0xD4D4D8),
                needs:       c(0x27272A, 0xE4E4E7),
                savings:     c(0x71717A, 0xA1A1AA),
                wants:       c(0xA1A1AA, 0x71717A),
                over:        c(0xDC2626, 0xF87171),
                fontStyle:   .system
            )

        // Clean like the system apps: grouped backgrounds, system accent colors.
        case .modern:
            return ThemePalette(
                background:  c(0xF2F2F7, 0x000000),
                surface:     c(0xFFFFFF, 0x1C1C1E),
                surfaceHigh: c(0xEFEFF4, 0x2C2C2E),
                hairline:    c(0xD1D1D6, 0x38383A),
                text:        c(0x1C1C1E, 0xFFFFFF),
                textMuted:   c(0x8A8A8E, 0x98989F),
                accent:      c(0x007AFF, 0x0A84FF),
                accentDim:   c(0x8A8A8E, 0x8E8E93),
                needs:       c(0xFF9500, 0xFF9F0A),
                savings:     c(0x34C759, 0x30D158),
                wants:       c(0x5856D6, 0x5E5CE6),
                over:        c(0xFF3B30, 0xFF453A),
                fontStyle:   .system
            )
        }
    }
}

// MARK: - Theme manager

/// Single source of truth for the active theme. `DS` and `Typography` read
/// `ThemeManager.shared` to resolve their values; views observe it so a switch
/// restyles the whole app.
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private static let storageKey = "appThemeID"

    @Published private(set) var theme: AppTheme
    /// Cached palette for the active theme — rebuilt only when `theme` changes.
    @Published private(set) var palette: ThemePalette

    var fontStyle: ThemeFontStyle { palette.fontStyle }

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.storageKey)
        let resolved = saved.flatMap(AppTheme.init(rawValue:)) ?? .ledger
        theme = resolved
        palette = resolved.palette
    }

    func setTheme(_ newTheme: AppTheme) {
        guard newTheme != theme else { return }
        theme = newTheme
        palette = newTheme.palette
        UserDefaults.standard.set(newTheme.rawValue, forKey: Self.storageKey)
    }
}
