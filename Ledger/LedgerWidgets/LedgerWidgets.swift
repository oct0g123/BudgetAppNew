import WidgetKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Shared snapshot (mirror of the app's BudgetSnapshot)

struct BudgetSnapshot: Codable {
    var monthKey: String
    var monthName: String
    var shortMonthName: String
    var safeToSpend: Double
    var needsSpent: Double
    var needsBudget: Double
    var savingsSpent: Double
    var savingsBudget: Double
    var wantsSpent: Double
    var wantsBudget: Double
    var savingsRate: Double
    var updatedAt: Date

    var needsRemaining: Double { needsBudget - needsSpent }
    var wantsRemaining: Double { wantsBudget - wantsSpent }
    var savingsProgress: Double { savingsBudget > 0 ? savingsSpent / savingsBudget : 0 }

    static func load() -> BudgetSnapshot? {
        guard let data = UserDefaults(suiteName: "group.com.anthonystacy.Ledger")?
                .data(forKey: "currentBudgetSnapshot"),
              let snap = try? JSONDecoder().decode(BudgetSnapshot.self, from: data) else { return nil }
        return snap
    }

    static let placeholder = BudgetSnapshot(
        monthKey: "", monthName: "This Month", shortMonthName: "—",
        safeToSpend: 0, needsSpent: 0, needsBudget: 0,
        savingsSpent: 0, savingsBudget: 0, wantsSpent: 0, wantsBudget: 0,
        savingsRate: 0, updatedAt: Date())
}

/// Cached — formatter init is expensive and the widget extension is
/// CPU/memory budgeted; BucketsView alone calls this 8× per render.
private let widgetMoneyFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.maximumFractionDigits = 0
    f.locale = .current
    return f
}()

func widgetMoney(_ value: Double) -> String {
    widgetMoneyFormatter.string(from: NSNumber(value: value)) ?? "$0"
}

// MARK: - Colors (mirror of the app's palette)

private extension Color {
    init(hex: UInt) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
    static func adaptive(light: UInt, dark: UInt) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light)) })
        #elseif canImport(AppKit)
        // Resolve per the effective appearance so the macOS widget tracks
        // light/dark instead of being pinned to the dark palette.
        return Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(Color(hex: isDark ? dark : light))
        })
        #else
        return Color(hex: dark)
        #endif
    }
}

enum WDS {
    static let background = Color.adaptive(light: 0xF6F1E6, dark: 0x141210)
    static let text       = Color.adaptive(light: 0x2A211A, dark: 0xEDE6DA)
    static let textMuted  = Color.adaptive(light: 0x7C6F5C, dark: 0x9A8F7E)
    static let gold       = Color.adaptive(light: 0xA9842F, dark: 0xCBA85A)
    static let needs      = Color.adaptive(light: 0xA85F37, dark: 0xB5734A)
    static let savings    = Color.adaptive(light: 0x5E6E4D, dark: 0x7F8F6E)
    static let wants      = Color.adaptive(light: 0xB1872C, dark: 0xCBA85A)
}

// MARK: - Timeline

struct Entry: TimelineEntry {
    let date: Date
    let snapshot: BudgetSnapshot
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: Date(), snapshot: .placeholder) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: Date(), snapshot: BudgetSnapshot.load() ?? .placeholder))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entry = Entry(date: Date(), snapshot: BudgetSnapshot.load() ?? .placeholder)
        let refresh = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date().addingTimeInterval(7200)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

struct WidgetBG: ViewModifier {
    @Environment(\.widgetFamily) private var family
    func body(content: Content) -> some View {
        switch family {
        case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge:
            content.containerBackground(WDS.background, for: .widget)
        default:
            content.containerBackground(.clear, for: .widget)
        }
    }
}

// MARK: - Safe to Spend

struct SafeToSpendWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SafeToSpendWidget", provider: Provider()) { entry in
            SafeToSpendView(snapshot: entry.snapshot)
                .widgetURL(URL(string: "ledger://budget"))
                .modifier(WidgetBG())
        }
        .configurationDisplayName("Safe to Spend")
        .description("What's left to spend this month, with savings set aside.")
        // Lock Screen accessory families are iOS-only; macOS gets the small widget.
        #if os(iOS)
        .supportedFamilies([.systemSmall, .accessoryInline, .accessoryRectangular])
        #else
        .supportedFamilies([.systemSmall])
        #endif
    }
}

