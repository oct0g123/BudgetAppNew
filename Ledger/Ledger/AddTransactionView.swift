//
//  AddTransactionView.swift
//  Ledger
//
//  Native Form sheet for logging a transaction — also used to edit an existing
//  one (pass `existing`).
//

import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PaymentCard.createdAt) private var cards: [PaymentCard]

    /// Target month for a NEW transaction. Ignored when editing.
    var month: MonthRecord? = nil
    /// When set, the sheet edits this transaction instead of creating one.
    var existing: Transaction? = nil

    @State private var desc = ""
    @State private var amount: Double? = nil
    @State private var category: BudgetCategory = .needs
    @State private var date = Date()
    @State private var memo = ""
    @State private var cardID: UUID?
    @State private var makeRecurring = false
    @State private var recurringIsLimited = false
    @State private var recurringMonths = 3
    @State private var saveCount = 0

    /// Archived cards stay selectable only if this transaction already uses
    /// one, so editing an old transaction never silently drops its card.
    private var pickableCards: [PaymentCard] {
        PaymentCard.uniqued(cards).filter { !$0.isArchived || $0.id == cardID }
    }

    /// Same label/placeholder duplication as the money field: on macOS "Note"
    /// is already the row's label, so the prompt mustn't repeat it.
    private var notePrompt: Text {
        #if os(macOS)
        Text("Optional")
        #else
        Text("Note (optional)")
        #endif
    }

    /// The rule's last month, or nil for open-ended. A NEW rule always starts in
    /// the month the transaction lands in, so counting from there is already
    /// "from now" — none of the past-anchoring trouble the editor has to guard
    /// against applies here.
    private func recurringEndKey(startingAt startKey: String) -> String? {
        guard makeRecurring, recurringIsLimited else { return nil }
        return MonthKey.offset(startKey, by: recurringMonths - 1)
    }

    private var recurringFooter: String {
        let startKey = MonthKey.key(for: date)
        guard let end = recurringEndKey(startingAt: startKey) else {
            return "Repeats every month until you turn it off in Settings → Recurring."
        }
        let times = recurringMonths == 1 ? "once" : "\(recurringMonths) times"
        return "Charges \(times) — \(MonthKey.displayName(startKey)) through \(MonthKey.displayName(end))."
    }

    private var isEditing: Bool { existing != nil }
    private var isValid: Bool { (amount ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Description", text: $desc, prompt: Text("e.g. Groceries"))
                        .foregroundStyle(DS.text)
                    MoneyField(placeholder: "Amount",
                               amount: Binding(get: { amount ?? 0 }, set: { amount = $0 }))
                        .font(Typography.mono(.body, weight: .medium))
                        .foregroundStyle(DS.text)
                } footer: {
                    // Explains the ⟳ marker on the row you tapped in.
                    if existing?.recurringRuleID != nil {
                        Label("From a recurring rule. Changes here affect only this month's charge.",
                              systemImage: "repeat")
                            .font(.caption)
                            .foregroundStyle(DS.textMuted)
                    }
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

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .foregroundStyle(DS.text)

                    // Optional. Hidden entirely until at least one card exists,
                    // so the sheet is unchanged for anyone not using them.
                    if !pickableCards.isEmpty {
                        Picker("Card", selection: $cardID) {
                            Text("None").tag(UUID?.none)
                            ForEach(pickableCards) { card in
                                Text(card.name).tag(UUID?.some(card.id))
                            }
                        }
                        .tint(DS.textMuted)
                    }

                    // Optional memo. Grows to a few lines only if you write
                    // more, so the sheet's height is unchanged when unused.
                    TextField("Note", text: $memo, prompt: notePrompt, axis: .vertical)
                        .lineLimit(1...3)
                        .foregroundStyle(DS.text)

                    if !isEditing {
                        Toggle(isOn: $makeRecurring) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Repeat monthly")
                                Text("Also save as a recurring rule")
                                    .font(.caption)
                                    .foregroundStyle(DS.textMuted)
                            }
                        }
                        .tint(DS.savings)

                        // Only once "Repeat monthly" is on — an installment plan
                        // is decided when you log the charge, not on a later trip
                        // to Settings. Nothing shows until it's relevant.
                        if makeRecurring {
                            Toggle("Ends after a set number of months",
                                   isOn: $recurringIsLimited)
                                .tint(DS.savings)

                            if recurringIsLimited {
                                Stepper(value: $recurringMonths, in: 1...60) {
                                    LabeledContent("Number of months") {
                                        Text("\(recurringMonths)")
                                            .font(Typography.mono(.body, weight: .medium))
                                            .foregroundStyle(DS.text)
                                    }
                                }
                            }
                        }
                    }
                } footer: {
                    if makeRecurring {
                        Text(recurringFooter)
                    }
                }
                .listRowBackground(DS.rowBackground())

                if isEditing {
                    Section {
                        Button("Delete Transaction", role: .destructive) { delete() }
                            .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(DS.rowBackground())
                }
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
            .navigationTitle(isEditing ? "Edit Transaction" : "New Transaction")
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
        .sensoryFeedback(.success, trigger: saveCount)
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 470)
        #endif
    }

    private func load() {
        guard let existing else { return }
        desc = existing.desc
        amount = existing.amount
        category = existing.category
        date = existing.date
        memo = existing.memo
        cardID = existing.cardID
    }

    private func save() {
        guard let value = amount, value > 0 else { return }
        let trimmed = desc.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMemo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing {
            existing.desc = trimmed
            existing.amount = value
            existing.category = category
            existing.date = date
            existing.memo = trimmedMemo
            existing.cardID = cardID
            // If the edited date moved into a different month, re-home the
            // transaction so it's counted under the month it now belongs to —
            // totals are computed per MonthRecord, so leaving the old `month`
            // relationship intact would keep it counted under the original month.
            let newKey = MonthKey.key(for: date)
            if existing.month?.key != newKey {
                let previousMonth = existing.month
                existing.month = LedgerService.ensureMonth(forKey: newKey, in: context)
                if let previousMonth { BudgetAlerts.evaluate(previousMonth) }
            }
        } else if let month {
            // Place the transaction in the month its DATE belongs to, not
            // blindly in the sheet's month (mirrors the edit path's re-home).
            // If the date's month is closed, fall back to the sheet's open
            // month rather than filing into a closed month the UI hides.
            let dateKey = MonthKey.key(for: date)
            var target = month
            if dateKey != month.key {
                let dated = LedgerService.ensureMonth(forKey: dateKey, in: context)
                if !dated.isClosed { target = dated }
            }
            if makeRecurring {
                // Create the rule, then add this month's occurrence tagged with
                // the rule id so applyRule won't double-add it for this month.
                let rule = RecurringRule(desc: trimmed,
                                         amount: value,
                                         category: category,
                                         dayOfMonth: dayOfMonth(from: date),
                                         startKey: target.key,
                                         endKey: recurringEndKey(startingAt: target.key))
                context.insert(rule)
                let txn = Transaction(desc: trimmed,
                                      amount: value,
                                      category: category,
                                      date: date,
                                      memo: trimmedMemo,
                                      cardID: cardID,
                                      recurringRuleID: rule.id)
                txn.month = target
                context.insert(txn)
                LedgerService.applyRule(rule, in: context)
            } else {
                LedgerService.addTransaction(to: target,
                                             desc: trimmed,
                                             amount: value,
                                             category: category,
                                             date: date,
                                             memo: trimmedMemo,
                                             cardID: cardID,
                                             in: context)
            }
            BudgetAlerts.evaluate(target)
        }
        if let existing { BudgetAlerts.evaluate(existing.month) }
        saveCount += 1
        dismiss()
    }

    /// Day-of-month for a recurring rule, clamped to 1...28 so it exists in
    /// every month.
    private func dayOfMonth(from date: Date) -> Int {
        let day = Calendar.current.component(.day, from: date)
        return min(max(day, 1), 28)
    }

    private func delete() {
        if let existing {
            LedgerService.delete(existing, in: context)
        }
        dismiss()
    }
}
