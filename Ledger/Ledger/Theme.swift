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
    /// Cached: NumberFormatter init is expensive (ICU) and this runs in every
    /// money label, once or more per list row. Main-thread only, like all UI.
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()

    static func string(_ value: Double, showSign: Bool = false) -> String {
        let base = currencyFormatter.string(from: NSNumber(value: abs(value))) ?? "\(value)"
        if showSign {
            return (value < 0 ? "-" : "+") + base
        }
        return (value < 0 ? "-" : "") + base
    }

    static func percent(_ fraction: Double) -> String {
        return String(format: "%.0f%%", fraction * 100)
    }
}

// MARK: - Screen background

extension View {
    /// The app's full-screen themed background — EXCEPT on visionOS, where it's
    /// intentionally omitted so the system glass window shows through for a
    /// native panel look (opaque `DS.surface` cards still provide content
    /// contrast). iOS/iPadOS/macOS are unchanged.
    @ViewBuilder
    func screenBackground() -> some View {
        #if os(visionOS)
        self
        #else
        self.background(DS.background.ignoresSafeArea())
        #endif
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
            .background(DS.surfaceStyle)   // material on visionOS, theme color elsewhere
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

// MARK: - Money input field

/// A currency text field that formats with the locale symbol + thousands
/// separators *live* as you type (e.g. "$10,000.50"), bound to a Double.
/// Used for every money input so formatting is consistent app-wide.
struct MoneyField: View {
    var placeholder: String = "0"
    @Binding var amount: Double
    @State private var text = ""

    private static var symbol: String { Locale.current.currencySymbol ?? "$" }

    var body: some View {
        // Title + prompt: callers that show the title as a macOS form label
        // keep it; callers that hide labels still get a real placeholder
        // (on macOS a title alone renders as a label, not placeholder text).
        TextField(placeholder, text: $text, prompt: Text(placeholder))
            #if os(iOS)
            .keyboardType(.decimalPad)
            #endif
            .onAppear { text = amount == 0 ? "" : Self.display(amount) }
            .onChange(of: text) { _, newValue in
                let r = Self.reformat(newValue)
                if r.display != newValue { text = r.display }
                if abs(r.value - amount) > 0.0001 { amount = r.value }
            }
            .onChange(of: amount) { _, newValue in
                // Reflect external/programmatic changes when not actively editing.
                if abs(Self.parse(text) - newValue) > 0.0001 {
                    text = newValue == 0 ? "" : Self.display(newValue)
                }
            }
    }

    static func parse(_ s: String) -> Double {
        Double(s.filter { $0.isNumber || $0 == "." }) ?? 0
    }

    /// Cached — `display`/`reformat` run on every keystroke.
    private static let decimalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f
    }()

    private static let groupingFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    static func display(_ value: Double) -> String {
        symbol + (decimalFormatter.string(from: NSNumber(value: value)) ?? "0")
    }

    /// Re-group the integer part live while preserving an in-progress decimal.
    static func reformat(_ s: String) -> (display: String, value: Double) {
        var seenDot = false, intPart = "", fracPart = ""
        for ch in s {
            if ch.isNumber {
                if seenDot { if fracPart.count < 2 { fracPart.append(ch) } }
                else { intPart.append(ch) }
            } else if ch == "." && !seenDot {
                seenDot = true
            }
        }
        if intPart.isEmpty && !seenDot { return ("", 0) }   // empty → show the placeholder
        let intValue = Int(intPart) ?? 0
        let groupedInt = groupingFormatter.string(from: NSNumber(value: intValue)) ?? "0"
        let display = symbol + groupedInt + (seenDot ? "." + fracPart : "")
        let numeric = (intPart.isEmpty ? "0" : intPart) + (fracPart.isEmpty ? "" : "." + fracPart)
        return (display, Double(numeric) ?? 0)
    }
}
