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
        return record
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
