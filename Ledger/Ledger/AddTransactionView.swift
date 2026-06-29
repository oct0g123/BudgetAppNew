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
                }
                .listRowBackground(DS.surface)

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
                .listRowBackground(DS.surface)

                if isEditing {
                    Section {
                        Button("Delete Transaction", role: .destructive) { delete() }
                            .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(DS.surface)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(DS.background.ignoresSafeArea())
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
    }

    private func save() {
        guard let value = amount, value > 0 else { return }
        let trimmed = desc.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing {
            existing.desc = trimmed
            existing.amount = value
            existing.category = category
            existing.date = date
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
            if makeRecurring {
                // Create the rule, then add this month's occurrence tagged with
                // the rule id so applyRule won't double-add it for this month.
                let rule = RecurringRule(desc: trimmed,
                                         amount: value,
                                         category: category,
                                         dayOfMonth: dayOfMonth(from: date),
                                         startKey: month.key)
                context.insert(rule)
                let txn = Transaction(desc: trimmed,
                                      amount: value,
                                      category: category,
                                      date: date,
                                      recurringRuleID: rule.id)
                txn.month = month
                context.insert(txn)
                LedgerService.applyRule(rule, in: context)
            } else {
                LedgerService.addTransaction(to: month,
                                             desc: trimmed,
                                             amount: value,
                                             category: category,
                                             date: date,
                                             in: context)
            }
        }
        BudgetAlerts.evaluate(existing?.month ?? month)
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
