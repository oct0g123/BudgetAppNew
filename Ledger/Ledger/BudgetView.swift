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
    @State private var editingTransaction: Transaction?
    @State private var confirmingClose = false
    @State private var closeCount = 0

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
            #if os(iOS)
            .overlay(alignment: .bottomTrailing) { addButton }
            #endif
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
        .sensoryFeedback(.selection, trigger: filter)
        .sensoryFeedback(.success, trigger: closeCount)
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
        .sheet(item: $editingTransaction) { txn in
            AddTransactionView(existing: txn)
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
                    closeCount += 1
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
                    Button {
                        LedgerService.reopenMonth(month, in: context)
                    } label: {
                        Label("Reopen Month", systemImage: "lock.open")
                    }
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
        // Floating glass filter pill, detached above the transaction rows.
        Section {
            TransactionFilterBar(filter: $filter)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Spacing.md, leading: Spacing.md,
                                          bottom: Spacing.xs, trailing: Spacing.md))
        }

        Section {
            let txns = filteredTransactions(month)
            if txns.isEmpty {
                Text(filter == nil ? "No transactions yet."
                                   : "No \(filter?.title.lowercased() ?? "") transactions.")
                    .font(.subheadline)
                    .foregroundStyle(DS.textMuted)
            } else {
                ForEach(txns) { txn in
                    Button {
                        if !month.isClosed { editingTransaction = txn }
                    } label: {
                        TransactionRow(txn: txn)
                    }
                    .buttonStyle(.plain)
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

    // MARK: Floating add button (iOS)

    @ViewBuilder
    private var addButton: some View {
        if let month = currentMonth, !month.isClosed {
            Button {
                showingAdd = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DS.background)
                    .frame(width: 56, height: 56)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassCircle(tint: DS.gold)
            .padding(Spacing.xl)
            .accessibilityLabel("Add transaction")
        }
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
    /// Uncapped ratio for the label (can exceed 100%).
    private var rawFraction: Double { budget > 0 ? spent / budget : 0 }
    /// Clamped for the progress bar.
    private var fraction: Double { min(rawFraction, 1) }
    private var over: Bool { spent > budget }
    private var isSavings: Bool { category == .savings }
    /// Going over Savings is a good thing, so it's never the "alarm" red.
    private var alarmOver: Bool { over && !isSavings }

    private var statusText: String {
        if over && isSavings {
            return Money.string(-remaining) + " past goal"
        } else if over {
            return "Over by " + Money.string(-remaining)
        } else {
            return Money.string(remaining) + " remaining"
        }
    }

    private var statusColor: Color {
        if over && isSavings { return DS.savings }
        if over { return DS.needs }
        return DS.textMuted
    }

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
                    .contentTransition(.numericText(value: spent))
            }

            ProgressView(value: fraction)
                .tint(alarmOver ? DS.needs : DS.category(category))
                .animation(.spring(duration: 0.5), value: fraction)

            HStack {
                Text(statusText)
                    .font(Typography.mono(.caption))
                    .foregroundStyle(statusColor)
                Spacer()
                if showUsage {
                    Text(Money.percent(rawFraction) + " used")
                        .font(Typography.mono(.caption))
                        .foregroundStyle(alarmOver ? DS.needs : DS.textMuted)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
        .animation(.snappy(duration: 0.3), value: spent)
    }
}

// MARK: - Floating glass filter bar

/// A custom segmented filter that floats on a Liquid Glass capsule (iOS/macOS/
/// visionOS 26), falling back to a translucent material on earlier systems.
struct TransactionFilterBar: View {
    @Binding var filter: BudgetCategory?

    private var options: [(title: String, value: BudgetCategory?)] {
        [("All", nil)] + BudgetCategory.allCases.map { ($0.title, Optional($0)) }
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.title) { option in
                Button {
                    withAnimation(.snappy(duration: 0.25)) { filter = option.value }
                } label: {
                    Text(option.title)
                        .font(Typography.mono(.subheadline, weight: .medium))
                        .foregroundStyle(filter == option.value ? DS.background : DS.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if filter == option.value {
                                Capsule().fill(option.value.map { DS.category($0) } ?? DS.gold)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .glassCapsule()
        .frame(maxWidth: .infinity)
    }
}

extension View {
    /// Liquid Glass capsule background where available, translucent material
    /// otherwise.
    @ViewBuilder
    func glassCapsule() -> some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            self.glassEffect(.regular, in: .capsule)
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(DS.hairline, lineWidth: 1))
        }
    }

    /// Tinted, interactive Liquid Glass circle where available; a solid tinted
    /// circle with a soft shadow otherwise.
    @ViewBuilder
    func glassCircle(tint: Color) -> some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            self.glassEffect(.regular.tint(tint).interactive(), in: .circle)
        } else {
            self.background(tint, in: Circle())
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        }
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
