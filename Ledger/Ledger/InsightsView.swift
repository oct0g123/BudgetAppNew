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
