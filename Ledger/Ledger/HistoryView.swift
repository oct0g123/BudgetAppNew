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

    /// One canonical record per key, newest first — a duplicate month waiting
    /// out its delete-grace period must not appear as an extra card or skew
    /// the overall totals.
    private var months: [MonthRecord] {
        Array(LedgerService.canonicalMonths(allMonths).reversed())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.background.ignoresSafeArea()
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
                                Button {
                                    viewedKey = month.key
                                    navigator.selectedTab = .budget
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
