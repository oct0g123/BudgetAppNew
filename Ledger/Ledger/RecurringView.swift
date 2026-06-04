//
//  RecurringView.swift
//  Ledger
//
//  Manage monthly recurring transactions (rent, subscriptions, paychecks…).
//  Active rules are materialized into each month as it's opened.
//

import SwiftUI
import SwiftData

struct RecurringView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RecurringRule.createdAt) private var rules: [RecurringRule]

    @State private var editing: RecurringRule?
    @State private var showingNew = false

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Active rules are added to each new month automatically. Editing or removing a rule does not change months you've already closed.")
                        .font(.system(.caption))
                        .foregroundStyle(Palette.textMuted)

                    if rules.isEmpty {
                        Card {
                            Text("No recurring transactions yet.")
                                .font(.system(.subheadline))
                                .foregroundStyle(Palette.textMuted)
                        }
                    } else {
                        ForEach(rules) { rule in
                            ruleCard(rule)
                        }
                    }

                    Button { showingNew = true } label: {
                        Label("Add Recurring", systemImage: "plus")
                            .font(.system(.body, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Palette.gold)
                            .foregroundStyle(Palette.background)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
        }
        .navigationTitle("Recurring")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingNew) {
            RecurringEditor(rule: nil).preferredColorScheme(.dark)
        }
        .sheet(item: $editing) { rule in
            RecurringEditor(rule: rule).preferredColorScheme(.dark)
        }
    }

    private func ruleCard(_ rule: RecurringRule) -> some View {
        Card {
            HStack(spacing: 12) {
                Circle().fill(Palette.color(for: rule.category)).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 3) {
                    Text(rule.desc.isEmpty ? rule.category.title : rule.desc)
                        .font(.system(.body))
                        .foregroundStyle(Palette.text)
                    Text("Day \(rule.dayOfMonth) · " + rule.category.title + " · from " + MonthKey.shortMonthName(rule.startKey))
                        .font(.mono(11))
                        .foregroundStyle(Palette.textMuted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(Money.string(rule.amount))
                        .font(.mono(15, weight: .medium))
                        .foregroundStyle(Palette.text)
                    Toggle("", isOn: Binding(
                        get: { rule.isActive },
                        set: { newValue in
                            rule.isActive = newValue
                            if newValue { LedgerService.applyRule(rule, in: context) }
                        }))
                    .labelsHidden()
                    .tint(Palette.savings)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { editing = rule }
            .contextMenu {
                Button { editing = rule } label: { Label("Edit", systemImage: "pencil") }
                Button(role: .destructive) {
                    context.delete(rule)
                } label: { Label("Delete", systemImage: "trash") }
            }
        }
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
    @State private var amount = ""
    @State private var category: BudgetCategory = .needs
    @State private var day = 1

    private var amountValue: Double? {
        let cleaned = amount.replacingOccurrences(of: ",", with: ".")
        guard let v = Double(cleaned), v > 0 else { return nil }
        return v
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        labeled("Description") {
                            TextField("e.g. Rent", text: $desc)
                                .textFieldStyle(.plain)
                                .foregroundStyle(Palette.text)
                        }
                        labeled("Amount") {
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
                                    Button { category = cat } label: {
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
                        labeled("Day of Month") {
                            Stepper(value: $day, in: 1...28) {
                                Text("Day \(day)")
                                    .font(.mono(15))
                                    .foregroundStyle(Palette.text)
                            }
                            .tint(Palette.gold)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(rule == nil ? "New Recurring" : "Edit Recurring")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Palette.textMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .foregroundStyle(amountValue == nil ? Palette.textMuted : Palette.gold)
                        .disabled(amountValue == nil)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func labeled<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
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

    private func load() {
        guard let rule else { return }
        desc = rule.desc
        amount = String(format: "%.2f", rule.amount)
        category = rule.category
        day = rule.dayOfMonth
    }

    private func save() {
        guard let value = amountValue else { return }
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
