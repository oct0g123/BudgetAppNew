//
//  Models.swift
//  Ledger
//
//  SwiftData models. Everything is CloudKit-compatible:
//   - every stored property has a default value
//   - relationships are optional
//   - no `.unique` attributes (CloudKit forbids them; uniqueness is
//     enforced in code instead)
//

import Foundation
import SwiftData

// MARK: - Category

/// The three 50/30/20 buckets. Stored as a raw String on Transaction so the
/// model stays trivially CloudKit-compatible.
enum BudgetCategory: String, CaseIterable, Identifiable, Codable {
    case needs
    case savings
    case wants

    var id: String { rawValue }

    var title: String {
        switch self {
        case .needs:   return "Needs"
        case .savings: return "Savings"
        case .wants:   return "Wants"
        }
    }
}

// MARK: - Transaction

@Model
final class Transaction {
    var id: UUID = UUID()
    var desc: String = ""
    var amount: Double = 0
    /// Raw value of `BudgetCategory`.
    var categoryRaw: String = BudgetCategory.needs.rawValue
    var date: Date = Date()

    /// Optional free-text memo ("split with Kate", "reimbursable"). Defaulted
    /// rather than optional so CloudKit is happy and no call site deals with
    /// nil — an empty string means "no memo". NOT named `note`: the command
    /// bar's parsed draft already uses `note` for the *description*.
    var memo: String = ""

    /// Which `PaymentCard` paid for this, if any. A loose id rather than a
    /// SwiftData relationship, mirroring `recurringRuleID`: a relationship with
    /// the wrong delete rule could cascade-delete transactions when a card is
    /// removed. An unresolvable id simply renders as no card.
    var cardID: UUID?

    /// Set when this transaction was generated from a recurring rule, so the
    /// same rule isn't applied to the same month twice.
    var recurringRuleID: UUID?

    /// Owning month. Optional for CloudKit.
    var month: MonthRecord?

    init(id: UUID = UUID(),
         desc: String,
         amount: Double,
         category: BudgetCategory,
         date: Date = Date(),
         memo: String = "",
         cardID: UUID? = nil,
         recurringRuleID: UUID? = nil) {
        self.id = id
        self.desc = desc
        self.amount = amount
        self.categoryRaw = category.rawValue
        self.date = date
        self.memo = memo
        self.cardID = cardID
        self.recurringRuleID = recurringRuleID
    }

    var category: BudgetCategory {
        get { BudgetCategory(rawValue: categoryRaw) ?? .needs }
        set { categoryRaw = newValue.rawValue }
    }
}

// MARK: - MonthRecord

/// A single budget month. The allocation split (needs/savings/wants %) is
/// stored *per month* so historical months keep whatever split was active
/// when they were created, even if the user later changes their default.
@Model
final class MonthRecord {
    /// 1-indexed, human-readable key: "2026-05" == May 2026.
    var key: String = ""
    var income: Double = 0

    var needsPct: Double = 50
    var savingsPct: Double = 20
    var wantsPct: Double = 30

