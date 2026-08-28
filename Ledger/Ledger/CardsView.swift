//
//  CardsView.swift
//  Ledger
//
//  Manage payment cards — typed in by hand, never connected to an account.
//  A card is a LABEL on a transaction: it has no balance, no statement period,
//  and no effect on budgets or the 50/30/20 math. Structurally a twin of
//  RecurringView (list + editor sheet), because that shape already works.
//

import SwiftUI
import SwiftData

struct CardsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PaymentCard.createdAt) private var cards: [PaymentCard]
    @Query private var months: [MonthRecord]

    @State private var editing: PaymentCard?
    @State private var showingNew = false

    private var active: [PaymentCard] { cards.filter { !$0.isArchived } }
    private var archived: [PaymentCard] { cards.filter(\.isArchived) }

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
                    Text(card.last4.isEmpty ? card.tag : "\(card.tag) · •\(card.last4)")
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
    @State private var last4 = ""
    @State private var isArchived = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// What the row will actually show, live as you type.
    private var previewTag: String {
        let typed = abbrev.trimmingCharacters(in: .whitespaces)
        if !typed.isEmpty { return typed }
        if !last4.isEmpty { return "•" + last4 }
        return PaymentCard.suggestedAbbrev(for: name)
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

                    LabeledContent("Last 4 digits") {
                        TextField("", text: $last4, prompt: Text("optional"))
                            .multilineTextAlignment(.trailing)
                            .font(Typography.mono(.body, weight: .medium))
                            .foregroundStyle(DS.text)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                            .onChange(of: last4) { _, newValue in
                                let digits = newValue.filter(\.isNumber)
                                if digits != newValue || digits.count > 4 {
                                    last4 = String(digits.prefix(4))
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
                        Button("Delete Card", role: .destructive) { delete() }
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
            // The last-4 field uses a number pad, which has no Return key.
            #if !os(visionOS)
            .scrollDismissesKeyboard(.immediately)
            #endif
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
        .frame(minWidth: 400, minHeight: 320)
        #endif
    }

    private func load() {
        guard let card else { return }
        name = card.name
        abbrev = card.abbrev
        last4 = card.last4
        isArchived = card.isArchived
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        let trimmedAbbrev = abbrev.trimmingCharacters(in: .whitespaces)
        if let card {
            card.name = trimmedName
            card.abbrev = trimmedAbbrev
            card.last4 = last4
            card.isArchived = isArchived
        } else {
            context.insert(PaymentCard(name: trimmedName,
                                       abbrev: trimmedAbbrev,
                                       last4: last4))
        }
        dismiss()
    }

    /// Transactions keep their now-unresolvable `cardID`, which simply renders
    /// as no card. Nothing cascades — that's exactly why the link is a loose id
    /// and not a SwiftData relationship.
    private func delete() {
        if let card { context.delete(card) }
        dismiss()
    }
}
