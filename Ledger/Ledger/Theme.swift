//
//  Theme.swift
//  Ledger
//
//  Dark editorial theme: warm gold accent, serif headings, monospaced numbers,
//  muted earth tones.
//
//  Fonts: the brief calls for Playfair Display (headings) and DM Mono
//  (numbers). To keep the project buildable with zero bundled assets, we
//  approximate them with the system serif (New York) and the system monospaced
//  face (SF Mono). To use the real fonts, drop the .ttf files into the app
//  target, list them under "Fonts provided by application" in Info.plist, and
//  swap the `Font.system(...)` calls below for `Font.custom("Playfair Display"...)`
//  and `Font.custom("DMMono-Regular"...)`.
//

import SwiftUI

// MARK: - Palette

enum Palette {
    static let background  = Color(hex: 0x141210) // near-black warm brown
    static let surface     = Color(hex: 0x1E1B17) // card
    static let surfaceHigh = Color(hex: 0x2A251F) // raised card / fields
    static let hairline    = Color(hex: 0x3A332B)

    static let gold        = Color(hex: 0xCBA85A) // warm gold accent
    static let goldDim     = Color(hex: 0x8A7338)

    static let text        = Color(hex: 0xEDE6DA) // warm off-white
    static let textMuted   = Color(hex: 0x9A8F7E) // muted taupe

    // Category earth tones
    static let needs       = Color(hex: 0xB5734A) // terracotta
    static let savings     = Color(hex: 0x7F8F6E) // sage / olive
    static let wants       = Color(hex: 0xCBA85A) // gold/amber

    static func color(for category: BudgetCategory) -> Color {
        switch category {
        case .needs:   return needs
        case .savings: return savings
        case .wants:   return wants
        }
    }
}

// MARK: - Fonts

extension Font {
    /// Serif display face (approximating Playfair Display).
    static func serif(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Monospaced face for figures (approximating DM Mono).
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Currency formatting

enum Money {
    static func string(_ value: Double, showSign: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        let base = formatter.string(from: NSNumber(value: abs(value))) ?? "\(value)"
        if showSign {
            return (value < 0 ? "-" : "+") + base
        }
        return (value < 0 ? "-" : "") + base
    }

    static func percent(_ fraction: Double) -> String {
        return String(format: "%.0f%%", fraction * 100)
    }
}

// MARK: - Color hex helper

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

// MARK: - Reusable surfaces

/// A rounded card in the surface color.
struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(DS.hairline, lineWidth: 1)
            )
    }
}

/// Small uppercase section label in muted gold.
struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(Typography.mono(.caption2, weight: .medium))
            .tracking(2)
            .foregroundStyle(DS.goldDim)
    }
}
