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

// MARK: - Semantic palette (light + dark)

/// Warm editorial palette. Dark mode keeps the existing near-black/gold mood;
/// light mode is a warm "paper" theme with the same accent family.
enum DS {
    // Backgrounds & structure
    static let background  = Color(light: Color(hex: 0xF6F1E6), dark: Color(hex: 0x141210))
    static let surface     = Color(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x1E1B17))
    static let surfaceHigh = Color(light: Color(hex: 0xEFE8D8), dark: Color(hex: 0x2A251F))
    static let hairline    = Color(light: Color(hex: 0xE2D8C6), dark: Color(hex: 0x3A332B))

    // Text
    static let text        = Color(light: Color(hex: 0x2A211A), dark: Color(hex: 0xEDE6DA))
    static let textMuted   = Color(light: Color(hex: 0x7C6F5C), dark: Color(hex: 0x9A8F7E))

    // Accent
    static let gold        = Color(light: Color(hex: 0xA9842F), dark: Color(hex: 0xCBA85A))
    static let goldDim     = Color(light: Color(hex: 0x8A6B25), dark: Color(hex: 0x8A7338))

    // Category earth tones (tuned for contrast in both appearances)
    static let needs       = Color(light: Color(hex: 0xA85F37), dark: Color(hex: 0xB5734A))
    static let savings     = Color(light: Color(hex: 0x5E6E4D), dark: Color(hex: 0x7F8F6E))
    static let wants       = Color(light: Color(hex: 0xB1872C), dark: Color(hex: 0xCBA85A))

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
/// To enable the custom fonts: add the .ttf files to the target, list them under
/// "Fonts provided by application" in Info.plist, and make sure the PostScript
/// names match those below (e.g. "PlayfairDisplay-Bold", "DMMono-Medium").
enum Typography {

    private static let hasSerif = fontExists("PlayfairDisplay-Regular") || fontExists("Playfair Display")
    private static let hasMono  = fontExists("DMMono-Regular") || fontExists("DM Mono")

    /// Serif display face (titles, headings).
    static func serif(_ style: Font.TextStyle = .title, weight: Font.Weight = .semibold) -> Font {
        if hasSerif {
            return .custom(serifName(weight), size: baseSize(style), relativeTo: style)
        }
        return .system(style, design: .serif, weight: weight)
    }

    /// Monospaced face for figures / amounts.
    static func mono(_ style: Font.TextStyle = .body, weight: Font.Weight = .regular) -> Font {
        if hasMono {
            return .custom(monoName(weight), size: baseSize(style), relativeTo: style)
        }
        return .system(style, design: .monospaced, weight: weight)
    }

    /// Standard body / UI text (system).
    static func body(_ style: Font.TextStyle = .body, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .default, weight: weight)
    }

    // MARK: Helpers

    private static func serifName(_ w: Font.Weight) -> String {
        switch w {
        case .bold, .heavy, .black: return "PlayfairDisplay-Bold"
        case .semibold:             return "PlayfairDisplay-SemiBold"
        case .medium:               return "PlayfairDisplay-Medium"
        default:                    return "PlayfairDisplay-Regular"
        }
    }

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
