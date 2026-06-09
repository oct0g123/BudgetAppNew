//
//  BudgetView.swift
//  Ledger
//
//  The main screen, rebuilt on a native List: month navigation in the toolbar,
//  income, the three buckets with progress, and transactions with a segmented
//  filter and real swipe-to-delete. Closing a month now asks for confirmation.
//

import SwiftUI
import SwiftData

struct BudgetView: View {
    @Environment(\.modelContext) private var context

    @AppStorage("viewedMonthKey") private var viewedKey: String = MonthKey.current
    @Query(sort: \MonthRecord.key) private var months: [MonthRecord]

    @AppStorage("showBucketUsage") private var showBucketUsage = true

    @State private var filter: BudgetCategory? = nil
    @State private var showingAdd = false
    @State private var confirmingClose = false

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    private var currentMonth: MonthRecord? {
        months.first { $0.key == viewedKey }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let month = currentMonth {
                    monthList(month)
                } else {
                    emptyState
                }
            }
            .scrollContentBackground(.hidden)
            .background(DS.background.ignoresSafeArea())
            .navigationTitle(MonthKey.displayName(viewedKey))
            #if !os(macOS)
            .toolbarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button {
                        viewedKey = MonthKey.offset(viewedKey, by: -1)
                    } label: {
                        Label("Previous month", systemImage: "chevron.left")
                    }
                    Button {
                        viewedKey = MonthKey.offset(viewedKey, by: 1)
                    } label: {
                        Label("Next month", systemImage: "chevron.right")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add transaction", systemImage: "plus")
                    }
                    .disabled(currentMonth == nil || currentMonth?.isClosed == true)
                }
            }
        }
        .tint(DS.gold)
        .onAppear {
            // Make sure the real current month exists on first launch.
            if currentMonth == nil && viewedKey == MonthKey.current {
                LedgerService.ensureMonth(forKey: viewedKey, in: context)
            }
        }
        .sheet(isPresented: $showingAdd) {
            if let month = currentMonth {
                AddTransactionView(month: month)
            }
        }
        .confirmationDialog(
            "Close \(MonthKey.displayName(viewedKey))?",
            isPresented: $confirmingClose,
            titleVisibility: .visible
        ) {
            Button("Close Month", role: .destructive) {
                if let month = currentMonth {
                    LedgerService.closeMonth(month, in: context)
                    viewedKey = MonthKey.offset(month.key, by: 1)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The month becomes read-only and the next month starts fresh. This can't be undone.")
        }
    }

    // MARK: Month content

    private func monthList(_ month: MonthRecord) -> some View {
        List {
            if month.isClosed {
                Section {
                    Label("This month is closed and read-only.", systemImage: "lock.fill")
                        .font(.subheadline)
                        .foregroundStyle(DS.textMuted)
                }
                .listRowBackground(DS.surfaceHigh)
            }

            incomeSection(month)
            bucketsSection(month)
            transactionsSection(month)

            if !month.isClosed {
                Section {
                    Button(role: .destructive) {
                        confirmingClose = true
                    } label: {
                        Label("Close \(MonthKey.shortMonthName(month.key)) & Start Next Month",
                              systemImage: "checkmark.seal")
                            .frame(maxWidth: .infinity)
                    }
                }
                .listRowBackground(DS.surface)
            }
        }
    }

    // MARK: Income

    private func incomeSection(_ month: MonthRecord) -> some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Monthly Income")
                    .font(Typography.mono(.caption2, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(DS.goldDim)
                TextField("Income",
                          value: Binding(get: { month.income },
                                         set: { month.income = $0 }),
                          format: .currency(code: currencyCode))
                    .labelsHidden()
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .font(Typography.mono(.title, weight: .medium))
                    .foregroundStyle(DS.text)
                    .disabled(month.isClosed)
                Text(splitWords(month.split))
                    .font(Typography.mono(.footnote))
                    .foregroundStyle(DS.textMuted)
            }
            .padding(.vertical, Spacing.xs)
        }
        .listRowBackground(DS.surface)
    }

    private func splitWords(_ split: BudgetSplit) -> String {
        "Needs \(Int(split.needs))% · Savings \(Int(split.savings))% · Wants \(Int(split.wants))%"
    }

    // MARK: Buckets

    private func bucketsSection(_ month: MonthRecord) -> some View {
        Section("Buckets") {
            ForEach(BudgetCategory.allCases) { category in
                BucketRow(category: category,
                          budget: month.budget(for: category),
                          spent: month.spent(for: category),
                          showUsage: showBucketUsage)
            }
        }
        .listRowBackground(DS.surface)
    }

    // MARK: Transactions

    @ViewBuilder
    private func transactionsSection(_ month: MonthRecord) -> some View {
        Section("Transactions") {
            Picker("Filter", selection: $filter) {
                Text("All").tag(BudgetCategory?.none)
                ForEach(BudgetCategory.allCases) { category in
                    Text(category.title).tag(Optional(category))
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)

            let txns = filteredTransactions(month)
            if txns.isEmpty {
                Text(filter == nil ? "No transactions yet."
                                   : "No \(filter?.title.lowercased() ?? "") transactions.")
                    .font(.subheadline)
                    .foregroundStyle(DS.textMuted)
            } else {
                ForEach(txns) { txn in
                    TransactionRow(txn: txn)
                }
                .onDelete { offsets in
                    guard !month.isClosed else { return }
                    let txns = filteredTransactions(month)
                    for index in offsets {
                        LedgerService.delete(txns[index], in: context)
                    }
                }
                .deleteDisabled(month.isClosed)
            }
        }
        .listRowBackground(DS.surface)
    }

    private func filteredTransactions(_ month: MonthRecord) -> [Transaction] {
        month.txns
            .filter { filter == nil || $0.category == filter }
            .sorted { $0.date > $1.date }
    }

    // MARK: Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Label(MonthKey.displayName(viewedKey), systemImage: "calendar")
        } description: {
            Text("Start this month to begin tracking. It will use your default income and allocation from Settings.")
        } actions: {
            Button("Start \(MonthKey.displayName(viewedKey))") {
                LedgerService.ensureMonth(forKey: viewedKey, in: context)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Bucket row

struct BucketRow: View {
    let category: BudgetCategory
    let budget: Double
    let spent: Double
    var showUsage: Bool = true

    private var remaining: Double { budget - spent }
    private var fraction: Double { budget > 0 ? min(spent / budget, 1) : 0 }
    private var over: Bool { spent > budget }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Circle()
                    .fill(DS.category(category))
                    .frame(width: 9, height: 9)
                Text(category.title)
                    .font(Typography.serif(.headline))
                    .foregroundStyle(DS.text)
                Spacer()
                Text(Money.string(spent) + " / " + Money.string(budget))
                    .font(Typography.mono(.footnote))
                    .foregroundStyle(DS.textMuted)
            }

            ProgressView(value: fraction)
                .tint(over ? DS.needs : DS.category(category))

            HStack {
                Text(over ? "Over by " + Money.string(-remaining)
                          : Money.string(remaining) + " remaining")
                    .font(Typography.mono(.caption))
                    .foregroundStyle(over ? DS.needs : DS.textMuted)
                Spacer()
                if showUsage {
                    Text(Money.percent(fraction) + " used")
                        .font(Typography.mono(.caption))
                        .foregroundStyle(DS.textMuted)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Transaction row

struct TransactionRow: View {
    let txn: Transaction

    var body: some View {
        HStack(spacing: Spacing.md) {
            Circle()
                .fill(DS.category(txn.category))
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text(txn.desc.isEmpty ? txn.category.title : txn.desc)
                    .foregroundStyle(DS.text)
                Text(txn.date, format: .dateTime.month().day())
                    .font(Typography.mono(.caption))
                    .foregroundStyle(DS.textMuted)
            }
            Spacer()
            Text(Money.string(txn.amount))
                .font(Typography.mono(.body, weight: .medium))
                .foregroundStyle(DS.text)
        }
    }
}
