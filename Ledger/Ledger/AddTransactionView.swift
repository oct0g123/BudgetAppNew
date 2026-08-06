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

    /// Target month for a NEW transaction. Ignored when editing.
    var month: MonthRecord? = nil
    /// When set, the sheet edits this transaction instead of creating one.
    var existing: Transaction? = nil

    @State private var desc = ""
    @State private var amount: Double? = nil
    @State private var category: BudgetCategory = .needs
    @State private var date = Date()
    @State private var memo = ""
    @State private var makeRecurring = false
    @State private var saveCount = 0

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

                    // Optional memo. Grows to a few lines only if you write
                    // more, so the sheet's height is unchanged when unused.
                    TextField("Note",
                              text: $memo,
                              prompt: Text("Note (optional)"),
                              axis: .vertical)
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
        .frame(minWidth: 400, minHeight: 320)
        #endif
    }

    private func load() {
        guard let existing else { return }
        desc = existing.desc
        amount = existing.amount
        category = existing.category
        date = existing.date
        memo = existing.memo
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
                                         startKey: target.key)
                context.insert(rule)
                let txn = Transaction(desc: trimmed,
                                      amount: value,
                                      category: category,
                                      date: date,
                                      memo: trimmedMemo,
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
