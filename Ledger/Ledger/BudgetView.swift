//
//  BudgetView.swift
//  Ledger
//
//  The main screen: month navigation, income, the three 50/30/20 buckets with
//  live progress bars, and the transaction list with category filtering.
//

import SwiftUI
import SwiftData

struct BudgetView: View {
    @Environment(\.modelContext) private var context

    @AppStorage("viewedMonthKey") private var viewedKey: String = MonthKey.current
    @Query(sort: \MonthRecord.key) private var months: [MonthRecord]

    @State private var filter: BudgetCategory? = nil
    @State private var showingAdd = false
    @State private var editingIncome = false
    @State private var incomeDraft = ""

    private var currentMonth: MonthRecord? {
        months.first { $0.key == viewedKey }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                content
            }
            .navigationTitle("")
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
        .tint(Palette.gold)
        .onAppear {
            // Make sure the real current month exists on first launch.
            if currentMonth == nil && viewedKey == MonthKey.current {
                LedgerService.ensureMonth(forKey: viewedKey, in: context)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if let month = currentMonth {
                    monthBody(month)
                } else {
                    emptyMonthState
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Header / month navigation

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ledger")
                    .font(.serif(30, weight: .bold))
                    .foregroundStyle(Palette.text)
                Spacer()
                SavedIndicator()
            }

            HStack(spacing: 16) {
                navButton(system: "chevron.left") {
                    viewedKey = MonthKey.offset(viewedKey, by: -1)
                }
                VStack(alignment: .center, spacing: 2) {
                    Text(MonthKey.displayName(viewedKey))
                        .font(.serif(20, weight: .semibold))
                        .foregroundStyle(Palette.text)
                    if currentMonth?.isClosed == true {
                        Text("CLOSED")
                            .font(.mono(10, weight: .medium))
                            .tracking(2)
                            .foregroundStyle(Palette.goldDim)
                    }
                }
                .frame(maxWidth: .infinity)
                navButton(system: "chevron.right") {
                    viewedKey = MonthKey.offset(viewedKey, by: 1)
                }
            }
        }
    }