    var isClosed: Bool = false
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Transaction.month)
    var transactions: [Transaction]? = []

    init(key: String,
         income: Double,
         split: BudgetSplit,
         createdAt: Date = Date()) {
        self.key = key
        self.income = income
        self.needsPct = split.needs
        self.savingsPct = split.savings
        self.wantsPct = split.wants
        self.createdAt = createdAt
    }

    var split: BudgetSplit {
        BudgetSplit(needs: needsPct, savings: savingsPct, wants: wantsPct)
    }

    var txns: [Transaction] { transactions ?? [] }

    // MARK: Derived figures

    func budget(for category: BudgetCategory) -> Double {
        income * split.fraction(for: category)
    }

    func spent(for category: BudgetCategory) -> Double {
        txns.filter { $0.category == category }
            .reduce(0) { $0 + $1.amount }
    }

    func remaining(for category: BudgetCategory) -> Double {
        budget(for: category) - spent(for: category)
    }

    var totalSpent: Double {
        txns.reduce(0) { $0 + $1.amount }
    }

    /// Share of income routed into the Savings bucket.
    var savingsRate: Double {
        guard income > 0 else { return 0 }
        return spent(for: .savings) / income
    }

    /// How much can still be spent this month while keeping the savings goal
    /// intact — what's left in the Needs and Wants buckets. Savings is treated
    /// as set aside, so unmet savings is never counted as "spendable." Can go
    /// negative if Needs + Wants are already over budget.
    var safeToSpend: Double {
        remaining(for: .needs) + remaining(for: .wants)
    }

    /// This week's allowance for `category`, anchored at the START of the week.
    ///
    /// The anchor is `remaining + spentThisWeek` — what was left when the week
    /// began. That sum is invariant to spending *inside* the week (spend $50
    /// and `remaining` drops 50 while `spentThisWeek` rises 50), so `budget`
    /// holds steady all week and only `left` drains. A naive
    /// `remaining ÷ weeks-left` would re-baseline itself on every purchase and
    /// could never visibly empty — which is the whole point of the number.
    ///
    /// It's the same even-pace math as the `$X/wk` label on the bucket rows,
    /// just anchored at the week's start instead of today, so the two agree.
    /// Nil for anything but the live, open month — a "this week" figure is
    /// meaningless while browsing history.
    func weekSpending(for category: BudgetCategory, now: Date = Date())
        -> (budget: Double, spent: Double, left: Double)? {
        guard key == MonthKey.current, !isClosed,
              let window = MonthKey.weekWindow(inMonth: key, from: now) else { return nil }
        let spentThisWeek = txns
            .filter { $0.category == category && $0.date >= window.start && $0.date < window.end }
            .reduce(0) { $0 + $1.amount }
        let anchor = remaining(for: category) + spentThisWeek
        let budget = anchor / Double(window.daysToMonthEnd) * Double(window.days)
        return (budget, spentThisWeek, budget - spentThisWeek)
    }
}

// MARK: - PaymentCard

/// A card the user types in by hand. Ledger never connects to an account and
/// never tracks balances — this is a LABEL on a transaction, nothing more, and
/// it has no effect on budgets or the 50/30/20 math.
@Model
final class PaymentCard {
    var id: UUID = UUID()
    var name: String = ""
    /// Short tag shown on each transaction row, e.g. "CSP". Capped in the
    /// editor so a long one can't crowd the row.
    var abbrev: String = ""
    /// Archived cards drop out of the picker but still resolve for history, so
    /// past transactions never silently lose their label.
    var isArchived: Bool = false
    var createdAt: Date = Date()

    init(id: UUID = UUID(),
         name: String,
         abbrev: String = "",
         isArchived: Bool = false,
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        // Clamped here, not only in the editor, so an over-long abbreviation
        // from an imported backup can't push the amount off a transaction row
        // (the chip is `.fixedSize()`).
        self.abbrev = String(abbrev.prefix(Self.maxAbbrev))
        self.isArchived = isArchived
        self.createdAt = createdAt
    }

    /// What actually appears on a transaction row.
    var tag: String {
        abbrev.isEmpty ? Self.suggestedAbbrev(for: name) : abbrev
    }

    /// "Chase Sapphire" → "CS". A suggestion only — always editable, because a
    /// generated label the user can't override is worse than no label.
    static func suggestedAbbrev(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let initials = trimmed.split(separator: " ").prefix(3).compactMap(\.first)
        if initials.isEmpty { return String(trimmed.prefix(3)).uppercased() }
        return String(String(initials).uppercased().prefix(maxAbbrev))
    }

    static let maxAbbrev = 6

    /// Collapses same-id repeats that iCloud can briefly produce, so a list
    /// never hands SwiftUI's `ForEach` two rows with the same identity while
    /// the next merge pass is still pending.
    static func uniqued(_ cards: [PaymentCard]) -> [PaymentCard] {
        var seen = Set<UUID>()
        return cards.filter { seen.insert($0.id).inserted }
    }
}

// MARK: - RecurringRule

