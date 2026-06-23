//
//  DesignSystem.swift
//  Ledger
//
//  Phase 1 of the redesign: the foundation only. This file is ADDITIVE — it
//  doesn't change any existing screen. It introduces:
//    • DS      — adaptive (light + dark) semantic colors
//    • Typography — a Dynamic Type-aware type scale with custom-font support
//                   (Playfair Display / DM Mono) that gracefully falls back to
//                   the system serif / monospaced faces until the .ttf files
//                   are bundled
//    • Spacing / Radius — layout tokens
//
//  As of Phase 2, every screen uses this system; the old dark-only Palette and
//  Font helpers have been removed from Theme.swift.
//

import SwiftUI
import CoreText
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Adaptive color helper

extension Color {
    /// Resolves to `light` or `dark` depending on the active appearance.
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #elseif canImport(AppKit)
        self = Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return isDark ? NSColor(dark) : NSColor(light)
        })
        #else
        self = dark
        #endif
    }
}

// MARK: - Semantic palette (theme-aware, light + dark)

/// Semantic color tokens. Each resolves against the *active theme's* palette
/// (see Theming.swift), which is cached, so these reads are cheap. Every color
/// is a dynamic light/dark `Color`, so themes follow the system appearance.
///
/// Call sites are unchanged from when these were static constants — `DS.gold`,
/// `DS.surface`, etc. still work. (`gold`/`goldDim` are the accent slots; the
/// `accent`/`accentDim` aliases read the same values for clarity in new code.)
enum DS {
    private static var p: ThemePalette { ThemeManager.shared.palette }

    // Backgrounds & structure
    static var background:  Color { p.background }
    static var surface:     Color { p.surface }
    static var surfaceHigh: Color { p.surfaceHigh }
    static var hairline:    Color { p.hairline }

    // Text
    static var text:        Color { p.text }
    static var textMuted:   Color { p.textMuted }

    // Accent
    static var gold:        Color { p.accent }
    static var goldDim:     Color { p.accentDim }
    static var accent:      Color { p.accent }
    static var accentDim:   Color { p.accentDim }

    // Category tones
    static var needs:       Color { p.needs }
    static var savings:     Color { p.savings }
    static var wants:       Color { p.wants }

    static func category(_ c: BudgetCategory) -> Color {
        switch c {
        case .needs:   return needs
        case .savings: return savings
        case .wants:   return wants
        }
    }
}

// MARK: - Typography

/// A type scale built on system text styles, so everything scales with Dynamic
/// Type. Uses Playfair Display (serif headings) and DM Mono (figures) when those
/// fonts are bundled; otherwise falls back to the system serif / monospaced
/// designs automatically.
///
/// The bundled .ttf files are registered at launch via `registerBundledFonts()`
/// (called from LedgerApp), so no Info.plist entries are needed. If a font ever
/// fails to register, the system serif / monospaced designs are used instead.
enum Typography {

    /// Variable-font family name for Playfair Display.
    private static let serifFamily = "Playfair Display"

    private static let hasSerif = fontExists(serifFamily)
    private static let hasMono  = fontExists("DMMono-Regular")

    /// Register the bundled font files with CoreText at app launch.
    static func registerBundledFonts() {
        for file in ["PlayfairDisplay-VF", "DMMono-Regular", "DMMono-Medium", "DMMono-Light"] {
            if let url = Bundle.main.url(forResource: file, withExtension: "ttf") {
                _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    /// Display face for titles/headings. In the editorial theme this is Playfair
    /// Display (variable font, weight via the weight axis); the `system` themes
    /// use the platform font for a clean, native feel.
    static func serif(_ style: Font.TextStyle = .title, weight: Font.Weight = .semibold) -> Font {
        switch ThemeManager.shared.fontStyle {
        case .editorial:
            if hasSerif {
                return .custom(serifFamily, size: baseSize(style), relativeTo: style).weight(weight)
            }
            return .system(style, design: .serif, weight: weight)
        case .system:
            return .system(style, design: .default, weight: weight)
        }
    }

    /// Face for figures / amounts. Editorial uses DM Mono; the `system` themes
    /// use the platform font with monospaced digits so columns of numbers still
    /// align without looking like a code editor.
    static func mono(_ style: Font.TextStyle = .body, weight: Font.Weight = .regular) -> Font {
        switch ThemeManager.shared.fontStyle {
        case .editorial:
            if hasMono {
                return .custom(monoName(weight), size: baseSize(style), relativeTo: style)
            }
            return .system(style, design: .monospaced, weight: weight)
        case .system:
            return .system(style, weight: weight).monospacedDigit()
        }
    }

    /// Standard body / UI text (system).
    static func body(_ style: Font.TextStyle = .body, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .default, weight: weight)
    }

    // MARK: Helpers

    private static func monoName(_ w: Font.Weight) -> String {
        switch w {
        case .medium, .semibold, .bold, .heavy, .black: return "DMMono-Medium"
        case .light, .thin, .ultraLight:                return "DMMono-Light"
        default:                                        return "DMMono-Regular"
        }
    }

    private static func baseSize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle:  return 34
        case .title:       return 28
        case .title2:      return 22
        case .title3:      return 20
        case .headline:    return 17
        case .body:        return 17
        case .callout:     return 16
        case .subheadline: return 15
        case .footnote:    return 13
        case .caption:     return 12
        case .caption2:    return 11
        @unknown default:  return 17
        }
    }

    private static func fontExists(_ name: String) -> Bool {
        #if canImport(UIKit)
        return UIFont(name: name, size: 10) != nil
        #elseif canImport(AppKit)
        return NSFont(name: name, size: 10) != nil
        #else
        return false
        #endif
    }
}

// MARK: - Layout tokens

enum Spacing {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 12
    static let lg:  CGFloat = 16
    static let xl:  CGFloat = 20
    static let xxl: CGFloat = 28
}

enum Radius {
    static let field: CGFloat = 10
    static let card:  CGFloat = 16
    static let pill:  CGFloat = 980
}

// MARK: - Adaptive layout

extension View {
    /// Caps content to a comfortable reading width on large screens (iPad, Mac,
    /// Vision Pro) and centers it, so lists and cards don't stretch edge-to-edge.
    /// A no-op on iPhone, whose screen is already narrower than the cap — so it
    /// never changes the phone layout.
    func readableContentWidth(_ maxWidth: CGFloat = 720) -> some View {
        frame(maxWidth: maxWidth).frame(maxWidth: .infinity)
    }
}

// MARK: - Preview (verifies light + dark without touching the app)

#Preview("Design System") {
    ScrollView {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Ledger")
                    .font(Typography.serif(.largeTitle, weight: .bold))
                    .foregroundStyle(DS.text)
                Text("$4,820.00")
                    .font(Typography.mono(.title, weight: .medium))
                    .foregroundStyle(DS.gold)
                Text("Needs 50% · Savings 20% · Wants 30%")
                    .font(Typography.mono(.footnote))
                    .foregroundStyle(DS.textMuted)
            }

            ForEach(BudgetCategory.allCases) { c in
                HStack(spacing: Spacing.md) {
                    Circle().fill(DS.category(c)).frame(width: 12, height: 12)
                    Text(c.title).font(Typography.serif(.headline)).foregroundStyle(DS.text)
                    Spacer()
                    Text("$1,234").font(Typography.mono(.body, weight: .medium)).foregroundStyle(DS.text)
                }
                .padding(Spacing.lg)
                .background(DS.surface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(DS.hairline, lineWidth: 1))
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(DS.background)
}
