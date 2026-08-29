//
//  RecurringView.swift
//  Ledger
//
//  The Settings sub-screens for user-managed lists:
//
//   • Recurring transactions (rent, subscriptions, paychecks…) — tap to edit,
//     swipe to delete, toggle to pause.
//   • Payment cards — hand-entered labels for tagging a transaction with how
//     you paid. Same list + editor shape, which is why they share a file.
//
//  Cards live here rather than in their own CardsView.swift because the app
//  target uses explicit file references (only LedgerWidgets is a synchronized
//  group), so a new file has to be added to the target by hand in Xcode.
//

import SwiftUI
import SwiftData

struct RecurringView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RecurringRule.createdAt) private var rules: [RecurringRule]

    @State private var editing: RecurringRule?
    @State private var showingNew = false

    var body: some View {
        Group {
            if rules.isEmpty {
                ContentUnavailableView {
                    Label("No recurring transactions", systemImage: "arrow.triangle.2.circlepath")
                } description: {
                    Text("Rules are added to each new month automatically — rent, subscriptions, or a regular savings transfer.")
                } actions: {
                    Button("Add Recurring") { showingNew = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    Section {
                        ForEach(rules) { rule in
                            ruleRow(rule)
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(rules[index]) }
                        }
                    } footer: {
                        Text("Active rules are added to each new month automatically. Editing one updates this month and future months; past months keep what they were charged.")
                    }
                    .listRowBackground(DS.rowBackground())
                }
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Recurring")
        #if !os(macOS)
        .toolbarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNew = true
                } label: {
                    Label("Add recurring", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNew) {
            RecurringEditor(rule: nil)
        }
        .sheet(item: $editing) { rule in
            RecurringEditor(rule: rule)
        }
        .tint(DS.gold)
    }

    private func ruleRow(_ rule: RecurringRule) -> some View {
        HStack(spacing: Spacing.md) {
            Button {
                editing = rule
            } label: {
                HStack(spacing: Spacing.md) {
                    Circle()
                        .fill(DS.category(rule.category))
                        .frame(width: 9, height: 9)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rule.desc.isEmpty ? rule.category.title : rule.desc)
                            .foregroundStyle(DS.text)
                        Text(subtitle(rule))
                            .font(Typography.mono(.caption))
                            .foregroundStyle(DS.textMuted)
                    }
                    Spacer()
                    Text(Money.string(rule.amount))
                        .font(Typography.mono(.body, weight: .medium))
                        .foregroundStyle(rule.isActive ? DS.text : DS.textMuted)
                }
            }
            .buttonStyle(.plain)

            Toggle("Active", isOn: Binding(
                get: { rule.isActive },
                set: { newValue in
                    rule.isActive = newValue
                    if newValue { LedgerService.applyRule(rule, in: context) }
                }))
                .labelsHidden()
                .tint(DS.savings)
        }
        .opacity(rule.isActive && !rule.hasFinished ? 1 : 0.6)
    }

    /// "Day 1 · Needs · from Aug · through Oct" — the end reads as "ended" once
    /// it's behind us, so a finished rule doesn't look merely paused.
    private func subtitle(_ rule: RecurringRule) -> String {
        var text = "Day \(rule.dayOfMonth) · \(rule.category.title) · from \(MonthKey.shortMonthName(rule.startKey))"
        if let end = rule.endKey {
            text += rule.hasFinished ? " · ended \(MonthKey.shortMonthName(end))"
                                     : " · through \(MonthKey.shortMonthName(end))"
        }
        return text
    }
}

// MARK: - Editor