struct SafeToSpendView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: BudgetSnapshot
    private var over: Bool { snapshot.safeToSpend < 0 }
    /// Safe-to-spend can't sensibly be negative — floor at $0 when over.
    private var headline: String { widgetMoney(max(snapshot.safeToSpend, 0)) }
    private var overBy: String { widgetMoney(abs(snapshot.safeToSpend)) }

    var body: some View {
        switch family {
        #if os(iOS)
        case .accessoryInline:
            Text(over ? "\(snapshot.shortMonthName) · \(overBy) over"
                      : "\(snapshot.shortMonthName) · \(headline) left")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("SAFE TO SPEND").font(.caption2).widgetAccentable()
                Text(headline).font(.title3.weight(.semibold))
                Text(over ? "Over by \(overBy)"
                          : "\(widgetMoney(snapshot.needsRemaining)) needs · \(widgetMoney(snapshot.wantsRemaining)) wants")
                    .font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
            }
        #endif
        default:
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.shortMonthName.uppercased())
                    .font(.caption2.weight(.semibold)).foregroundStyle(WDS.textMuted)
                Spacer(minLength: 0)
                Text(headline)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(WDS.text)
                    .minimumScaleFactor(0.5).lineLimit(1)
                Text(over ? "over by \(overBy)" : "left to spend")
                    .font(.caption)
                    .foregroundStyle(over ? WDS.needs : WDS.textMuted)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                HStack(spacing: 3) {
                    miniBar(WDS.needs, snapshot.needsSpent, snapshot.needsBudget)
                    miniBar(WDS.savings, snapshot.savingsSpent, snapshot.savingsBudget)
                    miniBar(WDS.wants, snapshot.wantsSpent, snapshot.wantsBudget)
                }
                .frame(height: 5)
            }
        }
    }

    private func miniBar(_ color: Color, _ spent: Double, _ budget: Double) -> some View {
        GeometryReader { geo in
            let frac = budget > 0 ? min(spent / budget, 1) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.25))
                Capsule().fill(color).frame(width: geo.size.width * frac)
            }
        }
    }
}

// MARK: - Buckets

struct BucketsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BucketsWidget", provider: Provider()) { entry in
            BucketsView(snapshot: entry.snapshot)
                .widgetURL(URL(string: "ledger://budget"))
                .modifier(WidgetBG())
        }
        .configurationDisplayName("Buckets")
        .description("Needs, Savings and Wants at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

struct BucketsView: View {
    let snapshot: BudgetSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(snapshot.monthName).font(.headline).foregroundStyle(WDS.text)
                Spacer()
                Text(snapshot.safeToSpend >= 0
                     ? "\(widgetMoney(snapshot.safeToSpend)) left"
                     : "over by \(widgetMoney(abs(snapshot.safeToSpend)))")
                    .font(.caption.weight(.medium)).foregroundStyle(WDS.textMuted)
            }
            row("Needs", WDS.needs, snapshot.needsSpent, snapshot.needsBudget, savings: false)
            row("Savings", WDS.savings, snapshot.savingsSpent, snapshot.savingsBudget, savings: true)
            row("Wants", WDS.wants, snapshot.wantsSpent, snapshot.wantsBudget, savings: false)
        }
    }

    private func row(_ name: String, _ color: Color, _ spent: Double, _ budget: Double, savings: Bool) -> some View {
        let frac = budget > 0 ? min(spent / budget, 1) : 0
        let alarm = spent > budget && !savings
        return VStack(spacing: 3) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(name).font(.caption.weight(.medium)).foregroundStyle(WDS.text)
                Spacer()
                Text("\(widgetMoney(spent)) / \(widgetMoney(budget))")
                    .font(.caption2).foregroundStyle(WDS.textMuted)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.22))
                    Capsule().fill(alarm ? WDS.needs : color).frame(width: geo.size.width * frac)
                }
            }
            .frame(height: 5)
        }
    }
}

// MARK: - Savings Goal

struct SavingsGoalWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SavingsGoalWidget", provider: Provider()) { entry in
            SavingsGoalView(snapshot: entry.snapshot)
                .widgetURL(URL(string: "ledger://budget"))
                .modifier(WidgetBG())
        }
        .configurationDisplayName("Savings Goal")
        .description("Progress toward this month's savings goal.")
        #if os(iOS)
        .supportedFamilies([.systemSmall, .accessoryCircular])
        #else
        .supportedFamilies([.systemSmall])
        #endif
    }
}

struct SavingsGoalView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: BudgetSnapshot
    private var progress: Double { snapshot.savingsProgress }
    private var pct: Int { Int((progress * 100).rounded()) }

    var body: some View {
        switch family {
        #if os(iOS)
        case .accessoryCircular:
            Gauge(value: min(progress, 1.0)) {
                Text("Save")
            } currentValueLabel: {
                Text("\(pct)%")
            }
            .gaugeStyle(.accessoryCircular)
            .tint(WDS.savings)
            .widgetAccentable()
        #endif
        default:
            VStack(spacing: 5) {
                Text("SAVINGS GOAL")
                    .font(.caption2.weight(.semibold)).foregroundStyle(WDS.textMuted)
                ZStack {
                    Circle().stroke(WDS.savings.opacity(0.22), lineWidth: 9)
                    Circle().trim(from: 0, to: min(progress, 1.0))
                        .stroke(WDS.savings, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(pct)%")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(WDS.text)
                        Text("of goal").font(.caption2).foregroundStyle(WDS.textMuted)
                    }
                }
                Text("\(widgetMoney(snapshot.savingsSpent)) / \(widgetMoney(snapshot.savingsBudget))")
                    .font(.caption2).foregroundStyle(WDS.textMuted)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
    }
}
