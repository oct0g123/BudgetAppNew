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
                Palette.background.ignoresSafeArea()
                if recentMonths.isEmpty {
                    Text("Add some data to see insights.")
                        .font(.system(.body))
                        .foregroundStyle(Palette.textMuted)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            savingsRateChart
                            categorySpendChart
                            if let month = currentMonth {
                                budgetVsActualChart(month)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Insights")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
        .tint(Palette.gold)
    }

    // MARK: Savings rate over time

    private var savingsRateChart: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel("Savings Rate")
                Chart(recentMonths) { month in
                    BarMark(
                        x: .value("Month", MonthKey.shortMonthName(month.key)),
                        y: .value("Rate", month.savingsRate)
                    )
                    .foregroundStyle(Palette.savings)
                    .cornerRadius(4)
                }
                .chartYAxis {
                    AxisMarks(format: FloatingPointFormatStyle<Double>.Percent())
                }
                .frame(height: 180)
            }
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
                    BudgetCategory.needs.title: Palette.needs,
                    BudgetCategory.savings.title: Palette.savings,
                    BudgetCategory.wants.title: Palette.wants
                ])
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
                        .foregroundStyle(Palette.surfaceHigh)
                        .cornerRadius(4)

                        BarMark(
                            x: .value("Amount", month.spent(for: category)),
                            y: .value("Bucket", category.title)
                        )
                        .foregroundStyle(Palette.color(for: category))
                        .cornerRadius(4)
                    }
                }
                .frame(height: 160)
                HStack(spacing: 16) {
                    legendDot(Palette.surfaceHigh, "Budget")
                    legendDot(Palette.gold, "Spent")
                }
            }
        }
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 12, height: 12)
            Text(label).font(.mono(11)).foregroundStyle(Palette.textMuted)
        }
    }
}
