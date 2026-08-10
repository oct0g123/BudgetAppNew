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
    /// Set by the Quick Add intent / Action Button so the Budget screen pops the
    /// add sheet once it's on screen.
    @Published var requestAddTransaction = false
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var navigator = AppNavigator()
    @StateObject private var themeManager = ThemeManager.shared
    @Query private var months: [MonthRecord]
    @AppStorage("viewedMonthKey") private var viewedKey: String = MonthKey.current
    @AppStorage("hasCompletedOnboarding") private var hasOnboarded = false

    private var onboardingBinding: Binding<Bool> {
        Binding(get: { !hasOnboarded && months.isEmpty }, set: { _ in })
    }

    /// Hand-off from the Quick Add intent / Action Button: jump to the current
    /// month's Budget tab and ask it to open the add sheet.
    private func consumeQuickAdd() {
        guard QuickAdd.consume() else { return }
        viewedKey = MonthKey.current
        navigator.selectedTab = .budget
        navigator.requestAddTransaction = true
    }

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
            // macOS opens Settings with ⌘, in its own window (the `Settings`
            // scene in LedgerApp), so it isn't duplicated in the sidebar there.
            #if !os(macOS)
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
            #endif
        }
        .tabViewStyle(.sidebarAdaptable)
        #if os(macOS)
        .frame(minWidth: 720, minHeight: 520)
        #endif
        // visionOS: no opaque fill so the system glass window shows through.
        .background {
            #if !os(visionOS)
            DS.background
            #endif
        }
        .modifier(TabChrome())
        // Re-style the whole tab tree when the theme changes. `navigator` is a
        // RootView @StateObject (outside this id'd subtree), so the selected tab
        // is preserved across the rebuild.
        .id(themeManager.theme)
        .environmentObject(navigator)
        // Lets the Mac menu bar drive THIS window, with no shared global state
        // — see the note above LedgerCommands for why a singleton would have
        // broken multi-window iPad and Vision Pro.
        #if os(macOS)
        // Explicit closure types (not trailing-closure shorthand) so the
        // generic `focusedSceneValue(_:_:)` can't pick the wrong overload.
        .focusedSceneValue(\.newTransaction, { () -> Void in
            navigator.selectedTab = .budget
            navigator.requestAddTransaction = true
        })
        .focusedSceneValue(\.selectTab, { (tab: AppTab) -> Void in
            navigator.selectedTab = tab
        })
        #endif
        // Consolidate any duplicate months/settings that arrive via iCloud sync.
        // Runs on launch and whenever the app re-activates (e.g. after a fresh
        // import has brought duplicates down from another device).
        .task {
            if !months.isEmpty { hasOnboarded = true }   // existing users skip onboarding
            LedgerService.mergeDuplicates(in: context)
            BudgetSnapshotStore.update(from: months)
            consumeQuickAdd()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                LedgerService.mergeDuplicates(in: context)
                consumeQuickAdd()
            }
            // Refresh the widget snapshot on every scene transition (covers
            // leaving the app to view a widget after an edit).
            BudgetSnapshotStore.update(from: months)
        }
        // Re-run when months arrive/change — catches duplicates that import
        // from iCloud a few seconds *after* a cold launch, and keeps the widget
        // snapshot current. Debounced: CloudKit delivers imports in bursts of
        // batches, each changing the count — the sleep coalesces a burst into
        // ONE merge pass after it settles (task(id:) cancels the pending pass
        // whenever the count changes again). This also avoids merging in the
        // middle of an import, which is exactly where duplicate-resolution
        // races live.
        .task(id: months.count) {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            LedgerService.mergeDuplicates(in: context)
            BudgetSnapshotStore.update(from: months)
        }
        // Deep link from a widget tap → jump to the current month's Budget tab.
        .onOpenURL { url in
            guard url.scheme == "ledger" else { return }
            viewedKey = MonthKey.current
            navigator.selectedTab = .budget
        }
        // First-run onboarding (fresh installs only).
        #if os(macOS)
        .sheet(isPresented: onboardingBinding) { OnboardingView() }
        #else
        .fullScreenCover(isPresented: onboardingBinding) { OnboardingView() }
        #endif
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

/// "This week · $288.67 left for Wants" — the discretionary allowance for the
/// current week, which drains as you spend and resets at the start of each
/// week. The system wraps this in Liquid Glass automatically as a tab accessory.
///
/// Wants, deliberately, not Needs + Wants: this is the number you act on before
/// spending ("can I go out tonight"). Needs is mostly fixed costs that are
/// already committed, so folding it in makes the figure look healthy in a week
/// where rent simply hasn't cleared yet.
///
/// Falls back to the month's safe-to-spend while browsing a past or closed
/// month, where a "this week" figure would be meaningless.
struct SafeToSpendBar: View {
    @AppStorage("viewedMonthKey") private var viewedKey: String = MonthKey.current
    @Query(sort: \MonthRecord.key) private var months: [MonthRecord]

    private var month: MonthRecord? {
        LedgerService.canonical(months, key: viewedKey)
    }

