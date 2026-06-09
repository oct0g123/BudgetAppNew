//
//  Theme.swift
//  Ledger
//
//  Shared formatting and reusable surfaces. Colors and typography live in
//  DesignSystem.swift (DS / Typography), which is adaptive light + dark.
//

import SwiftUI

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