/// A monthly recurring transaction template (rent, subscriptions, paychecks
/// logged as negative spend, etc.). When a month is opened, active rules whose
/// `startKey` has been reached are materialized into real `Transaction`s for
/// that month — once each, tracked via `Transaction.recurringRuleID`.
@Model
final class RecurringRule {
    var id: UUID = UUID()
    var desc: String = ""
    var amount: Double = 0
    var categoryRaw: String = BudgetCategory.needs.rawValue
    /// Day of month to date the generated transaction (clamped to the month).
    var dayOfMonth: Int = 1
    var isActive: Bool = true
    /// First month the rule applies, e.g. "2026-06".
    var startKey: String = ""
    /// LAST month the rule applies (inclusive), e.g. "2026-08" — nil means it
    /// runs until switched off.
    ///
    /// Stored as a month rather than a "3 payments left" counter on purpose. A
    /// counter has to be decremented as months materialize, and with CloudKit
    /// two devices can materialize the same month before syncing — each would
    /// decrement, or a conflict would drop one. An end month is idempotent:
    /// every device derives the same answer from the same data, which is the
    /// rule the rest of the merge system follows.
    var endKey: String?
    var createdAt: Date = Date()

    init(id: UUID = UUID(),
         desc: String,
         amount: Double,
         category: BudgetCategory,
         dayOfMonth: Int = 1,
         isActive: Bool = true,
         startKey: String,
         endKey: String? = nil) {
        self.id = id
        self.desc = desc
        self.amount = amount
        self.categoryRaw = category.rawValue
        self.dayOfMonth = dayOfMonth
        self.isActive = isActive
        self.startKey = startKey
        self.endKey = endKey
    }

    /// Whether this rule should charge in `monthKey`. One definition, so the
    /// two places that materialize rules can't drift apart.
    func covers(_ monthKey: String) -> Bool {
        guard startKey <= monthKey else { return false }
        guard let endKey else { return true }      // open-ended
        return monthKey <= endKey
    }

    /// The end month has passed: the rule will never charge again, even though
    /// it may still be `isActive`. Kept separate from `isActive` — "finished"
    /// and "paused" are different things and the row says which.
    var hasFinished: Bool {
        guard let endKey else { return false }
        return endKey < MonthKey.current
    }

    /// Total number of charges when limited, for the editor's stepper.
    var monthCount: Int? {
        guard let endKey else { return nil }
        return max(MonthKey.monthsBetween(startKey, endKey) + 1, 1)
    }

    var category: BudgetCategory {
        get { BudgetCategory(rawValue: categoryRaw) ?? .needs }
        set { categoryRaw = newValue.rawValue }
    }
}

// MARK: - BudgetSplit

/// A needs/savings/wants allocation expressed as whole-number percentages that
/// sum to 100.
struct BudgetSplit: Equatable, Codable {
    var needs: Double
    var savings: Double
    var wants: Double

    static let balanced     = BudgetSplit(needs: 50, savings: 20, wants: 30) // 50/30/20 classic
    static let aggressive   = BudgetSplit(needs: 50, savings: 30, wants: 20) // save more

    var total: Double { needs + savings + wants }
    var isValid: Bool { abs(total - 100) < 0.01 }

    func fraction(for category: BudgetCategory) -> Double {
        switch category {
        case .needs:   return needs / 100
        case .savings: return savings / 100
        case .wants:   return wants / 100
        }
    }
}

// MARK: - AppSettings

/// App-wide preferences. Treated as a singleton (first row wins).
@Model
final class AppSettings {
    var defaultIncome: Double = 0
    var defaultNeedsPct: Double = 50
    var defaultSavingsPct: Double = 20
    var defaultWantsPct: Double = 30

    init(defaultIncome: Double = 0, split: BudgetSplit = .balanced) {
        self.defaultIncome = defaultIncome
        self.defaultNeedsPct = split.needs
        self.defaultSavingsPct = split.savings
        self.defaultWantsPct = split.wants
    }

    var defaultSplit: BudgetSplit {
        get { BudgetSplit(needs: defaultNeedsPct, savings: defaultSavingsPct, wants: defaultWantsPct) }
        set {
            defaultNeedsPct = newValue.needs
            defaultSavingsPct = newValue.savings
            defaultWantsPct = newValue.wants
        }
    }
}
