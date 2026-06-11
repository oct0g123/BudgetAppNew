//
//  LedgerService.swift
//  Ledger
//
//  Mutation helpers that operate on a SwiftData ModelContext. Views read data
//  reactively with @Query and call into here to make changes.
//

import Foundation
import SwiftData

enum LedgerService {

    // MARK: Settings

    /// Returns the singleton settings row, creating it if needed.
    @discardableResult
    static func settings(in context: ModelContext) -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try? context.fetch(descriptor), let first = existing.first {
            return first
        }
        let created = AppSettings()
        context.insert(created)
        return created
    }

    // MARK: Months

    static func month(forKey key: String, in context: ModelContext) -> MonthRecord? {
        let descriptor = FetchDescriptor<MonthRecord>(
            predicate: #Predicate { $0.key == key }
        )
        return try? context.fetch(descriptor).first
    }

    static func allMonths(in context: ModelContext) -> [MonthRecord] {
        let descriptor = FetchDescriptor<MonthRecord>(
            sortBy: [SortDescriptor(\.key)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Returns the month for `key`, creating it from current defaults if it
    /// doesn't exist yet. New months inherit the default income and the default
    /// split *at creation time*, then keep that split forever.
    @discardableResult
    static func ensureMonth(forKey key: String, in context: ModelContext) -> MonthRecord {
        if let existing = month(forKey: key, in: context) {
            return existing
        }
        let settings = settings(in: context)
        let record = MonthRecord(key: key,
                                 income: settings.defaultIncome,
                                 split: settings.defaultSplit)
        context.insert(record)
        applyRecurringRules(to: record, in: context)
        return record
    }

    // MARK: Recurring rules

    static func allRecurringRules(in context: ModelContext) -> [RecurringRule] {
        let descriptor = FetchDescriptor<RecurringRule>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Materialize every active rule that has reached `startKey` into the month,
    /// skipping any rule already represented there. Closed months are left
    /// untouched.
    static func applyRecurringRules(to month: MonthRecord, in context: ModelContext) {
        guard !month.isClosed else { return }
        let existingRuleIDs = Set(month.txns.compactMap { $0.recurringRuleID })
        for rule in allRecurringRules(in: context) where rule.isActive {
            guard rule.startKey <= month.key else { continue }
            guard !existingRuleIDs.contains(rule.id) else { continue }
            let txn = Transaction(desc: rule.desc,
                                  amount: rule.amount,
                                  category: rule.category,
                                  date: dateForDay(rule.dayOfMonth, inMonthKey: month.key),
                                  recurringRuleID: rule.id)
            txn.month = month
            context.insert(txn)
        }
    }

    /// Apply a rule to every existing open month it covers (used right after a
    /// rule is created or re-activated).
    static func applyRule(_ rule: RecurringRule, in context: ModelContext) {
        for month in allMonths(in: context) where !month.isClosed && rule.startKey <= month.key {
            applyRecurringRules(to: month, in: context)
        }
    }

    private static func dateForDay(_ day: Int, inMonthKey key: String) -> Date {
        guard let (year, month) = MonthKey.components(key) else { return Date() }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        let range = cal.range(of: .day, in: .month, for: cal.date(from: comps) ?? Date())
        let maxDay = range?.count ?? 28
        comps.day = min(max(day, 1), maxDay)
        return cal.date(from: comps) ?? Date()
    }

    // MARK: Transactions

    static func addTransaction(to month: MonthRecord,
                               desc: String,
                               amount: Double,
                               category: BudgetCategory,
                               date: Date,
                               in context: ModelContext) {
        let txn = Transaction(desc: desc, amount: amount, category: category, date: date)
        txn.month = month
        context.insert(txn)
    }

    static func delete(_ transaction: Transaction, in context: ModelContext) {
        context.delete(transaction)
    }

    // MARK: Close month

    static func closeMonth(_ month: MonthRecord, in context: ModelContext) {
        month.isClosed = true
        // Ensure the *next* month exists so the user lands somewhere fresh.
        let nextKey = MonthKey.offset(month.key, by: 1)
        ensureMonth(forKey: nextKey, in: context)
    }

    /// Reopen a closed month so it can be edited again.
    static func reopenMonth(_ month: MonthRecord, in context: ModelContext) {
        month.isClosed = false
    }

    // MARK: Import

    /// Merge an imported archive into the store. Existing months (matched by
    /// key) are updated in place; transactions are matched by id to avoid
    /// duplicates on repeated imports.
    static func importArchive(_ archive: ExportData, in context: ModelContext) {
        // Settings
        let settings = settings(in: context)
        settings.defaultIncome = archive.settings.defaultIncome
        settings.defaultSplit = BudgetSplit(needs: archive.settings.needsPct,
                                            savings: archive.settings.savingsPct,
                                            wants: archive.settings.wantsPct)

        for monthDTO in archive.months {
            let record: MonthRecord
            if let existing = month(forKey: monthDTO.key, in: context) {
                record = existing
            } else {
                record = MonthRecord(key: monthDTO.key,
                                     income: monthDTO.income,
                                     split: BudgetSplit(needs: monthDTO.needsPct,
                                                        savings: monthDTO.savingsPct,
                                                        wants: monthDTO.wantsPct),
                                     createdAt: monthDTO.createdAt)
                context.insert(record)
            }
            record.income = monthDTO.income
            record.needsPct = monthDTO.needsPct
            record.savingsPct = monthDTO.savingsPct
            record.wantsPct = monthDTO.wantsPct
            record.isClosed = monthDTO.isClosed

            let existingIDs = Set(record.txns.map(\.id))
            for txnDTO in monthDTO.transactions where !existingIDs.contains(txnDTO.id) {
                let txn = Transaction(id: txnDTO.id,
                                      desc: txnDTO.desc,
                                      amount: txnDTO.amount,
                                      category: BudgetCategory(rawValue: txnDTO.category) ?? .needs,
                                      date: txnDTO.date)
                txn.month = record
                context.insert(txn)
            }
        }

        // Recurring rules (match by id to avoid duplicates).
        let existingRuleIDs = Set(allRecurringRules(in: context).map(\.id))
        for ruleDTO in (archive.rules ?? []) where !existingRuleIDs.contains(ruleDTO.id) {
            let rule = RecurringRule(id: ruleDTO.id,
                                     desc: ruleDTO.desc,
                                     amount: ruleDTO.amount,
                                     category: BudgetCategory(rawValue: ruleDTO.category) ?? .needs,
                                     dayOfMonth: ruleDTO.dayOfMonth,
                                     isActive: ruleDTO.isActive,
                                     startKey: ruleDTO.startKey)
            context.insert(rule)
        }
    }

    /// Import flat CSV transaction rows, creating months as needed.
    static func importCSVTransactions(_ buckets: [String: [TransactionDTO]],
                                      in context: ModelContext) {
        for (key, txns) in buckets {
            let record = ensureMonth(forKey: key, in: context)
            let existingIDs = Set(record.txns.map(\.id))
            for dto in txns where !existingIDs.contains(dto.id) {
                let txn = Transaction(id: dto.id,
                                      desc: dto.desc,
                                      amount: dto.amount,
                                      category: BudgetCategory(rawValue: dto.category) ?? .needs,
                                      date: dto.date)
                txn.month = record
                context.insert(txn)
            }
        }
    }
}
