//
//  AddTransactionView.swift
//  Ledger
//
//  Native Form sheet for logging a transaction.
//

import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let month: MonthRecord

    @State private var desc = ""
    @State private var amount: Double? = nil
    @State private var category: BudgetCategory = .needs
    @State private var date = Date()

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
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(DS.background.ignoresSafeArea())
            .navigationTitle("New Transaction")
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
        }
        .tint(DS.gold)
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 320)
        #endif
    }

    private func save() {
        guard let value = amount, value > 0 else { return }
        LedgerService.addTransaction(to: month,
                                     desc: desc.trimmingCharacters(in: .whitespacesAndNewlines),
                                     amount: value,
                                     category: category,
                                     date: date,
                                     in: context)
        dismiss()
    }
}