struct RecurringEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("viewedMonthKey") private var viewedKey: String = MonthKey.current

    /// nil = creating a new rule.
    let rule: RecurringRule?

    @State private var desc = ""
    @State private var amount: Double? = nil
    @State private var category: BudgetCategory = .needs
    @State private var day = 1
    @State private var isLimited = false
    @State private var monthCount = 3
    /// Exactly what the rule had when the sheet opened. An untouched duration is
    /// written back verbatim, so opening a rule to change its AMOUNT can never
    /// alter its schedule — that path could otherwise truncate a long rule,
    /// restart a finished one, or delete charges.
    @State private var loadedIsLimited = false
    @State private var loadedDisplayCount = 3
    @State private var loadedEndKey: String?

    private var isValid: Bool { (amount ?? 0) > 0 }

    /// An existing rule keeps its own start; a new one begins in the viewed month.
    private var effectiveStartKey: String { rule?.startKey ?? viewedKey }

    /// Where a NEWLY SET duration starts counting.
    ///
    /// For a rule already underway that's the CURRENT month, not the rule's
    /// original start: "3 months" on a rule that began in January has to mean
    /// "3 more months". Counting from January would put the end in the past, and
    /// `applyRule`'s retraction branch would then delete that rule's charge from
    /// every open month in between — silently, and with no undo.
    /// Keys are "YYYY-MM", so lexical order is chronological order.
    private var anchorKey: String {
        guard let rule else { return viewedKey }
        return max(rule.startKey, MonthKey.current)
    }

    /// nil = runs until switched off. The UI counts months because that's how
    /// people think about it ("3 payments"); the model stores the resulting end
    /// month, which can't drift the way a decrementing counter would.
    private var computedEndKey: String? {
        // Duration untouched → hand back precisely what was stored.
        if isLimited == loadedIsLimited, monthCount == loadedDisplayCount {
            return loadedEndKey
        }
        guard isLimited else { return nil }
        return MonthKey.offset(anchorKey, by: monthCount - 1)
    }

    private var durationFooter: String {
        guard let end = computedEndKey else {
            return "Repeats every month until you turn it off."
        }
        if end < MonthKey.current {
            return "Ended \(MonthKey.displayName(end)). Change the number of months to restart it from \(MonthKey.displayName(anchorKey))."
        }
        // Describe the range actually being stored, so the count and the months
        // can never disagree with each other.
        let start = end < anchorKey ? effectiveStartKey : anchorKey
        let count = max(MonthKey.monthsBetween(start, end) + 1, 1)
        let times = count == 1 ? "once" : "\(count) times"
        return "Charges \(times) — \(MonthKey.displayName(start)) through \(MonthKey.displayName(end))."
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Description", text: $desc, prompt: Text("e.g. Rent"))
                        .foregroundStyle(DS.text)
                    MoneyField(placeholder: "Amount",
                               amount: Binding(get: { amount ?? 0 }, set: { amount = $0 }))
                        .font(Typography.mono(.body, weight: .medium))
                        .foregroundStyle(DS.text)
                }
                .listRowBackground(DS.rowBackground())

                Section {
                    Picker("Category", selection: $category) {
                        ForEach(BudgetCategory.allCases) { cat in
                            Text(cat.title).tag(cat)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Stepper(value: $day, in: 1...28) {
                        LabeledContent("Day of month") {
                            TextField("Day", value: $day, format: .number)
                                .labelsHidden()
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                                .multilineTextAlignment(.trailing)
                                .font(Typography.mono(.body, weight: .medium))
                                .foregroundStyle(DS.text)
                                .frame(width: 44)
                                .onChange(of: day) { _, newValue in
                                    day = min(max(newValue, 1), 28)
                                }
                        }
                    }
                } footer: {
                    Text("The transaction is dated this day in each month (capped at 28 so it exists in every month).")
                }
                .listRowBackground(DS.rowBackground())

                Section {
                    Toggle(isOn: $isLimited) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ends after a set number of months")
                            Text("For installments or a fixed-term plan")
                                .font(.caption)
                                .foregroundStyle(DS.textMuted)
                        }
                    }
                    .tint(DS.savings)

                    if isLimited {
                        Stepper(value: $monthCount, in: 1...60) {
                            LabeledContent("Number of months") {
                                Text("\(monthCount)")
                                    .font(Typography.mono(.body, weight: .medium))
                                    .foregroundStyle(DS.text)
                            }
                        }
                    }
                } header: {
                    Text("Duration")
                } footer: {
                    Text(durationFooter)
                }
                .listRowBackground(DS.rowBackground())
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .screenBackground()
            // How the numeric keypad gets dismissed: it has no Return key, so
            // scrolling the form drops it. (Unavailable on visionOS, whose
            // keyboard floats beside the window with its own dismiss control.)
            #if !os(visionOS)
            .scrollDismissesKeyboard(.immediately)
            #endif
            .navigationTitle(rule == nil ? "New Recurring" : "Edit Recurring")
            #if !os(macOS)
            .toolbarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
            .onAppear(perform: load)
        }
        .tint(DS.gold)
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 470)
        #endif
    }

    private func load() {
        guard let rule else { return }
        desc = rule.desc
        amount = rule.amount
        category = rule.category
        day = rule.dayOfMonth
        if let end = rule.endKey {
            isLimited = true
            loadedIsLimited = true
            loadedEndKey = end
            // REMAINING months, not the rule's total span, so the number means
            // "months from here" both on open and after a change.
            monthCount = min(max(MonthKey.monthsBetween(anchorKey, end) + 1, 1), 60)
        }
        loadedDisplayCount = monthCount
    }

    private func save() {
        guard let value = amount, value > 0 else { return }
        let trimmed = desc.trimmingCharacters(in: .whitespacesAndNewlines)
        if let rule {
            rule.desc = trimmed
            rule.amount = value
            rule.category = category
            rule.dayOfMonth = day
            rule.endKey = computedEndKey
            LedgerService.applyRule(rule, in: context)
        } else {
            let newRule = RecurringRule(desc: trimmed,
                                        amount: value,
                                        category: category,
                                        dayOfMonth: day,
                                        startKey: viewedKey,
                                        endKey: computedEndKey)
            context.insert(newRule)
            LedgerService.applyRule(newRule, in: context)
        }
        dismiss()
    }
}

