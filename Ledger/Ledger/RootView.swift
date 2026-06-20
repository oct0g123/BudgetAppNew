//
//  RootView.swift
//  Ledger
//

import SwiftUI
import SwiftData

/// The four top-level tabs, used as `TabView` selection values so other screens
/// (e.g. History) can switch tabs programmatically.
enum AppTab: Hashable {
    case budget, insights, history, settings
}

/// Lightweight app-wide navigation state injected into the environment.
final class AppNavigator: ObservableObject {
    @Published var selectedTab: AppTab = .budget
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var navigator = AppNavigator()
    @Query private var months: [MonthRecord]
    @AppStorage("viewedMonthKey") private var viewedKey: String = MonthKey.current

    var body: some View {
        TabView(selection: $navigator.selectedTab) {
            Tab("Budget", systemImage: "chart.pie", value: AppTab.budget) {
                BudgetView()
            }
            Tab("Insights", systemImage: "chart.bar.xaxis", value: AppTab.insights) {
                InsightsView()
            }
            Tab("History", systemImage: "clock.arrow.circlepath", value: AppTab.history) {
                HistoryView()
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .background(DS.background)
        .modifier(TabChrome())
        .environmentObject(navigator)
        // Consolidate any duplicate months/settings that arrive via iCloud sync.
        // Runs on launch and whenever the app re-activates (e.g. after a fresh
        // import has brought duplicates down from another device).
        .task {
            LedgerService.mergeDuplicates(in: context)
            BudgetSnapshotStore.update(from: months)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { LedgerService.mergeDuplicates(in: context) }
            // Refresh the widget snapshot on every scene transition (covers
            // leaving the app to view a widget after an edit).
            BudgetSnapshotStore.update(from: months)
        }
        // Re-run when months arrive/change — catches duplicates that import
        // from iCloud a few seconds *after* a cold launch, and keeps the widget
        // snapshot current.
        .onChange(of: months.count) { _, _ in
            LedgerService.mergeDuplicates(in: context)
            BudgetSnapshotStore.update(from: months)
        }
        // Deep link from a widget tap → jump to the current month's Budget tab.
        .onOpenURL { url in
            guard url.scheme == "ledger" else { return }
            viewedKey = MonthKey.current
            navigator.selectedTab = .budget
        }
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
            let left = month.safeToSpend
            HStack(spacing: Spacing.sm) {
                Circle()
                    .fill(left >= 0 ? DS.savings : DS.needs)
                    .frame(width: 8, height: 8)
                Text(MonthKey.shortMonthName(month.key))
                    .font(Typography.mono(.footnote, weight: .medium))
                    .foregroundStyle(DS.textMuted)
                Text(left >= 0 ? Money.string(left) + " left to spend"
                               : Money.string(-left) + " over budget")
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
