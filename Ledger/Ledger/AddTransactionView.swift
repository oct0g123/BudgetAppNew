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
    @State private var saveCount = 0

    private var isEditing: Bool { existing != nil }
    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }
    private var isValid: Bool { (amount ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Description", text: $desc, prompt: Text("e.g. Groceries"))
                        .foregroundStyle(DS.text)
                    TextField("Amount", value: $amount,
                              format: .currency(code: currencyCode),
                              prompt: Text("Amount"))
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
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
        } else if let month {
            LedgerService.addTransaction(to: month,
                                         desc: trimmed,
                                         amount: value,
                                         category: category,
                                         date: date,
                                         in: context)
        }
        saveCount += 1
        dismiss()
    }

    private func delete() {
        if let existing {
            LedgerService.delete(existing, in: context)
        }
        dismiss()
    }
}