// MARK: - Payment cards

struct CardsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PaymentCard.createdAt) private var cards: [PaymentCard]
    @Query private var months: [MonthRecord]

    @State private var editing: PaymentCard?
    @State private var showingNew = false

    private var active: [PaymentCard] { PaymentCard.uniqued(cards).filter { !$0.isArchived } }
    private var archived: [PaymentCard] { PaymentCard.uniqued(cards).filter(\.isArchived) }

    /// How many transactions in the CURRENT month used each card — makes the
    /// screen read as live data rather than a settings dump. One pass over the
    /// month, not one per card.
    private var usageThisMonth: [UUID: Int] {
        guard let month = LedgerService.canonical(months, key: MonthKey.current) else { return [:] }
        var counts: [UUID: Int] = [:]
        for txn in month.txns {
            if let id = txn.cardID { counts[id, default: 0] += 1 }
        }
        return counts
    }

    var body: some View {
        Group {
            if cards.isEmpty {
                ContentUnavailableView {
                    Label("No cards", systemImage: "creditcard")
                } description: {
                    Text("Add a card to tag transactions with how you paid. Ledger never connects to an account and doesn't track balances.")
                } actions: {
                    Button("Add Card") { showingNew = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    let counts = usageThisMonth
                    Section {
                        ForEach(active) { card in
                            cardRow(card, count: counts[card.id] ?? 0)
                        }
                    } footer: {
                        Text("Cards are labels only — Ledger never connects to an account and doesn't track balances.")
                    }
                    .listRowBackground(DS.rowBackground())

                    if !archived.isEmpty {
                        Section {
                            ForEach(archived) { card in
                                cardRow(card, count: counts[card.id] ?? 0)
                            }
                        } header: {
                            Text("Archived")
                        } footer: {
                            Text("Hidden when adding a transaction. Past transactions keep their label.")
                        }
                        .listRowBackground(DS.rowBackground())
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Cards")
        #if !os(macOS)
        .toolbarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNew = true
                } label: {
                    Label("Add card", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNew) { CardEditor(card: nil) }
        .sheet(item: $editing) { card in CardEditor(card: card) }
        .tint(DS.gold)
    }

    private func cardRow(_ card: PaymentCard, count: Int) -> some View {
        Button {
            editing = card
        } label: {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.name.isEmpty ? "Untitled card" : card.name)
                        .foregroundStyle(DS.text)
                    Text(card.tag)
                        .font(Typography.mono(.caption))
                        .foregroundStyle(DS.textMuted)
                }
                Spacer()
                if count > 0 {
                    Text("\(count) this month")
                        .font(Typography.mono(.caption))
                        .foregroundStyle(DS.textMuted)
                }
            }
        }
        .buttonStyle(.plain)
        .hoverHighlight()
        .opacity(card.isArchived ? 0.6 : 1)
    }
}

// MARK: - Editor

struct CardEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// nil = creating a new card.
    let card: PaymentCard?

    @State private var name = ""
    @State private var abbrev = ""
    @State private var isArchived = false
    @State private var confirmingDelete = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// What the row will actually show, live as you type.
    private var previewTag: String {
        let typed = abbrev.trimmingCharacters(in: .whitespaces)
        return typed.isEmpty ? PaymentCard.suggestedAbbrev(for: name) : typed
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("e.g. Chase Sapphire"))
                        .foregroundStyle(DS.text)

                    LabeledContent("Abbreviation") {
                        TextField("", text: $abbrev, prompt: Text(PaymentCard.suggestedAbbrev(for: name)))
                            .multilineTextAlignment(.trailing)
                            .font(Typography.mono(.body, weight: .medium))
                            .foregroundStyle(DS.text)
                            #if os(iOS)
                            .textInputAutocapitalization(.characters)
                            #endif
                            .autocorrectionDisabled()
                            .onChange(of: abbrev) { _, newValue in
                                if newValue.count > PaymentCard.maxAbbrev {
                                    abbrev = String(newValue.prefix(PaymentCard.maxAbbrev))
                                }
                            }
                    }

                } footer: {
                    Text("Transactions show “\(previewTag)”. Suggested from the name — change it to anything up to \(PaymentCard.maxAbbrev) characters.")
                }
                .listRowBackground(DS.rowBackground())

                if card != nil {
                    Section {
                        Toggle("Archived", isOn: $isArchived)
                            .tint(DS.savings)
                    } footer: {
                        Text("Archiving hides the card when adding a transaction. Past transactions keep their label.")
                    }
                    .listRowBackground(DS.rowBackground())

                    Section {
                        Button("Delete Card", role: .destructive) { confirmingDelete = true }
                            .frame(maxWidth: .infinity)
                    } footer: {
                        Text("Deleting is permanent, and transactions that used this card lose their label. Archive instead if you might want it back.")
                    }
                    .listRowBackground(DS.rowBackground())
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .screenBackground()
            // Every other destructive action in the app confirms first —
            // closing a month, resetting data. This one strips the label off
            // every transaction that used the card, so it should too.
            .confirmationDialog("Delete this card?",
                                isPresented: $confirmingDelete,
                                titleVisibility: .visible) {
                Button("Delete Card", role: .destructive) { delete() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Transactions tagged with this card lose their label. Archive it instead if you might want it back.")
            }
            .navigationTitle(card == nil ? "New Card" : "Edit Card")
            #if !os(macOS)
            .toolbarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
            .onAppear(perform: load)
        }
        .tint(DS.gold)
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 360)
        #endif
    }

    private func load() {
        guard let card else { return }
        name = card.name
        abbrev = card.abbrev
        isArchived = card.isArchived
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        let trimmedAbbrev = abbrev.trimmingCharacters(in: .whitespaces)
        if let card {
            card.name = trimmedName
            card.abbrev = trimmedAbbrev
            card.isArchived = isArchived
        } else if let existing = duplicate(of: trimmedName) {
            // Re-adding a card you already have edits it instead of stacking a
            // second one — the merge pass would collapse them anyway.
            existing.abbrev = trimmedAbbrev
            existing.isArchived = false
        } else {
            context.insert(PaymentCard(name: trimmedName,
                                       abbrev: trimmedAbbrev))
        }
        dismiss()
    }

    /// An existing card with the same name, if there is one.
    private func duplicate(of name: String) -> PaymentCard? {
        let key = name.lowercased()
        return LedgerService.allCards(in: context).first {
            $0.name.trimmingCharacters(in: .whitespaces).lowercased() == key
        }
    }

    /// Transactions keep their now-unresolvable `cardID`, which simply renders
    /// as no card. Nothing cascades — that's exactly why the link is a loose id
    /// and not a SwiftData relationship.
    private func delete() {
        if let card { context.delete(card) }
        dismiss()
    }
}
