//
//  AddTransactionView.swift
//  Ledger
//

import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let month: MonthRecord

    @State private var desc = ""
    @State private var amount = ""
    @State private var category: BudgetCategory = .needs
    @State private var date = Date()

    private var amountValue: Double? {
        let cleaned = amount.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value > 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        field(label: "Description") {
                            TextField("e.g. Groceries", text: $desc)
                                .textFieldStyle(.plain)
                                .font(.system(.body))
                                .foregroundStyle(Palette.text)
                        }

                        field(label: "Amount") {
                            TextField("0.00", text: $amount)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                .textFieldStyle(.plain)
                                .font(.mono(20, weight: .medium))
                                .foregroundStyle(Palette.text)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel("Category")
                            HStack(spacing: 8) {
                                ForEach(BudgetCategory.allCases) { cat in
                                    Button {
                                        category = cat
                                    } label: {
                                        Text(cat.title)
                                            .font(.mono(13, weight: .medium))
                                            .foregroundStyle(category == cat ? Palette.background : Palette.text)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(category == cat ? Palette.color(for: cat) : Palette.surface)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(category == cat ? .clear : Palette.hairline, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        field(label: "Date") {
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .labelsHidden()
                                .tint(Palette.gold)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New Transaction")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Palette.textMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .foregroundStyle(amountValue == nil ? Palette.textMuted : Palette.gold)
                        .disabled(amountValue == nil)
                }
            }
        }
    }

    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(label)
            content()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Palette.hairline, lineWidth: 1))
        }
    }

    private func save() {
        guard let value = amountValue else { return }
        LedgerService.addTransaction(to: month,
                                     desc: desc.trimmingCharacters(in: .whitespacesAndNewlines),
                                     amount: value,
                                     category: category,
                                     date: date,
                                     in: context)
        dismiss()
    }
}
