//
//  InsightsView.swift
//  Ledger
//
//  Dashboards & reporting, built on Swift Charts. A first cut: savings-rate
//  trajectory, spend-by-category over time, and budget-vs-actual for the
//  current month.
//

import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
    @AppStorage("viewedMonthKey") private var viewedKey: String = MonthKey.current
    @Query(sort: \MonthRecord.key) private var months: [MonthRecord]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Drives the one-shot "bars fill up" entrance: charts render at zero
    /// until the tab first appears, then animate to their real values.
    @State private var chartsAppeared = false

    /// Most recent 12 months that have any income or spend.
    private var recentMonths: [MonthRecord] {
        months
            .filter { $0.income > 0 || $0.totalSpent > 0 }
            .suffix(12)
            .map { $0 }
    }

    private var currentMonth: MonthRecord? {
        months.first { $0.key == viewedKey } ?? months.last
    }

    var body: some View {
        // Evaluated once per render — recentMonths scans every month's
        // transactions, so repeated property access here was O(months × txns)
        // several times over per body pass.
        let recent = recentMonths
        NavigationStack {
            ZStack {
                DS.background.ignoresSafeArea()
                if recent.isEmpty {
                    ContentUnavailableView("No insights yet",
                                           systemImage: "chart.bar.xaxis",
                                           description: Text("Add income and transactions to see charts."))
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Spacing.xl) {
                            if let month = currentMonth {
                                MonthSummaryInsightCard(month: month,
                                                        previousMonth: previousMonth(before: month))
                            }
                            savingsRateChart(recent)
                            categorySpendChart(recent)
                            if let month = currentMonth {
                                budgetVsActualChart(month)
                            }
                        }
                        .padding(Spacing.xl)
                        .readableContentWidth()
                    }
                }
            }
            .navigationTitle("Insights")
            #if !os(macOS)
            .toolbarTitleDisplayMode(.large)
            #endif
        }
        .tint(DS.gold)
        .onAppear {
            guard !chartsAppeared else { return }
            if reduceMotion {
                chartsAppeared = true      // no animation, straight to final values
            } else {
                withAnimation(.easeOut(duration: 0.8)) { chartsAppeared = true }
            }
        }
    }

    private func previousMonth(before month: MonthRecord) -> MonthRecord? {
        months.filter { $0.key < month.key }.max { $0.key < $1.key }
    }

    // MARK: Savings rate over time

    private func avgSavingsRate(_ recent: [MonthRecord]) -> Double {
        guard !recent.isEmpty else { return 0 }
        return recent.reduce(0) { $0 + $1.savingsRate } / Double(recent.count)
    }

    private func savingsRateChart(_ recent: [MonthRecord]) -> some View {
        let avg = avgSavingsRate(recent)
        return Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel("Savings Rate")
                Chart {
                    ForEach(recent) { month in
                        BarMark(
                            x: .value("Month", MonthKey.shortMonthName(month.key)),
                            y: .value("Rate", chartsAppeared ? month.savingsRate : 0)
                        )
                        .foregroundStyle(DS.savings)
                        .cornerRadius(4)
                    }
                    if recent.count > 1 {
                        RuleMark(y: .value("Average", avg))
                            .foregroundStyle(DS.gold.opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("avg " + Money.percent(avg))
                                    .font(Typography.mono(.caption2))
                                    .foregroundStyle(DS.gold)
                            }
                    }
                }
                .chartXAxis { monoAxisLabels() }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(DS.hairline)
                        AxisValueLabel(format: FloatingPointFormatStyle<Double>.Percent())
                            .font(Typography.mono(.caption2))
                            .foregroundStyle(DS.textMuted)
                    }
                }
                .frame(height: 180)
            }
        }
    }

    /// Shared mono styling for category-axis labels.
    private func monoAxisLabels() -> some AxisContent {
        AxisMarks { _ in
            AxisValueLabel()
                .font(Typography.mono(.caption2))
                .foregroundStyle(DS.textMuted)
        }
    }

    // MARK: Spend by category, stacked

    private func categorySpendChart(_ recent: [MonthRecord]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel("Spending by Category")
                Chart {
                    ForEach(recent) { month in
                        ForEach(BudgetCategory.allCases) { category in
                            BarMark(
                                x: .value("Month", MonthKey.shortMonthName(month.key)),
                                y: .value("Spent", chartsAppeared ? month.spent(for: category) : 0)
                            )
                            .foregroundStyle(by: .value("Category", category.title))
                        }
                    }
                }
                .chartForegroundStyleScale([
                    BudgetCategory.needs.title: DS.needs,
                    BudgetCategory.savings.title: DS.savings,
                    BudgetCategory.wants.title: DS.wants
                ])
                .chartXAxis { monoAxisLabels() }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(DS.hairline)
                        AxisValueLabel()
                            .font(Typography.mono(.caption2))
                            .foregroundStyle(DS.textMuted)
                    }
                }
                .frame(height: 200)
                .chartLegend(position: .bottom)
            }
        }
    }

    // MARK: Budget vs actual (current month)

    private func budgetVsActualChart(_ month: MonthRecord) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SectionLabel("Budget vs Actual — \(MonthKey.displayName(month.key))")
                ForEach(BudgetCategory.allCases) { category in
                    // Feeding zero until appearance rides the bar's own spring
                    // animation, so these fill in with the charts above.
                    BudgetProgressBar(category: category,
                                      spent: chartsAppeared ? month.spent(for: category) : 0,
                                      budget: month.budget(for: category))
                }
            }
        }
    }
}

