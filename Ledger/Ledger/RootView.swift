//
//  RootView.swift
//  Ledger
//

import SwiftUI
import SwiftData

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Budget", systemImage: "chart.pie") {
                BudgetView()
            }
            Tab("Insights", systemImage: "chart.bar.xaxis") {
                InsightsView()
            }
            Tab("History", systemImage: "clock.arrow.circlepath") {
                HistoryView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .background(DS.background)
        .modifier(TabChrome())
    }
}

/// iOS 26 tab-bar niceties: the bar minimizes as you scroll, and a Liquid
/// Glass accessory above it shows how much is left to spend in the viewed
/// month. No-ops on earlier systems and other platforms.
private struct TabChrome: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            content
                .tabBarMinimizeBehavior(.onScrollDown)
                .tabViewBottomAccessory { SafeToSpendBar() }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

/// "June · $1,283 left" — income minus everything spent in the viewed month.
/// The system wraps this in Liquid Glass automatically as a tab accessory.
struct SafeToSpendBar: View {
    @AppStorage("viewedMonthKey") private var viewedKey: String = MonthKey.current
    @Query(sort: \MonthRecord.key) private var months: [MonthRecord]

    private var month: MonthRecord? {
        months.first { $0.key == viewedKey }
    }

    var body: some View {
        if let month {
            let left = month.income - month.totalSpent
            HStack(spacing: Spacing.sm) {
                Circle()
                    .fill(left >= 0 ? DS.savings : DS.needs)
                    .frame(width: 8, height: 8)
                Text(MonthKey.shortMonthName(month.key))
                    .font(Typography.mono(.footnote, weight: .medium))
                    .foregroundStyle(DS.textMuted)
                Text(left >= 0 ? Money.string(left) + " left to spend"
                               : Money.string(-left) + " over income")
                    .font(Typography.mono(.footnote, weight: .semibold))
                    .foregroundStyle(left >= 0 ? DS.text : DS.needs)
            }
            .padding(.horizontal, Spacing.lg)
        } else {
            Text("Ledger")
                .font(Typography.serif(.footnote, weight: .semibold))
                .foregroundStyle(DS.textMuted)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [MonthRecord.self, Transaction.self, AppSettings.self, RecurringRule.self],
                        inMemory: true)
}
