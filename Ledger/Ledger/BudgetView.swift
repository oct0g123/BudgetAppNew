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
import StoreKit

struct BudgetView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject private var navigator: AppNavigator

    @AppStorage("viewedMonthKey") private var viewedKey: String = MonthKey.current
    @Query(sort: \MonthRecord.key) private var months: [MonthRecord]

    @AppStorage("showBucketUsage") private var showBucketUsage = true
    @AppStorage("hasCompletedOnboarding") private var hasOnboarded = false
    @AppStorage("hasRequestedReview") private var hasRequestedReview = false

    @State private var filter: BudgetCategory? = nil
    @State private var searchText = ""
    /// Trails `searchText` by ~250ms so the txn list isn't re-filtered + sorted
    /// on every keystroke; UI chrome (hiding cards/pills) still reacts instantly.
    @State private var debouncedSearch = ""
    @State private var sort: TxnSort = .dateDesc
    @State private var showingAdd = false
    @State private var showingCommandBar = false
    @State private var editingTransaction: Transaction?
    @State private var confirmingClose = false
    @State private var closeCount = 0
    @State private var pendingUndo: [DeletedTxn] = []
    @State private var undoVisible = false
    @State private var undoToken = 0
    /// The just-closed month, presented as a RecapView sheet (the "ritual"
    /// wrap-up moment). Review prompt fires after this dismisses.
    @State private var recapMonth: MonthRecord?

    private var currentMonth: MonthRecord? {
        // Canonical pick: a duplicate month waiting out its delete-grace
        // period (see LedgerService merge notes) must never be the one shown.
        LedgerService.canonical(months, key: viewedKey)
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
            .screenBackground()
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
                // Hidden (not grayed) when the month is closed or missing —
                // matching the + button's behavior. A permanently-gray toolbar
                // icon reads as broken, especially on visionOS.
                if IntelligenceService.isAvailable,
                   let m = currentMonth, !m.isClosed {
                    ToolbarItem(placement: .primaryAction) {
                        // visionOS stomps custom glyph colors in toolbars (the
                        // label always renders in the standard glass style), so
                        // gold has to come from a prominent button tint there —
                        // which also matches the gold sort button beside it.
                        #if os(visionOS)
                        Button {
                            showingCommandBar = true
                        } label: {
                            Label("Tell Ledger", systemImage: "sparkles")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(DS.gold)
                        #else
                        Button {
                            showingCommandBar = true
                        } label: {
                            Label("Tell Ledger", systemImage: "sparkles")
                                .foregroundStyle(DS.gold)
                        }
                        #endif
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
                    recapMonth = month   // pop the wrap-up sheet
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The month becomes read-only and the next month starts fresh. This can't be undone.")
        }
        // The month-close recap — and the best-timed moment to ask for a
        // rating: right after the user reviews a finished month.
        .sheet(item: $recapMonth, onDismiss: { maybeRequestReview() }) { month in
            RecapView(month: month,
                      previousMonth: LedgerService.canonicalMonths(months)
                          .last(where: { $0.key < month.key }))
        }
    }

    // MARK: Month selector (header row under the "Budget" title)

    #if !os(visionOS)
    /// Month anchors the leading edge; the chevrons sit as an adjacent pair on
    /// the trailing edge — the system date-picker / Calendar pattern, replacing
    /// the old centered layout whose spread-apart chevrons floated unanchored.
    private var monthSelector: some View {
        HStack(spacing: Spacing.lg) {
            Text(MonthKey.displayName(viewedKey))
                .font(Typography.serif(.title3, weight: .semibold))
                .foregroundStyle(DS.text)
                .contentTransition(.numericText())

            Spacer(minLength: Spacing.lg)

            HStack(spacing: Spacing.xl) {
                Button {
                    viewedKey = MonthKey.offset(viewedKey, by: -1)
                } label: {
                    Image(systemName: "chevron.left").font(.headline)
                        .frame(width: 32, height: 32)   // comfortable tap target
                }
                .accessibilityLabel("Previous month")

                Button {
                    viewedKey = MonthKey.offset(viewedKey, by: 1)
                } label: {
                    Image(systemName: "chevron.right").font(.headline)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("Next month")
            }
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

    // MARK: Review prompt

    /// Ask for a rating once, right after the user closes their first month —
    /// a natural "this app worked for me" moment. The system decides whether
    /// the prompt actually appears (Apple caps it at ~3/year), so one
    /// well-placed request is all we ever make. Delayed slightly so the
    /// close-month transition settles first.
    private func maybeRequestReview() {
        guard !hasRequestedReview else { return }
        hasRequestedReview = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            requestReview()
        }
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
                .listRowBackground(DS.rowBackgroundHigh())
            }

            incomeSection(month)
            bucketsSection(month)

            // Search lives with the transactions it filters; results appear
            // directly beneath it, so the cards above no longer need to hide.
            searchField

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
                .listRowBackground(DS.rowBackground())
            }
        }
        // Pull-to-refresh: wait out any in-flight iCloud import, then merge
        // and republish so newly synced changes appear right away.
        .refreshable {
            await LedgerService.refreshFromCloud(in: context)
        }
        // Without this, the search keyboard has no way to be dismissed on
        // iPhone — scrolling the list now drops it immediately. (The API
        // doesn't exist on visionOS, whose keyboard floats beside the window.)
        #if !os(visionOS)
        .scrollDismissesKeyboard(.immediately)
        #endif
    }

    /// In-list search field — sits directly above the transaction rows it
    /// filters, so matches appear right beneath it. While searching, the
    /// category filter pills hide (the filter is ignored so a leftover pill
    /// can't mask matches).
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
                    .task(id: searchText) {
                        // Clearing applies immediately; typing settles for 250ms
                        // first. Cancellation (next keystroke) skips the update.
                        if searchText.isEmpty {
                            debouncedSearch = ""
                            return
                        }
                        try? await Task.sleep(for: .milliseconds(250))
                        guard !Task.isCancelled else { return }
                        debouncedSearch = searchText
                    }
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
            .background(DS.surfaceHighStyle,
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
                MonthIncomeField(month: month)
                    .id(month.key)   // fresh draft when you switch months
                Text(splitWords(month.split))
                    .font(Typography.mono(.footnote))
                    .foregroundStyle(DS.textMuted)
            }
            .padding(.vertical, Spacing.xs)
        }
        .listRowBackground(DS.rowBackground())
    }

    /// The month's income field. Typing updates a local draft and only writes
    /// the model ~½s after you stop — a write per keystroke meant a SwiftData
    /// save + CloudKit export + full budget-list rebuild per character.
    private struct MonthIncomeField: View {
        let month: MonthRecord
        @State private var draft: Double = 0
        @State private var loaded = false

        var body: some View {
            MoneyField(amount: $draft)
                .labelsHidden()
                .font(Typography.mono(.title, weight: .bold))
                .foregroundStyle(DS.text)
                .disabled(month.isClosed)
                .onAppear {
                    draft = month.income
                    loaded = true
                }
                .task(id: draft) {
                    guard loaded else { return }
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    commit()
                }
                .onChange(of: month.income) { _, newValue in
                    // Reflect a sync/import that landed while we weren't typing.
                    if abs(newValue - draft) > 0.0001 { draft = newValue }
                }
                .onDisappear { commit() }
        }

        private func commit() {
            guard loaded, !month.isClosed,
                  abs(draft - month.income) > 0.0001 else { return }
            month.income = draft
        }
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
                          showUsage: showBucketUsage,
                          pace: paceText(for: month, category: category))
            }
        }
        .listRowBackground(DS.rowBackground())
    }

    /// "$625/wk" pacing for Needs/Wants on the LIVE month: what's left spread
    /// over the time remaining. Switches to "/day" inside the final week.
    /// Savings is excluded (it's a goal, not a spending allowance), as are
    /// past/future/closed months where pacing has no meaning.
    private func paceText(for month: MonthRecord, category: BudgetCategory) -> String? {
        guard category != .savings,
              month.key == MonthKey.current, !month.isClosed else { return nil }
        let remaining = month.remaining(for: category)
        guard remaining > 0 else { return nil }
        let daysLeft = MonthKey.daysRemainingInCurrentMonth()
        if daysLeft <= 7 {
            return Money.string(remaining / Double(daysLeft)) + "/day"
        }
        return Money.string(remaining * 7 / Double(daysLeft)) + "/wk"
    }

    // MARK: Transactions

    @ViewBuilder
    private func transactionsSection(_ month: MonthRecord) -> some View {
        // Floating glass filter pill, detached above the transaction rows.
        // Hidden while searching — search spans all categories, so a visible
        // (but ignored) pill would be misleading.
        if !isSearching {
            Section {
                TransactionFilterBar(filter: $filter)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: Spacing.md, leading: Spacing.md,
                                              bottom: Spacing.xs, trailing: Spacing.md))
            }
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
        .listRowBackground(DS.rowBackground())
    }

    private func filteredTransactions(_ month: MonthRecord) -> [Transaction] {
        let query = debouncedSearch.trimmingCharacters(in: .whitespaces).lowercased()
        let searching = !query.isEmpty
        return month.txns
            // While searching, ignore the category pill so a leftover filter
            // can't hide matches that live in other categories.
            .filter { searching || filter == nil || $0.category == filter }
            .filter { query.isEmpty
                || $0.desc.lowercased().contains(query)
                || $0.memo.lowercased().contains(query) }
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
            .accessibilityLabel("Previous month")
            Text(MonthKey.displayName(viewedKey))
                .font(Typography.serif(.headline))
                .foregroundStyle(DS.text)
                .frame(minWidth: 160)
            Button {
                viewedKey = MonthKey.offset(viewedKey, by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("Next month")
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
        .accessibilityLabel("Add transaction")
        .disabled(currentMonth == nil || currentMonth?.isClosed == true)
        .glassBackgroundEffect()
    }
    #endif

    // MARK: Quick add (Action Button / intent)

    private func handleQuickAdd() {
        guard navigator.requestAddTransaction else { return }
        navigator.requestAddTransaction = false
        // Ensure the current month exists so quick-add always has a target —
        // e.g. on a cold launch before the month has been created. (Previously
        // the request was silently dropped when currentMonth was nil.)
        let month = currentMonth ?? LedgerService.ensureMonth(forKey: viewedKey, in: context)
        if !month.isClosed { showingAdd = true }
    }

    // MARK: Delete with undo

    private func performDelete(_ toDelete: [Transaction]) {
        guard !toDelete.isEmpty else { return }
        pendingUndo = toDelete.map {
            DeletedTxn(desc: $0.desc, amount: $0.amount, category: $0.category,
                       date: $0.date, memo: $0.memo,
                       recurringRuleID: $0.recurringRuleID, month: $0.month)
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
                                  date: d.date, memo: d.memo,
                                  recurringRuleID: d.recurringRuleID)
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
                // Match the List's effective row inset (its ~20pt content
                // margin + the Spacing.md row inset) so the month row sits at
                // the same x-position whether or not the month has started.
                .padding(.horizontal, Spacing.xl + Spacing.md)
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
    var memo: String
    var recurringRuleID: UUID?
    var month: MonthRecord?
}

// MARK: - Bucket row

struct BucketRow: View {
    let category: BudgetCategory
    let budget: Double
    let spent: Double
    var showUsage: Bool = true
    /// Optional live-month pacing ("$625/wk"), appended to the status line.
    var pace: String? = nil

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
        } else if let pace {
            return Money.string(remaining) + " remaining · " + pace
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
        // One VoiceOver element per bucket ("Needs, $2,500 of $5,000, $2,500
        // remaining, 50% used") instead of four fragments + a decorative dot.
        .accessibilityElement(children: .combine)
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

    // Full-width, thumb-sized segments are right on iPhone/iPad; on a wide Mac
    // window they balloon, so the bar compacts and caps its width there.
    #if os(macOS)
    private let pillVerticalPadding: CGFloat = 5
    private let barMaxWidth: CGFloat = 420
    #else
    private let pillVerticalPadding: CGFloat = 9
    private let barMaxWidth: CGFloat = .infinity
    #endif

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
                        .padding(.vertical, pillVerticalPadding)
                        .background {
                            if filter == option.value {
                                Capsule().fill(option.value.map { DS.category($0) } ?? DS.gold)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .hoverHighlight()
                // VoiceOver announces which filter is active.
                .accessibilityAddTraits(filter == option.value ? .isSelected : [])
            }
        }
        .padding(5)
        .glassCapsule()
        .frame(maxWidth: barMaxWidth)
        .frame(maxWidth: .infinity)   // center the capped bar in the row
    }
}

extension View {
    /// Liquid Glass capsule background where available, translucent material
    /// otherwise.
    @ViewBuilder
    func glassCapsule() -> some View {
        // Liquid Glass exists on iOS/macOS only; visionOS uses a material.
        #if os(iOS) || os(macOS)
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(.regular, in: .capsule)
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(DS.hairline, lineWidth: 1))
        }
        #else
        self.background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(DS.hairline, lineWidth: 1))
        #endif
    }

    /// Tinted, interactive Liquid Glass circle where available; a solid tinted
    /// circle with a soft shadow otherwise.
    @ViewBuilder
    func glassCircle(tint: Color) -> some View {
        #if os(iOS) || os(macOS)
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(.regular.tint(tint).interactive(), in: .circle)
        } else {
            self.background(tint, in: Circle())
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        }
        #else
        self.background(tint, in: Circle())
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        #endif
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
            .screenBackground()
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
                // Title via `prompt` + labelsHidden: on macOS a TextField's
                // title renders as a leading LABEL with the input right-aligned
                // like a form value — which made the example text look like a
                // real entry. A prompt is a true placeholder on every platform.
                TextField("Describe your spending",
                          text: $text,
                          prompt: Text("e.g. spent $80 on groceries and $25 on a movie"),
                          axis: .vertical)
                    .labelsHidden()
                    .multilineTextAlignment(.leading)
                    .lineLimit(2...5)
                    .foregroundStyle(DS.text)
            } footer: {
                Text("Describe what you spent or saved in plain English. You'll review everything before it's added. Processed entirely on your device.")
            }
            .listRowBackground(DS.rowBackground())

            if let notice {
                Section { Text(notice).foregroundStyle(DS.needs).font(.subheadline) }
                    .listRowBackground(DS.rowBackground())
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
            .listRowBackground(DS.rowBackground())
        }
    }

    private var reviewForm: some View {
        Form {
            Section {
                ForEach($drafts) { $draft in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        TextField("Description", text: $draft.note,
                                  prompt: Text("Description"))
                            .labelsHidden()
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(DS.text)
                        HStack {
                            MoneyField(placeholder: "Amount", amount: $draft.amount)
                                .labelsHidden()
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
            .listRowBackground(DS.rowBackground())
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

    /// Generated from (or saved as) a recurring rule.
    private var isRecurring: Bool { txn.recurringRuleID != nil }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Circle()
                .fill(DS.category(txn.category))
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text(txn.desc.isEmpty ? txn.category.title : txn.desc)
                    .foregroundStyle(DS.text)
                HStack(spacing: 5) {
                    // Marks a rule-driven charge so a month's fixed costs are
                    // readable at a glance (pairs with the "Recurring first"
                    // sort). A glyph, not a color, so it survives color-blind
                    // vision and grayscale.
                    if isRecurring {
                        Image(systemName: "repeat")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(DS.goldDim)
                    }
                    Text(txn.date, format: .dateTime.month().day())
                        .font(Typography.mono(.caption))
                        .foregroundStyle(DS.textMuted)
                        .fixedSize()
                    // The memo rides the existing caption line rather than
                    // adding a third row, so rows without one are unchanged.
                    if !txn.memo.isEmpty {
                        Text("· \(txn.memo)")
                            .font(.caption)
                            .foregroundStyle(DS.textMuted)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
            Spacer(minLength: Spacing.sm)
            Text(Money.string(txn.amount))
                .font(Typography.mono(.body, weight: .medium))
                .foregroundStyle(DS.text)
                .layoutPriority(1)   // a long memo truncates; the amount never does
        }
        // The category is conveyed only by the dot's color, so VoiceOver gets
        // it spoken explicitly alongside the description, amount, and date.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(txn.desc.isEmpty ? txn.category.title : txn.desc), \(Money.string(txn.amount)), \(txn.category.title), \(txn.date.formatted(.dateTime.month().day()))\(isRecurring ? ", repeats monthly" : "")\(txn.memo.isEmpty ? "" : ", note: \(txn.memo)")")
    }
}