    var body: some View {
        if let month {
            if let week = month.weekSpending(for: .wants) {
                bar(leading: "This week",
                    value: week.left,
                    positive: " left for Wants",
                    negative: " over on Wants")
            } else {
                bar(leading: MonthKey.shortMonthName(month.key),
                    value: month.safeToSpend,
                    positive: " left to spend",
                    negative: " over budget")
            }
        } else {
            Text("Ledger")
                .font(Typography.serif(.footnote, weight: .semibold))
                .foregroundStyle(DS.textMuted)
        }
    }

    private func bar(leading: String, value: Double,
                     positive: String, negative: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(value >= 0 ? DS.savings : DS.needs)
                .frame(width: 8, height: 8)
            Text(leading)
                .font(Typography.mono(.footnote, weight: .medium))
                .foregroundStyle(DS.textMuted)
            Text(value >= 0 ? Money.string(value) + positive
                            : Money.string(-value) + negative)
                .font(Typography.mono(.footnote, weight: .semibold))
                .foregroundStyle(value >= 0 ? DS.text : DS.needs)
        }
        .padding(.horizontal, Spacing.lg)
        // Single VoiceOver element: "This week, $288.67 left for Wants".
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    RootView()
        .modelContainer(for: [MonthRecord.self, Transaction.self, AppSettings.self, RecurringRule.self],
                        inMemory: true)
}

// MARK: - First-run onboarding

/// Shown once on a fresh install: set monthly income + the 50/30/20 split before
/// landing in the app. Writes the settings + the current month, then flips the
/// `hasCompletedOnboarding` flag (which dismisses this).
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("hasCompletedOnboarding") private var hasOnboarded = false
    @AppStorage("viewedMonthKey") private var viewedKey: String = MonthKey.current

    @State private var incomeAmount: Double = 0
    @State private var needsPct = 50
    @State private var savingsPct = 20
    @State private var wantsPct = 30

    private var split: BudgetSplit {
        BudgetSplit(needs: Double(needsPct), savings: Double(savingsPct), wants: Double(wantsPct))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Welcome to Ledger")
                        .font(Typography.serif(.largeTitle, weight: .bold))
                        .foregroundStyle(DS.text)
                    Text("A simple 50/30/20 budget — your income splits into Needs, Savings, and Wants.")
                        .font(.subheadline)
                        .foregroundStyle(DS.textMuted)
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SectionLabel("Monthly Income")
                    MoneyField(placeholder: "0", amount: $incomeAmount)
                        .font(Typography.mono(.title, weight: .medium))
                        .foregroundStyle(DS.text)
                        .padding(Spacing.md)
                        .background(DS.surfaceStyle, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SectionLabel("Allocation")
                    Text("Needs / Savings / Wants")
                        .font(Typography.mono(.caption))
                        .foregroundStyle(DS.textMuted)
                    HStack(spacing: Spacing.sm) {
                        presetButton("50 / 20 / 30", subtitle: "Balanced · 20% saved", n: 50, s: 20, w: 30)
                        presetButton("50 / 30 / 20", subtitle: "Aggressive · 30% saved", n: 50, s: 30, w: 20)
                    }
                    Text("Needs \(needsPct)% · Savings \(savingsPct)% · Wants \(wantsPct)%")
                        .font(Typography.mono(.footnote))
                        .foregroundStyle(DS.textMuted)
                }

                Button { finish() } label: {
                    Text("Get Started").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.gold)
                .controlSize(.large)

                Text("You can change all of this anytime in Settings.")
                    .font(.caption)
                    .foregroundStyle(DS.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(Spacing.xl)
        }
        .screenBackground()
        .tint(DS.gold)
        // Onboarding has no Cancel and no tap-away target, so scrolling is the
        // only way to drop the decimal pad — which has no Return key.
        #if !os(visionOS)
        .scrollDismissesKeyboard(.immediately)
        #endif
        .interactiveDismissDisabled(true)
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 520)
        #endif
    }

    private func presetButton(_ title: String, subtitle: String, n: Int, s: Int, w: Int) -> some View {
        let selected = needsPct == n && savingsPct == s && wantsPct == w
        return Button {
            needsPct = n; savingsPct = s; wantsPct = w
        } label: {
            VStack(spacing: 2) {
                Text(title).font(Typography.mono(.subheadline, weight: .medium))
                Text(subtitle).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xs)
        }
        .buttonStyle(.bordered)
        .tint(selected ? DS.gold : DS.textMuted)
    }

    private func finish() {
        let income = incomeAmount
        let settings = LedgerService.settings(in: context)
        settings.defaultIncome = income
        settings.defaultSplit = split
        let month = LedgerService.ensureMonth(forKey: MonthKey.current, in: context)
        month.income = income
        month.needsPct = split.needs
        month.savingsPct = split.savings
        month.wantsPct = split.wants
        try? context.save()
        viewedKey = MonthKey.current
        hasOnboarded = true
    }
}

#Preview("Onboarding") {
    OnboardingView()
        .modelContainer(for: [MonthRecord.self, Transaction.self, AppSettings.self, RecurringRule.self],
                        inMemory: true)
}
