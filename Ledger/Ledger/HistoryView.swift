//
//  HistoryView.swift
//  Ledger
//
//  Summary of every month: income, total spent, and savings rate. A first step
//  toward the dashboards/reporting planned for later.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \MonthRecord.key, order: .reverse) private var allMonths: [MonthRecord]
    @EnvironmentObject private var navigator: AppNavigator
    @AppStorage("viewedMonthKey") private var viewedKey: String = MonthKey.current
    @State private var recapMonth: MonthRecord?

    /// One canonical record per key, newest first — a duplicate month waiting
    /// out its delete-grace period must not appear as an extra card or skew
    /// the overall totals.
    private var months: [MonthRecord] {
        Array(LedgerService.canonicalMonths(allMonths).reversed())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                #if !os(visionOS)
                DS.background.ignoresSafeArea()   // glass shows through on visionOS
                #endif
                if months.isEmpty {
                    ContentUnavailableView("No months yet",
                                           systemImage: "clock.arrow.circlepath",
                                           description: Text("Closed and active months will appear here."))
                } else {
                    ScrollView {
                        // Lazy so only visible month cards are built — each card
                        // scans its month's transactions several times to render.
                        LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                            overallCard
                            ForEach(months) { month in
                                // Tap opens the month's RECAP (its natural
                                // detail view); jumping to the Budget tab
                                // lives inside the recap as a button, so you
                                // never lose your place in History.
                                Button {
                                    recapMonth = month
                                } label: {
                                    MonthSummaryCard(month: month)
                                }
                                .buttonStyle(.plain)
                                .hoverHighlight()
                            }
                        }
                        .padding(Spacing.xl)
                        .readableContentWidth()
                    }
                }
            }
            .navigationTitle("History")
            #if !os(macOS)
            .toolbarTitleDisplayMode(.large)
            #endif
            .sheet(item: $recapMonth) { month in
                // `months` is newest-first, so the immediately-previous month
                // is the FIRST entry with a smaller key.
                RecapView(month: month,
                          previousMonth: months.first(where: { $0.key < month.key }),
                          onOpenBudget: {
                              viewedKey = month.key
                              navigator.selectedTab = .budget
                          })
            }
        }
        .tint(DS.gold)
    }

    private var totalIncome: Double { months.reduce(0) { $0 + $1.income } }
    private var totalSaved: Double { months.reduce(0) { $0 + $1.spent(for: .savings) } }
    private var avgSavingsRate: Double {
        totalIncome > 0 ? totalSaved / totalIncome : 0
    }

    private var overallCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionLabel("All Time")
                HStack {
                    stat("Months", "\(months.count)")
                    Spacer()
                    stat("Saved", Money.string(totalSaved))
                    Spacer()
                    stat("Avg Savings", Money.percent(avgSavingsRate))
                }
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(Typography.mono(.title3, weight: .medium))
                .foregroundStyle(DS.text)
            Text(label)
                .font(Typography.mono(.caption2))
                .foregroundStyle(DS.textMuted)
        }
    }
}

struct MonthSummaryCard: View {
    let month: MonthRecord

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text(MonthKey.displayName(month.key))
                        .font(Typography.serif(.title3))
                        .foregroundStyle(DS.text)
                    if month.isClosed {
                        Text("CLOSED")
                            .font(Typography.mono(.caption2, weight: .medium))
                            .tracking(1.5)
                            .foregroundStyle(DS.goldDim)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .overlay(Capsule().stroke(DS.goldDim, lineWidth: 1))
                    }
                    Spacer()
                    Text(Money.percent(month.savingsRate) + " saved")
                        .font(Typography.mono(.footnote))
                        .foregroundStyle(DS.savings)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(DS.textMuted)
                }

                ProportionBar(month: month)

                HStack {
                    detail("Income", Money.string(month.income))
                    Spacer()
                    detail("Spent", Money.string(month.totalSpent))
                    Spacer()
                    detail("Split", "\(Int(month.needsPct))/\(Int(month.savingsPct))/\(Int(month.wantsPct))")
                }
            }
        }
        // One VoiceOver element per month card ("July 2026, 10% saved,
        // Income $10,000, Spent $5,250, Split 50/30/20") — the proportion
        // bar is decorative and folds away.
        .accessibilityElement(children: .combine)
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(Typography.mono(.caption2))
                .foregroundStyle(DS.textMuted)
            Text(value)
                .font(Typography.mono(.footnote))
                .foregroundStyle(DS.text)
        }
    }
}

