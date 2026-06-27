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
    @EnvironmentObject private var navigator: AppNavigator

    @AppStorage("viewedMonthKey") private var viewedKey: String = MonthKey.current
    @Query(sort: \MonthRecord.key) private var months: [MonthRecord]

    @AppStorage("showBucketUsage") private var showBucketUsage = true
    @AppStorage("hasCompletedOnboarding") private var hasOnboarded = false

    @State private var filter: BudgetCategory? = nil
    @State private var searchText = ""
    @State private var sort: TxnSort = .dateDesc
    @State private var showingAdd = false
    @State private var showingCommandBar = false
    @State private var editingTransaction: Transaction?
    @State private var confirmingClose = false
    @State private var closeCount = 0
    @State private var pendingUndo: [DeletedTxn] = []
    @State private var undoVisible = false
    @State private var undoToken = 0

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
            .overlay(alignment: .bottom) { undoToast }
            .animation(.spring(duration: 0.3), value: undoVisible)
            .navigationTitle("Budget")
            #if !os(macOS)
            .toolbarTitleDisplayMode(.large)
            #endif
            .toolbar {
                if IntelligenceService.isAvailable {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingCommandBar = true
                        } label: {
                            Label("Tell Ledger", systemImage: "sparkles")
                        }
                        .disabled(currentMonth == nil || currentMonth?.isClosed == true)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            ForEach(TxnSort.allCases, id: \.self) { option in
                                Text(option.label).tag(option)
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                    .disabled(currentMonth == nil)
                }
                // iOS has the floating bottom-right + button and visionOS has the
                // add ornament, so the toolbar + is only needed on macOS.
                #if os(macOS)
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add transaction", systemImage: "plus")
                    }
                    .disabled(currentMonth == nil || currentMonth?.isClosed == true)
                }
                #endif
            }
        }
        .tint(DS.gold)
        #if os(visionOS)
        .ornament(attachmentAnchor: .scene(.bottom)) { monthNavOrnament }
        .ornament(attachmentAnchor: .scene(.trailing)) { addOrnament }
        #endif
        .sensoryFeedback(.selection, trigger: filter)
        .sensoryFeedback(.success, trigger: closeCount)
        .task(id: viewedKey) {
            // Make sure the current month exists — but on a fresh install give
            // iCloud a few seconds to import an existing month first, so we
            // don't create an empty duplicate that has to be merged away. Skip
            // entirely until onboarding is done (onboarding creates the month).
            guard hasOnboarded, currentMonth == nil, viewedKey == MonthKey.current else { return }
            try? await Task.sleep(for: .seconds(4))
            if hasOnboarded, currentMonth == nil, viewedKey == MonthKey.current {
                LedgerService.ensureMonth(forKey: viewedKey, in: context)
            }
        }
        // Quick Add intent / Action Button hand-off (set by RootView).
        .onChange(of: navigator.requestAddTransaction) { _, req in
            if req { handleQuickAdd() }
        }
        .onAppear {
            if navigator.requestAddTransaction { handleQuickAdd() }
        }
        .sheet(isPresented: $showingAdd) {
            if let month = currentMonth {
                AddTransactionView(month: month)
            }
        }
        .sheet(item: $editingTransaction) { txn in
            AddTransactionView(existing: txn)
        }
        .sheet(isPresented: $showingCommandBar) {
            CommandBarView(month: currentMonth)
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

    // MARK: Month selector (header row under the "Budget" title)

    #if !os(visionOS)
    private var monthSelector: some View {
        HStack(spacing: Spacing.xl) {
            Button {
                viewedKey = MonthKey.offset(viewedKey, by: -1)
            } label: {
                Image(systemName: "chevron.left").font(.headline)
            }
            .accessibilityLabel("Previous month")

            Text(MonthKey.displayName(viewedKey))
                .font(Typography.serif(.title3, weight: .semibold))
                .foregroundStyle(DS.text)
                .frame(minWidth: 170)
                .contentTransition(.numericText())

            Button {
                viewedKey = MonthKey.offset(viewedKey, by: 1)
            } label: {
                Image(systemName: "chevron.right").font(.headline)
            }
            .accessibilityLabel("Next month")
        }
        .buttonStyle(.borderless)   // make each chevron tappable inside the List row
        .tint(DS.gold)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xs)
    }
    #endif

    // MARK: Month content

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func monthList(_ month: MonthRecord) -> some View {
        List {
            #if !os(visionOS)
            monthSelector
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Spacing.sm, leading: Spacing.md,
                                          bottom: 0, trailing: Spacing.md))
            #endif

            searchField

            if !isSearching {
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
            }

            transactionsSection(month)

            if !isSearching, !month.isClosed {
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

    /// In-list search field — sits below the pinned month selector and scrolls
    /// with the content. While searching, the income/category cards hide (above)
    /// so matches show right under the field.
    private var searchField: some View {
        Section {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DS.textMuted)
                TextField("Search transactions", text: $searchText)
                    .foregroundStyle(DS.text)
                    #if os(iOS)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    #endif
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DS.textMuted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 10)
            .background(DS.surfaceHigh,
                        in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: Spacing.sm, leading: Spacing.md,
                                      bottom: Spacing.xs, trailing: Spacing.md))
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
                MoneyField(amount: Binding(get: { month.income },
                                           set: { month.income = $0 }))
                    .labelsHidden()
                    .font(Typography.mono(.title, weight: .bold))
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
        Section("Categories") {
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
                let query = searchText.trimmingCharacters(in: .whitespaces)
                Text(!query.isEmpty ? "No transactions match \"\(query)\"."
                     : filter == nil ? "No transactions yet."
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
                    .hoverHighlight()
                    // Long-press (iPad/visionOS) / right-click (Mac) delete, since
                    // swipe-to-delete is awkward off iPhone. iPhone keeps swipe too.
                    .contextMenu {
                        Button {
                            editingTransaction = txn
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .disabled(month.isClosed)
                        Button(role: .destructive) {
                            performDelete([txn])
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(month.isClosed)
                    }
                }
                .onDelete { offsets in
                    guard !month.isClosed else { return }
                    let txns = filteredTransactions(month)
                    performDelete(offsets.map { txns[$0] })
                }
                .deleteDisabled(month.isClosed)
            }
        }
        .listRowBackground(DS.surface)
    }

    private func filteredTransactions(_ month: MonthRecord) -> [Transaction] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return month.txns
            .filter { filter == nil || $0.category == filter }
            .filter { query.isEmpty || $0.desc.lowercased().contains(query) }
            .sorted(by: sortPredicate)
    }

    private func sortPredicate(_ a: Transaction, _ b: Transaction) -> Bool {
        switch sort {
        case .dateDesc:   return a.date > b.date
        case .dateAsc:    return a.date < b.date
        case .amountDesc: return a.amount > b.amount
        case .amountAsc:  return a.amount < b.amount
        case .recurringFirst:
            let aRecurring = a.recurringRuleID != nil
            let bRecurring = b.recurringRuleID != nil
            if aRecurring != bRecurring { return aRecurring }  // recurring first
            return a.date > b.date                             // then newest within each group
        }
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

    // MARK: visionOS ornaments

    #if os(visionOS)
    /// Floating month navigation below the window — the signature visionOS way
    /// to flip between months (replaces the top-bar chevrons there).
    private var monthNavOrnament: some View {
        HStack(spacing: Spacing.lg) {
            Button {
                viewedKey = MonthKey.offset(viewedKey, by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            Text(MonthKey.displayName(viewedKey))
                .font(Typography.serif(.headline))
                .foregroundStyle(DS.text)
                .frame(minWidth: 160)
            Button {
                viewedKey = MonthKey.offset(viewedKey, by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .glassBackgroundEffect()
    }

    /// Floating add button off the trailing edge — the visionOS counterpart to
    /// the iOS bottom-right "+".
    private var addOrnament: some View {
        Button {
            showingAdd = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .padding(Spacing.sm)
        }
        .disabled(currentMonth == nil || currentMonth?.isClosed == true)
        .glassBackgroundEffect()
    }
    #endif

    // MARK: Quick add (Action Button / intent)

    private func handleQuickAdd() {
        guard navigator.requestAddTransaction else { return }
        navigator.requestAddTransaction = false
        if let month = currentMonth, !month.isClosed { showingAdd = true }
    }

    // MARK: Delete with undo

    private func performDelete(_ toDelete: [Transaction]) {
        guard !toDelete.isEmpty else { return }
        pendingUndo = toDelete.map {
            DeletedTxn(desc: $0.desc, amount: $0.amount, category: $0.category,
                       date: $0.date, recurringRuleID: $0.recurringRuleID, month: $0.month)
        }
        for txn in toDelete { LedgerService.delete(txn, in: context) }

        undoVisible = true
        undoToken += 1
        let token = undoToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            if token == undoToken {
                undoVisible = false
                pendingUndo = []
            }
        }
    }

    private func undoDelete() {
        for d in pendingUndo {
            guard let month = d.month else { continue }
            let txn = Transaction(desc: d.desc, amount: d.amount, category: d.category,
                                  date: d.date, recurringRuleID: d.recurringRuleID)
            txn.month = month
            context.insert(txn)
        }
        pendingUndo = []
        undoToken += 1
        undoVisible = false
    }

    @ViewBuilder
    private var undoToast: some View {
        if undoVisible {
            HStack(spacing: Spacing.md) {
                Text(pendingUndo.count > 1 ? "\(pendingUndo.count) deleted" : "Transaction deleted")
                    .font(Typography.mono(.footnote, weight: .medium))
                    .foregroundStyle(.white)
                Button("Undo") { undoDelete() }
                    .font(Typography.mono(.footnote, weight: .bold))
                    .foregroundStyle(DS.gold)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(Color.black.opacity(0.82), in: Capsule())
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            .padding(.bottom, 96)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 0) {
            #if !os(visionOS)
            monthSelector
                .padding(.top, Spacing.sm)
            #endif
            Spacer(minLength: 0)
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
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Transaction sort order

enum TxnSort: CaseIterable {
    case dateDesc, dateAsc, amountDesc, amountAsc, recurringFirst

    var label: String {
        switch self {
        case .dateDesc:        return "Newest first"
        case .dateAsc:         return "Oldest first"
        case .amountDesc:      return "Largest first"
        case .amountAsc:       return "Smallest first"
        case .recurringFirst:  return "Recurring first"
        }
    }
}

// MARK: - Deleted-transaction snapshot (for undo)

struct DeletedTxn: Identifiable {
    let id = UUID()
    var desc: String
    var amount: Double
    var category: BudgetCategory
    var date: Date
    var recurringRuleID: UUID?
    var month: MonthRecord?
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
        if over { return DS.over }
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
                .tint(alarmOver ? DS.over : DS.category(category))
                .animation(.spring(duration: 0.5), value: fraction)

            HStack {
                Text(statusText)
                    .font(Typography.mono(.caption))
                    .foregroundStyle(statusColor)
                Spacer()
                if showUsage {
                    Text(Money.percent(rawFraction) + " used")
                        .font(Typography.mono(.caption))
                        .foregroundStyle(alarmOver ? DS.over : DS.textMuted)
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
                .hoverHighlight()
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

// MARK: - AI command bar ("Tell Ledger")

/// Natural-language entry: type what you spent, the on-device model proposes
/// draft transactions, you review/edit, then confirm. Nothing is saved until
/// you tap Add (money always gets an explicit confirm).
struct CommandBarView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let month: MonthRecord?

    @State private var text = ""
    @State private var drafts: [DraftTxn] = []
    @State private var stage: Stage = .input
    @State private var notice: String?
    @State private var saveCount = 0

    private enum Stage { case input, thinking, review }

    var body: some View {
        NavigationStack {
            Group {
                if stage == .review { reviewForm } else { inputForm }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(DS.background.ignoresSafeArea())
            .navigationTitle("Tell Ledger")
            #if !os(macOS)
            .toolbarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if stage == .review {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add \(drafts.count)") { commit() }
                            .disabled(drafts.allSatisfy { $0.amount <= 0 })
                    }
                }
            }
        }
        .tint(DS.gold)
        .task { IntelligenceService.prewarm() }
        .sensoryFeedback(.success, trigger: saveCount)
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 360)
        #endif
    }

    private var inputForm: some View {
        Form {
            Section {
                TextField("e.g. spent $80 on groceries and $25 on a movie",
                          text: $text, axis: .vertical)
                    .lineLimit(2...5)
                    .foregroundStyle(DS.text)
            } footer: {
                Text("Describe what you spent or saved in plain English. You'll review everything before it's added. Processed entirely on your device.")
            }
            .listRowBackground(DS.surface)

            if let notice {
                Section { Text(notice).foregroundStyle(DS.needs).font(.subheadline) }
                    .listRowBackground(DS.surface)
            }

            Section {
                Button {
                    interpret()
                } label: {
                    HStack(spacing: Spacing.sm) {
                        if stage == .thinking { ProgressView() }
                        Label(stage == .thinking ? "Interpreting…" : "Interpret",
                              systemImage: "sparkles")
                        Spacer()
                    }
                }
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || stage == .thinking)
            }
            .listRowBackground(DS.surface)
        }
    }

    private var reviewForm: some View {
        Form {
            Section {
                ForEach($drafts) { $draft in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        TextField("Description", text: $draft.note)
                            .foregroundStyle(DS.text)
                        HStack {
                            MoneyField(placeholder: "Amount", amount: $draft.amount)
                                .font(Typography.mono(.body, weight: .medium))
                                .foregroundStyle(DS.text)
                            Spacer()
                            Picker("Category", selection: $draft.category) {
                                ForEach(BudgetCategory.allCases) { c in
                                    Text(c.title).tag(c)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .tint(DS.gold)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { drafts.remove(atOffsets: $0) }
            } header: {
                Text(drafts.count == 1 ? "1 transaction" : "\(drafts.count) transactions")
            } footer: {
                Text("Review and edit, then Add. Nothing is saved until you tap Add. Added to \(MonthKey.displayName(month?.key ?? MonthKey.current)).")
            }
            .listRowBackground(DS.surface)
        }
    }

    private func interpret() {
        notice = nil
        stage = .thinking
        let input = text
        Task {
            let result = await IntelligenceService.parse(input)
            await MainActor.run {
                if result.isEmpty {
                    notice = "Couldn't find any transactions in that. Try something like \"$40 dinner, $1200 rent\"."
                    stage = .input
                } else {
                    drafts = result
                    stage = .review
                }
            }
        }
    }

    private func commit() {
        guard let month else { dismiss(); return }
        for draft in drafts where draft.amount > 0 {
            let note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
            LedgerService.addTransaction(to: month,
                                         desc: note,
                                         amount: draft.amount,
                                         category: draft.category,
                                         date: Date(),
                                         in: context)
            // Remember your final category for this merchant for next time.
            CategoryMemory.remember(note, as: draft.category)
        }
        saveCount += 1
        dismiss()
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