    private func navButton(system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.gold)
                .frame(width: 40, height: 40)
                .background(Palette.surface)
                .clipShape(Circle())
                .overlay(Circle().stroke(Palette.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Empty state

    private var emptyMonthState: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("No data for \(MonthKey.displayName(viewedKey))")
                    .font(.serif(18))
                    .foregroundStyle(Palette.text)
                Text("Start this month to begin tracking. It will use your default income and allocation from Settings.")
                    .font(.system(.subheadline))
                    .foregroundStyle(Palette.textMuted)
                Button {
                    LedgerService.ensureMonth(forKey: viewedKey, in: context)
                } label: {
                    Text("Start \(MonthKey.displayName(viewedKey))")
                        .font(.system(.body, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Palette.gold)
                        .foregroundStyle(Palette.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }

    // MARK: Month body

    @ViewBuilder
    private func monthBody(_ month: MonthRecord) -> some View {
        incomeCard(month)
        bucketsSection(month)
        transactionsSection(month)
        if !month.isClosed {
            closeMonthButton(month)
        }
    }

    private func incomeCard(_ month: MonthRecord) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Monthly Income")
                if editingIncome && !month.isClosed {
                    HStack {
                        TextField("0", text: $incomeDraft)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .font(.mono(28, weight: .medium))
                            .foregroundStyle(Palette.text)
                        Button("Save") {
                            month.income = Double(incomeDraft) ?? month.income
                            editingIncome = false
                        }
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(Palette.gold)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        Text(Money.string(month.income))
                            .font(.mono(28, weight: .medium))
                            .foregroundStyle(Palette.text)
                        Spacer()
                        if !month.isClosed {
                            Button {
                                incomeDraft = String(format: "%.0f", month.income)
                                editingIncome = true
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundStyle(Palette.gold)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Text(splitDescription(month.split))
                    .font(.mono(12))
                    .foregroundStyle(Palette.textMuted)
            }
        }
    }

    private func splitDescription(_ split: BudgetSplit) -> String {
        return "Needs " + Money.percent(split.needs / 100)
            + " · Savings " + Money.percent(split.savings / 100)
            + " · Wants " + Money.percent(split.wants / 100)
    }

    private func bucketsSection(_ month: MonthRecord) -> some View {
        VStack(spacing: 12) {
            ForEach(BudgetCategory.allCases) { category in
                BucketCard(category: category,
                           budget: month.budget(for: category),
                           spent: month.spent(for: category))
            }
        }
    }

    // MARK: Transactions

    private func transactionsSection(_ month: MonthRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel("Transactions")
                Spacer()
                if !month.isClosed {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add", systemImage: "plus")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(Palette.gold)
                    }
                    .buttonStyle(.plain)
                }
            }

            filterChips

            let txns = filteredTransactions(month)
            if txns.isEmpty {
                Text("No transactions yet.")
                    .font(.system(.subheadline))
                    .foregroundStyle(Palette.textMuted)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(txns) { txn in
                        TransactionRow(txn: txn)
                            .contextMenu {
                                if !month.isClosed {
                                    Button(role: .destructive) {
                                        LedgerService.delete(txn, in: context)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        if txn.id != txns.last?.id {
                            Divider().background(Palette.hairline)
                        }
                    }
                }
                .background(Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Palette.hairline, lineWidth: 1))
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddTransactionView(month: month)
                .preferredColorScheme(.dark)
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", color: Palette.gold, selected: filter == nil) {
                    filter = nil
                }
                ForEach(BudgetCategory.allCases) { category in
                    FilterChip(title: category.title,
                               color: Palette.color(for: category),
                               selected: filter == category) {
                        filter = (filter == category) ? nil : category
                    }
                }
            }
        }
    }

    private func filteredTransactions(_ month: MonthRecord) -> [Transaction] {
        month.txns
            .filter { filter == nil || $0.category == filter }
            .sorted { $0.date > $1.date }
    }

    private func closeMonthButton(_ month: MonthRecord) -> some View {
        Button {
            LedgerService.closeMonth(month, in: context)
            // Jump to the freshly opened next month.
            viewedKey = MonthKey.offset(month.key, by: 1)
        } label: {
            Text("Close \(MonthKey.shortMonthName(month.key)) & Start Next Month")
                .font(.system(.subheadline, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(Palette.textMuted)
                .background(Palette.surfaceHigh)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Palette.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bucket card with progress bar

struct BucketCard: View {
    let category: BudgetCategory
    let budget: Double
    let spent: Double

    private var remaining: Double { budget - spent }
    private var fraction: Double { budget > 0 ? min(spent / budget, 1) : 0 }
    private var over: Bool { spent > budget }

    var body: some View {
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Circle()
                        .fill(Palette.color(for: category))
                        .frame(width: 8, height: 8)
                    Text(category.title)
                        .font(.serif(17))
                        .foregroundStyle(Palette.text)
                    Spacer()
                    Text(Money.string(spent) + " / " + Money.string(budget))
                        .font(.mono(13))
                        .foregroundStyle(Palette.textMuted)
                }

                ProgressBar(fraction: fraction,
                            color: Palette.color(for: category),
                            over: over)

                HStack {
                    Text(over ? "Over by " + Money.string(-remaining)
                              : Money.string(remaining) + " remaining")
                        .font(.mono(12))
                        .foregroundStyle(over ? Palette.needs : Palette.textMuted)
                    Spacer()
                    Text(Money.percent(fraction))
                        .font(.mono(12))
                        .foregroundStyle(Palette.textMuted)
                }
            }
        }
    }
}

struct ProgressBar: View {
    let fraction: Double
    let color: Color
    var over: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.surfaceHigh)
                Capsule()
                    .fill(over ? Palette.needs : color)
                    .frame(width: max(0, geo.size.width * fraction))
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Filter chip

struct FilterChip: View {
    let title: String
    let color: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.mono(12, weight: .medium))
                .foregroundStyle(selected ? Palette.background : Palette.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(selected ? color : Palette.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(selected ? .clear : Palette.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Transaction row

struct TransactionRow: View {
    let txn: Transaction

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Palette.color(for: txn.category))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(txn.desc.isEmpty ? txn.category.title : txn.desc)
                    .font(.system(.body))
                    .foregroundStyle(Palette.text)
                Text(txn.date, format: .dateTime.month().day())
                    .font(.mono(11))
                    .foregroundStyle(Palette.textMuted)
            }
            Spacer()
            Text(Money.string(txn.amount))
                .font(.mono(15, weight: .medium))
                .foregroundStyle(Palette.text)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Saved indicator

struct SavedIndicator: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.icloud")
                .font(.system(size: 12))
            Text("Saved")
                .font(.mono(11))
        }
        .foregroundStyle(Palette.savings)
    }
}