// MARK: - Budget vs actual bar (matches the Budget page, thicker)

/// One category's spend against its budget as a thick progress bar: spent fills
/// the budget track, category-colored, red when over. Mirrors the Budget page's
/// BucketRow so the two screens read the same — just chunkier for the Insights
/// real estate.
struct BudgetProgressBar: View {
    let category: BudgetCategory
    let spent: Double
    let budget: Double

    private var rawFraction: Double { budget > 0 ? spent / budget : 0 }
    private var fraction: Double { min(rawFraction, 1) }
    private var isSavings: Bool { category == .savings }
    private var spentOver: Bool { spent > budget }
    private var alarmOver: Bool { spentOver && !isSavings }

    private var statusText: String {
        if spentOver && isSavings { return Money.string(spent - budget) + " past goal" }
        if spentOver { return "Over by " + Money.string(spent - budget) }
        return Money.string(budget - spent) + " remaining"
    }
    private var statusColor: Color {
        if spentOver && isSavings { return DS.savings }
        if spentOver { return DS.over }
        return DS.textMuted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Circle().fill(DS.category(category)).frame(width: 9, height: 9)
                Text(category.title)
                    .font(Typography.serif(.headline))
                    .foregroundStyle(DS.text)
                Spacer()
                Text(Money.string(spent) + " / " + Money.string(budget))
                    .font(Typography.mono(.footnote))
                    .foregroundStyle(DS.textMuted)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(DS.surfaceHigh)
                    Capsule().fill(alarmOver ? DS.over : DS.category(category))
                        .frame(width: max(0, geo.size.width * fraction))
                }
            }
            .frame(height: 18)
            .animation(.spring(duration: 0.5), value: fraction)
            HStack {
                Text(statusText)
                    .font(Typography.mono(.caption))
                    .foregroundStyle(statusColor)
                Spacer()
                Text(Money.percent(rawFraction) + " used")
                    .font(Typography.mono(.caption))
                    .foregroundStyle(alarmOver ? DS.over : DS.textMuted)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Monthly summary card

/// A concise, always-correct monthly summary. Computed entirely in Swift so the
/// figures are consistent and right every time (the on-device model was too
/// unreliable with numbers/labels to trust for this). Updates live with the data.
struct MonthSummaryInsightCard: View {
    let month: MonthRecord
    var previousMonth: MonthRecord?

    /// Not enough logged yet to say anything meaningful.
    private var hasEnoughData: Bool { month.txns.count >= 3 }

    var body: some View {
        // Built once per render — reading it via a computed property ran the
        // full aggregation separately for headline, observations & suggestion.
        let insight = buildInsight()
        Card {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionLabel("Monthly Summary")
                if hasEnoughData {
                    Text(insight.headline)
                        .font(Typography.serif(.title3))
                        .foregroundStyle(DS.text)
                    ForEach(insight.observations, id: \.self) { obs in
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            Circle().fill(DS.gold).frame(width: 5, height: 5).padding(.top, 7)
                            Text(obs).foregroundStyle(DS.text)
                        }
                    }
                    if !insight.suggestion.isEmpty {
                        Text(insight.suggestion)
                            .font(.subheadline)
                            .foregroundStyle(DS.text)
                            .padding(Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DS.surfaceHigh,
                                        in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                    }
                } else {
                    Text("Log a few transactions and your \(MonthKey.shortMonthName(month.key)) insights will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(DS.textMuted)
                }
            }
        }
    }

    private func buildInsight() -> MonthInsight {
        // Present tense ("so far") for the current, open month; past tense
        // (recap) once it's closed or it's a past month.
        let inProgress = !month.isClosed && month.key >= MonthKey.current
        let monthName = MonthKey.shortMonthName(month.key)

        var observations: [String] = []
        for category in BudgetCategory.allCases {
            let budget = month.budget(for: category)
            let spent = month.spent(for: category)
            let pct = budget > 0 ? Int(((spent / budget) * 100).rounded()) : 0
            let over = spent > budget
            switch category {
            case .savings:
                if inProgress {
                    observations.append(over
                        ? "Savings is already past your goal (\(pct)%) — great."
                        : "Savings is at \(pct)% of your goal so far.")
                } else {
                    observations.append(over
                        ? "Savings reached \(pct)% of your goal — nicely done."
                        : "Savings reached \(pct)% of your goal.")
                }
            default:
                if inProgress {
                    observations.append(over
                        ? "\(category.title) is already over budget (\(pct)% used)."
                        : "\(category.title) is at \(pct)% of budget so far.")
                } else {
                    observations.append(over
                        ? "\(category.title) went over budget (\(pct)% used)."
                        : "\(category.title) stayed within budget (\(pct)% used).")
                }
            }
        }
        // Month-over-month only compares fairly once the month is complete.
        if !inProgress, let prev = previousMonth, prev.totalSpent > 0 {
            let delta = (month.totalSpent - prev.totalSpent) / prev.totalSpent
            let pct = Int((abs(delta) * 100).rounded())
            if pct >= 1 {
                observations.append("Total spending was \(pct)% \(delta >= 0 ? "higher" : "lower") than last month.")
            }
        }

        let rate = Int((month.savingsRate * 100).rounded())
        let overNeeds = month.spent(for: .needs) > month.budget(for: .needs)
        let overWants = month.spent(for: .wants) > month.budget(for: .wants)

        let headline: String
        if inProgress {
            if overNeeds || overWants { headline = "Watch your spending in \(monthName)" }
            else if month.savingsRate >= 0.2 { headline = "Saving strong so far" }
            else { headline = "\(monthName) so far" }
        } else {
            if month.savingsRate >= 0.2 { headline = "Strong savings in \(monthName)" }
            else if overNeeds && overWants { headline = "Over budget in Needs and Wants" }
            else if overNeeds || overWants { headline = "Spending ran over budget" }
            else { headline = "\(monthName) is on track" }
        }

        let suggestion: String
        if inProgress {
            let leftText = month.safeToSpend >= 0 ? " You have \(Money.string(month.safeToSpend)) left to spend." : ""
            if overWants { suggestion = "Ease up on Wants for the rest of the month." + leftText }
            else if overNeeds { suggestion = "Needs is running high — keep an eye on essentials." + leftText }
            else if month.savingsRate < 0.2 { suggestion = "Consider moving a bit more toward Savings before month-end." + leftText }
            else { suggestion = "You're on track — keep it up." + leftText }
        } else {
            var recap: String
            if overNeeds && overWants { recap = "Trimming both Needs and Wants would help next month." }
            else if overWants { recap = "Next month, trimming Wants would help you rebalance." }
            else if overNeeds { recap = "Needs ran high — see if any essentials can come down next month." }
            else if month.savingsRate < 0.2 { recap = "Consider directing a little more toward Savings next month." }
            else { recap = "Nice balance — keep the momentum going next month." }
            recap += " Savings rate \(rate)%."
            suggestion = recap
        }

        return MonthInsight(headline: headline, observations: observations, suggestion: suggestion)
    }
}