/// A thin stacked bar showing the relative spend across the three buckets.
struct ProportionBar: View {
    let month: MonthRecord

    var body: some View {
        let total = max(month.totalSpent, 0.0001)
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(BudgetCategory.allCases) { category in
                    let fraction = month.spent(for: category) / total
                    Rectangle()
                        .fill(DS.category(category))
                        .frame(width: max(0, geo.size.width * fraction - 2))
                }
            }
        }
        .frame(height: 6)
        .clipShape(Capsule())
        .opacity(month.totalSpent > 0 ? 0.9 : 0.25)
    }
}

// MARK: - Month recap

/// The "here's how the month went" wrap-up: shown as a sheet right after
/// closing a month (the ritual moment) and from any History card (the
/// archive). Built on the same deterministic `buildInsight` engine as the
/// Insights summary — no AI prose, figures always correct.
struct RecapView: View {
    @Environment(\.dismiss) private var dismiss

    let month: MonthRecord
    var previousMonth: MonthRecord? = nil
    /// Present when opened from History: jumps to this month on the Budget tab.
    var onOpenBudget: (() -> Void)? = nil

    var body: some View {
        let insight = LedgerService.buildInsight(for: month, previous: previousMonth)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {

                    // Headline block
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        SectionLabel(MonthKey.displayName(month.key)
                                     + (month.isClosed ? "  ·  CLOSED" : ""))
                        Text(insight.headline)
                            .font(Typography.serif(.largeTitle, weight: .semibold))
                            .foregroundStyle(DS.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // The month in three numbers
                    HStack {
                        recapStat("Income", Money.string(month.income))
                        Spacer()
                        recapStat("Spent", Money.string(month.totalSpent))
                        Spacer()
                        recapStat("Saved", Money.percent(month.savingsRate))
                    }
                    .padding(Spacing.lg)
                    .background(DS.surfaceStyle)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    .accessibilityElement(children: .combine)

                    // Bucket results (same thick bars as Insights)
                    VStack(spacing: Spacing.md) {
                        ForEach(BudgetCategory.allCases) { category in
                            BudgetProgressBar(category: category,
                                              spent: month.spent(for: category),
                                              budget: month.budget(for: category))
                        }
                    }
                    .padding(Spacing.lg)
                    .background(DS.surfaceStyle)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))

                    // Observations
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        ForEach(insight.observations, id: \.self) { obs in
                            HStack(alignment: .top, spacing: Spacing.sm) {
                                Circle().fill(DS.gold)
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 7)
                                Text(obs).foregroundStyle(DS.text)
                            }
                        }
                    }

                    if !insight.suggestion.isEmpty {
                        Text(insight.suggestion)
                            .font(.subheadline)
                            .foregroundStyle(DS.text)
                            .padding(Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DS.surfaceHighStyle,
                                        in: RoundedRectangle(cornerRadius: Radius.field,
                                                             style: .continuous))
                    }

                    if let onOpenBudget {
                        Button {
                            onOpenBudget()
                            dismiss()
                        } label: {
                            Label("Open in Budget", systemImage: "chart.pie")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(DS.gold)
                    }
                }
                .padding(Spacing.xl)
                .readableContentWidth()
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Month Recap")
            #if !os(macOS)
            .toolbarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(DS.gold)
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 560)
        #endif
        // visionOS sheets size to a compact panel by default, which cut the
        // recap off after the observations and looked complete — deceiving.
        // A taller panel fits the whole recap (or clearly shows the scroll).
        #if os(visionOS)
        .frame(minWidth: 640, minHeight: 820)
        #endif
    }

    private func recapStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(Typography.mono(.caption2, weight: .medium))
                .tracking(1.5)
                .foregroundStyle(DS.goldDim)
            Text(value)
                .font(Typography.mono(.headline, weight: .semibold))
                .foregroundStyle(DS.text)
        }
    }
}
