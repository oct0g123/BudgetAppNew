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
    @Query(sort: \MonthRecord.key, order: .reverse) private var months: [MonthRecord]

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                if months.isEmpty {
                    Text("No months yet.")
                        .font(.system(.body))
                        .foregroundStyle(Palette.textMuted)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            overallCard
                            ForEach(months) { month in
                                MonthSummaryCard(month: month)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("History")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
        .tint(Palette.gold)
    }

    private var totalIncome: Double { months.reduce(0) { $0 + $1.income } }
    private var totalSaved: Double { months.reduce(0) { $0 + $1.spent(for: .savings) } }
    private var avgSavingsRate: Double {
        totalIncome > 0 ? totalSaved / totalIncome : 0
    }

    private var overallCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
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
                .font(.mono(18, weight: .medium))
                .foregroundStyle(Palette.text)
            Text(label)
                .font(.mono(10))
                .foregroundStyle(Palette.textMuted)
        }
    }
}

struct MonthSummaryCard: View {
    let month: MonthRecord

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(MonthKey.displayName(month.key))
                        .font(.serif(18))
                        .foregroundStyle(Palette.text)
                    if month.isClosed {
                        Text("CLOSED")
                            .font(.mono(9, weight: .medium))
                            .tracking(1.5)
                            .foregroundStyle(Palette.goldDim)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .overlay(Capsule().stroke(Palette.goldDim, lineWidth: 1))
                    }
                    Spacer()
                    Text(Money.percent(month.savingsRate) + " saved")
                        .font(.mono(12))
                        .foregroundStyle(Palette.savings)
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
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.mono(10))
                .foregroundStyle(Palette.textMuted)
            Text(value)
                .font(.mono(14))
                .foregroundStyle(Palette.text)
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
                        .fill(Palette.color(for: category))
                        .frame(width: max(0, geo.size.width * fraction - 2))
                }
            }
        }
        .frame(height: 6)
        .clipShape(Capsule())
        .opacity(month.totalSpent > 0 ? 0.9 : 0.25)
    }
}
