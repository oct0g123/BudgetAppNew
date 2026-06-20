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
        NavigationStack {
            ZStack {
                DS.background.ignoresSafeArea()
                if recentMonths.isEmpty {
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
                            savingsRateChart
                            categorySpendChart
                            if let month = currentMonth {
                                budgetVsActualChart(month)
                            }
                        }
                        .padding(Spacing.xl)
                    }
                }
            }
            .navigationTitle("Insights")
            #if !os(macOS)
            .toolbarTitleDisplayMode(.large)
            #endif
        }
        .tint(DS.gold)
    }

    private func previousMonth(before month: MonthRecord) -> MonthRecord? {
        months.filter { $0.key < month.key }.max { $0.key < $1.key }
    }

    // MARK: Savings rate over time

    private var avgSavingsRate: Double {
        guard !recentMonths.isEmpty else { return 0 }
        return recentMonths.reduce(0) { $0 + $1.savingsRate } / Double(recentMonths.count)
    }

    private var savingsRateChart: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel("Savings Rate")
                Chart {
                    ForEach(recentMonths) { month in
                        BarMark(
                            x: .value("Month", MonthKey.shortMonthName(month.key)),
                            y: .value("Rate", month.savingsRate)
                        )
                        .foregroundStyle(DS.savings)
                        .cornerRadius(4)
                    }
                    if recentMonths.count > 1 {
                        RuleMark(y: .value("Average", avgSavingsRate))
                            .foregroundStyle(DS.gold.opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("avg " + Money.percent(avgSavingsRate))
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

    private var categorySpendChart: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel("Spending by Category")
                Chart {
                    ForEach(recentMonths) { month in
                        ForEach(BudgetCategory.allCases) { category in
                            BarMark(
                                x: .value("Month", MonthKey.shortMonthName(month.key)),
                                y: .value("Spent", month.spent(for: category))
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
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel("Budget vs Actual — \(MonthKey.displayName(month.key))")
                Chart {
                    ForEach(BudgetCategory.allCases) { category in
                        BarMark(
                            x: .value("Amount", month.budget(for: category)),
                            y: .value("Bucket", category.title)
                        )
                        .foregroundStyle(DS.surfaceHigh)
                        .cornerRadius(4)

                        BarMark(
                            x: .value("Amount", month.spent(for: category)),
                            y: .value("Bucket", category.title)
                        )
                        .foregroundStyle(DS.category(category))
                        .cornerRadius(4)
                    }
                }
                .chartYAxis { monoAxisLabels() }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(DS.hairline)
                        AxisValueLabel()
                            .font(Typography.mono(.caption2))
                            .foregroundStyle(DS.textMuted)
                    }
                }
                .frame(height: 160)
                HStack(spacing: Spacing.lg) {
                    legendDot(DS.surfaceHigh, "Budget")
                    legendDot(DS.gold, "Spent")
                }
            }
        }
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 12, height: 12)
            Text(label).font(Typography.mono(.caption)).foregroundStyle(DS.textMuted)
        }
    }
}

// MARK: - Monthly summary card

/// A concise, always-correct monthly summary. Computed entirely in Swift so the
/// figures are consistent and right every time (the on-device model was too
/// unreliable with numbers/labels to trust for this). Updates live with the data.
struct MonthSummaryInsightCard: View {
    let month: MonthRecord
    var previousMonth: MonthRecord?

    private var insight: MonthInsight { buildInsight() }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionLabel("Monthly Summary")
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
            if overNeeds && overWants { suggestion = "Trimming both Needs and Wants would help next month." }
            else if overWants { suggestion = "Next month, trimming Wants would help you rebalance." }
            else if overNeeds { suggestion = "Needs ran high — see if any essentials can come down next month." }
            else if month.savingsRate < 0.2 { suggestion = "Consider directing a little more toward Savings next month." }
            else { suggestion = "Nice balance — keep the momentum going next month." }
            suggestion += " Savings rate \(rate)%."
        }

        return MonthInsight(headline: headline, observations: observations, suggestion: suggestion)
    }
}
