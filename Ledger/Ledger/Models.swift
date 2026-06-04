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
         recurringRuleID: UUID? = nil) {
        self.id = id
        self.desc = desc
        self.amount = amount
        self.categoryRaw = category.rawValue
        self.date = date
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
    var createdAt: Date = Date()

    init(id: UUID = UUID(),
         desc: String,
         amount: Double,
         category: BudgetCategory,
         dayOfMonth: Int = 1,
         isActive: Bool = true,
         startKey: String) {
        self.id = id
        self.desc = desc
        self.amount = amount
        self.categoryRaw = category.rawValue
        self.dayOfMonth = dayOfMonth
        self.isActive = isActive
        self.startKey = startKey
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
