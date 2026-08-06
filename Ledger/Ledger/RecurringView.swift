//
//  RecurringView.swift
//  Ledger
//
//  Manage monthly recurring transactions (rent, subscriptions, paychecks…) on
//  a native List: tap to edit, swipe to delete, toggle to pause.
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
                        Text("Active rules are added to each new month automatically. Edits update this month's copy too; closed months are never changed.")
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
                        Text("Day \(rule.dayOfMonth) · \(rule.category.title) · from \(MonthKey.shortMonthName(rule.startKey))")
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
        .opacity(rule.isActive ? 1 : 0.6)
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

    private var isValid: Bool { (amount ?? 0) > 0 }

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
        .frame(minWidth: 400, minHeight: 340)
        #endif
    }

    private func load() {
        guard let rule else { return }
        desc = rule.desc
        amount = rule.amount
        category = rule.category
        day = rule.dayOfMonth
    }

    private func save() {
        guard let value = amount, value > 0 else { return }
        let trimmed = desc.trimmingCharacters(in: .whitespacesAndNewlines)
        if let rule {
            rule.desc = trimmed
            rule.amount = value
            rule.category = category
            rule.dayOfMonth = day
            LedgerService.applyRule(rule, in: context)
        } else {
            let newRule = RecurringRule(desc: trimmed,
                                        amount: value,
                                        category: category,
                                        dayOfMonth: day,
                                        startKey: viewedKey)
            context.insert(newRule)
            LedgerService.applyRule(newRule, in: context)
        }
        dismiss()
    }
}
