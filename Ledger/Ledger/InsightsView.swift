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
                            if IntelligenceService.isAvailable, let month = currentMonth {
                                AIInsightCard(month: month,
                                              summary: insightSummary(month),
                                              signature: insightSignature(month))
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
        .task { IntelligenceService.prewarm() }
    }

    // MARK: AI insight inputs

    /// A neutral, percentage-based summary fed to the model — no raw dollar
    /// amounts or income, both for privacy and to avoid the model's
    /// "sensitive financial content" guardrail refusing benign budget data.
    private func insightSummary(_ month: MonthRecord) -> String {
        var lines = ["Budget report for \(MonthKey.displayName(month.key))."]
        for category in BudgetCategory.allCases {
            let budget = month.budget(for: category)
            let used = budget > 0 ? Int((month.spent(for: category) / budget) * 100) : 0
            let state = month.spent(for: category) > budget ? "over its limit" : "within its limit"
            lines.append("\(category.title): used \(used)% of its allocation, \(state).")
        }
        lines.append("Overall savings rate: \(Int(month.savingsRate * 100))%.")
        if let prev = previousMonth(before: month), prev.totalSpent > 0 {
            let delta = (month.totalSpent - prev.totalSpent) / prev.totalSpent
            let direction = delta >= 0 ? "higher" : "lower"
            lines.append("Total spending is \(Int(abs(delta) * 100))% \(direction) than last month.")
        }
        return lines.joined(separator: "\n")
    }

    /// Changes whenever the month's numbers change, so a cached insight is reused
    /// until it's actually stale.
    private func insightSignature(_ month: MonthRecord) -> String {
        "\(Int(month.income))-\(Int(month.totalSpent))-\(month.txns.count)"
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

// MARK: - AI insight card

/// On-demand, on-device narrative for a month. Swift computes the numbers
/// (`summary`); the model only writes the prose. Cached per month by signature.
struct AIInsightCard: View {
    let month: MonthRecord
    let summary: String
    let signature: String

    @State private var insight: MonthInsight?
    @State private var isGenerating = false

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    SectionLabel("AI Insight")
                    Spacer()
                    if insight != nil {
                        Button(action: generate) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(DS.gold)
                        .disabled(isGenerating)
                    }
                }

                if isGenerating {
                    HStack(spacing: Spacing.sm) {
                        ProgressView()
                        Text("Reading your month…")
                            .font(Typography.mono(.footnote))
                            .foregroundStyle(DS.textMuted)
                    }
                } else if let insight {
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
                    Text("Processed on your device")
                        .font(Typography.mono(.caption2))
                        .foregroundStyle(DS.textMuted)
                } else {
                    Text("Get a quick, private read on this month's spending.")
                        .font(.subheadline)
                        .foregroundStyle(DS.textMuted)
                    Button(action: generate) {
                        Label("Generate insight", systemImage: "sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.gold)
                }
            }
        }
        .task(id: signature) { loadCached() }
    }

    private func loadCached() {
        if let cached = InsightStore.load(for: month.key), cached.signature == signature {
            insight = cached.insight
        } else {
            insight = nil
        }
    }

    private func generate() {
        isGenerating = true
        Task {
            let result: MonthInsight
            do {
                result = try await IntelligenceService.generateInsight(summary: summary)
            } catch {
                // Model refused/failed — fall back to a deterministic, on-device
                // insight computed in Swift so the card always shows something useful.
                result = fallbackInsight()
            }
            await MainActor.run {
                isGenerating = false
                insight = result
                InsightStore.save(result, signature: signature, for: month.key)
            }
        }
    }

    /// Rule-based insight from the month's own figures — the safety net when the
    /// on-device model isn't usable (e.g. a guardrail refusal).
    private func fallbackInsight() -> MonthInsight {
        var observations: [String] = []
        for category in BudgetCategory.allCases {
            let budget = month.budget(for: category)
            let spent = month.spent(for: category)
            let pct = budget > 0 ? Int((spent / budget) * 100) : 0
            if category == .savings {
                observations.append("Savings reached \(pct)% of your goal\(spent >= budget ? " — nicely done." : ".")")
            } else if spent > budget {
                observations.append("\(category.title) went over budget (\(pct)% used).")
            } else {
                observations.append("\(category.title) stayed within budget (\(pct)% used).")
            }
        }
        let rate = Int(month.savingsRate * 100)
        let overNeeds = month.spent(for: .needs) > month.budget(for: .needs)
        let overWants = month.spent(for: .wants) > month.budget(for: .wants)
        let headline: String
        if month.savingsRate >= 0.2 { headline = "Strong savings this month" }
        else if overNeeds || overWants { headline = "Spending ran over budget" }
        else { headline = "\(MonthKey.shortMonthName(month.key)) is on track" }
        let suggestion: String
        if overWants { suggestion = "Next month, trimming Wants would help you rebalance." }
        else if overNeeds { suggestion = "Needs ran high — see if any essentials can come down next month." }
        else if month.savingsRate < 0.2 { suggestion = "Consider directing a little more toward Savings next month." }
        else { suggestion = "Keep the momentum going next month." }
        return MonthInsight(headline: headline,
                            observations: observations,
                            suggestion: suggestion + " Savings rate \(rate)%.")
    }
}
