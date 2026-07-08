//
//  LedgerService.swift
//  Ledger
//
//  Mutation helpers that operate on a SwiftData ModelContext. Views read data
//  reactively with @Query and call into here to make changes.
//

import Foundation
import SwiftData
import WidgetKit
import AppIntents
import UserNotifications
#if canImport(FoundationModels)
import FoundationModels
#endif

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
        // If a sync race ever deleted every settings row, restore the user's
        // income/split from the local cache rather than resetting to zeros.
        SettingsBackup.restore(into: created)
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
            // Deterministic id: two devices that each materialize this rule into
            // this month (e.g. both open the app on the 1st before syncing)
            // produce the SAME transaction id, so id-dedupe collapses the pair
            // instead of leaving a permanent double charge.
            let txn = Transaction(id: LedgerArchive.deterministicUUID(
                                      "recurring|\(rule.id.uuidString)|\(month.key)"),
                                  desc: rule.desc,
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
        BudgetAlerts.evaluate(month)
    }

    static func delete(_ transaction: Transaction, in context: ModelContext) {
        let month = transaction.month
        context.delete(transaction)
        BudgetAlerts.evaluate(month)   // re-arm thresholds when spend drops
    }

    // MARK: Deduplication
    //
    // With iCloud sync, two devices can independently create "singleton-ish"
    // records before they've synced — most commonly the current month (each
    // device makes its own on first launch) and the settings row. This
    // consolidates the duplicates. Design rules, learned the hard way:
    //
    //  1. Every choice is DETERMINISTIC from synced fields only, so all
    //     devices converge on the same survivor instead of each deleting the
    //     other's copy (which syncs both deletions and loses the record).
    //  2. Duplicate MONTHS are never deleted immediately. Deleting a month
    //     cascades to its transactions — and a deletion that syncs to a device
    //     whose transactions haven't uploaded yet would cascade-wipe them.
    //     Instead: reparent transactions to the canonical month every pass,
    //     and only delete a duplicate after it has been observed empty for a
    //     grace period (late-arriving remote transactions get reparented on a
    //     later pass and reset the clock). Views always display the canonical
    //     copy (see `canonical(_:key:)`), so a lingering empty duplicate is
    //     invisible while it waits.
    //  3. A cheap precheck (ids only, no relationship faulting) skips the
    //     whole pass when there's nothing to merge — this runs on every
    //     activation, so the common case must cost ~nothing.

    static func mergeDuplicates(in context: ModelContext) {
        guard needsMerge(in: context) else {
            // Keep the local settings cache warm even when nothing merges.
            if let s = try? context.fetch(FetchDescriptor<AppSettings>()).first {
                SettingsBackup.save(s)
            }
            return
        }
        mergeDuplicateSettings(in: context)
        mergeDuplicateMonths(in: context)
        for month in allMonths(in: context) {
            dedupeTransactions(in: month, context: context)
        }
        dedupeRecurringRules(in: context)
        try? context.save()
    }

    /// Ids-only duplicate scan — no relationship faulting, so it's cheap enough
    /// to run on every scene activation and CloudKit import batch.
    private static func needsMerge(in context: ModelContext) -> Bool {
        let settingsCount = (try? context.fetchCount(FetchDescriptor<AppSettings>())) ?? 0
        if settingsCount > 1 { return true }

        var monthDesc = FetchDescriptor<MonthRecord>()
        monthDesc.propertiesToFetch = [\.key]
        let monthKeys = ((try? context.fetch(monthDesc)) ?? []).map(\.key)
        if Set(monthKeys).count != monthKeys.count { return true }

        var txnDesc = FetchDescriptor<Transaction>()
        txnDesc.propertiesToFetch = [\.id]
        let txnIDs = ((try? context.fetch(txnDesc)) ?? []).map(\.id)
        if Set(txnIDs).count != txnIDs.count { return true }

        var ruleDesc = FetchDescriptor<RecurringRule>()
        ruleDesc.propertiesToFetch = [\.id]
        let ruleIDs = ((try? context.fetch(ruleDesc)) ?? []).map(\.id)
        if Set(ruleIDs).count != ruleIDs.count { return true }

        // A month-delete grace period pending? Finish the job.
        return !MonthDeleteGrace.load().isEmpty
    }

    // MARK: Canonical month selection

    /// Deterministic cross-device ordering for months sharing a key: earliest
    /// createdAt wins (set once at creation and synced, so every device agrees;
    /// sub-second Dates make cross-device ties effectively impossible).
    static func monthPrecedes(_ a: MonthRecord, _ b: MonthRecord) -> Bool {
        if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
        if a.txns.count != b.txns.count { return a.txns.count > b.txns.count }
        return a.income > b.income
    }

    /// The canonical record for a month key — what views should display, so a
    /// duplicate lingering through its delete-grace period is never visible.
    static func canonical(_ months: [MonthRecord], key: String) -> MonthRecord? {
        months.lazy.filter { $0.key == key }.min(by: monthPrecedes)
    }

    /// All months, one canonical record per key, sorted by key.
    static func canonicalMonths(_ months: [MonthRecord]) -> [MonthRecord] {
        Dictionary(grouping: months, by: \.key)
            .values
            .compactMap { $0.min(by: monthPrecedes) }
            .sorted { $0.key < $1.key }
    }

    private static func mergeDuplicateSettings(in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<AppSettings>())) ?? []
        guard let first = all.first else { return }
        if all.count > 1 {
            // Merge CONTENT deterministically (same result on every device):
            // income = the largest configured income; the split rides with the
            // row that carried it. Even if two devices keep different records
            // momentarily, both records hold identical merged values — and if
            // a mutual delete empties the table entirely, `settings(in:)`
            // recreates the row from the local cache instead of zeros.
            let keep = all.min(by: { settingsKey($0) < settingsKey($1) }) ?? first
            let richest = all.max(by: { settingsKey($0) < settingsKey($1) }) ?? first
            if keep !== richest {
                keep.defaultIncome = max(keep.defaultIncome, richest.defaultIncome)
                if keep.defaultIncome == richest.defaultIncome {
                    keep.defaultNeedsPct = richest.defaultNeedsPct
                    keep.defaultSavingsPct = richest.defaultSavingsPct
                    keep.defaultWantsPct = richest.defaultWantsPct
                }
            }
            for s in all where s !== keep { context.delete(s) }
            SettingsBackup.save(keep)
        } else {
            SettingsBackup.save(first)
        }
    }

    /// Deterministic content ordering for settings rows (higher income sorts
    /// later, so `max` = the configured row and `min` = a stable keep-choice).
    private static func settingsKey(_ s: AppSettings) -> String {
        String(format: "%015.2f|%05.1f|%05.1f|%05.1f",
               s.defaultIncome, s.defaultNeedsPct, s.defaultSavingsPct, s.defaultWantsPct)
    }

    private static func mergeDuplicateMonths(in context: ModelContext) {
        let groups = Dictionary(grouping: allMonths(in: context), by: { $0.key })
        var pending = MonthDeleteGrace.load()
        var active: Set<String> = []
        let now = Date().timeIntervalSince1970

        for (_, group) in groups where group.count > 1 {
            let canonical = group.min(by: monthPrecedes)!
            for dup in group where dup !== canonical {
                // Late-arriving remote transactions reset the delete clock.
                if !dup.txns.isEmpty { pending[MonthDeleteGrace.signature(dup)] = now }

                if canonical.income == 0, dup.income != 0 {
                    canonical.income = dup.income
                    canonical.needsPct = dup.needsPct
                    canonical.savingsPct = dup.savingsPct
                    canonical.wantsPct = dup.wantsPct
                }
                if dup.isClosed { canonical.isClosed = true }
                for txn in dup.txns { txn.month = canonical }

                let sig = MonthDeleteGrace.signature(dup)
                if let firstSeenEmpty = pending[sig] {
                    if now - firstSeenEmpty >= MonthDeleteGrace.period {
                        context.delete(dup)
                        pending.removeValue(forKey: sig)
                    } else {
                        active.insert(sig)
                    }
                } else {
                    pending[sig] = now
                    active.insert(sig)
                }
            }
        }

        // Drop grace entries whose duplicates no longer exist.
        pending = pending.filter { active.contains($0.key) }
        MonthDeleteGrace.save(pending)
    }

    /// Collapse duplicate transactions within a month, deterministically.
    /// Pass 1: copies sharing an id (imports preserve ids; deterministic
    /// recurring ids collide across devices on purpose). Pass 2: rows
    /// materialized from the same recurring rule under different ids — the
    /// legacy of the pre-deterministic-id race (the permanent "double rent").
    private static func dedupeTransactions(in month: MonthRecord, context: ModelContext) {
        var byID: [UUID: [Transaction]] = [:]
        for txn in month.txns { byID[txn.id, default: []].append(txn) }
        var deleted = Set<ObjectIdentifier>()
        for (_, copies) in byID where copies.count > 1 {
            let survivor = copies.min(by: { survivorKey($0) < survivorKey($1) })!
            for txn in copies where txn !== survivor {
                deleted.insert(ObjectIdentifier(txn))
                context.delete(txn)
            }
        }

        var byRule: [UUID: [Transaction]] = [:]
        for txn in month.txns where !deleted.contains(ObjectIdentifier(txn)) {
            if let ruleID = txn.recurringRuleID {
                byRule[ruleID, default: []].append(txn)
            }
        }
        for (_, copies) in byRule where copies.count > 1 {
            let survivor = copies.min(by: { survivorKey($0) < survivorKey($1) })!
            for txn in copies where txn !== survivor { context.delete(txn) }
        }
    }

    /// Deterministic, synced-content-only ordering for duplicate transactions —
    /// every device picks the same survivor. Rule-linked rows sort first so a
    /// dedupe between a tagged and an untagged copy keeps the rule link.
    private static func survivorKey(_ t: Transaction) -> String {
        let tagged = t.recurringRuleID == nil ? "1" : "0"
        let stamp = String(format: "%017.3f", t.date.timeIntervalSince1970)
        let amount = String(format: "%015.2f", t.amount)
        return "\(tagged)|\(stamp)|\(amount)|\(t.desc)|\(t.categoryRaw)|\(t.id.uuidString)"
    }

    private static func dedupeRecurringRules(in context: ModelContext) {
        // Fetch is sorted by createdAt, so first-seen is deterministic.
        var seen = Set<UUID>()
        for rule in allRecurringRules(in: context) {
            if seen.contains(rule.id) { context.delete(rule) } else { seen.insert(rule.id) }
        }
    }

    // MARK: Merge support stores (local, not synced)

    /// Grace-period bookkeeping for duplicate-month deletion. Signature is
    /// key + createdAt so a re-created month never inherits an old timer.
    enum MonthDeleteGrace {
        static let storageKey = "pendingMonthDeletes"
        /// How long a duplicate must stay empty before it's deleted (seconds).
        static let period: Double = 300

        static func signature(_ m: MonthRecord) -> String {
            "\(m.key)|\(m.createdAt.timeIntervalSince1970)"
        }
        static func load() -> [String: Double] {
            UserDefaults.standard.dictionary(forKey: storageKey) as? [String: Double] ?? [:]
        }
        static func save(_ dict: [String: Double]) {
            if dict.isEmpty { UserDefaults.standard.removeObject(forKey: storageKey) }
            else { UserDefaults.standard.set(dict, forKey: storageKey) }
        }
        static func clear() { UserDefaults.standard.removeObject(forKey: storageKey) }
    }

    /// Local cache of the last-known settings, so if a cross-device merge race
    /// ever deletes every settings row, recreation restores the user's income
    /// and split instead of silently resetting to zeros.
    enum SettingsBackup {
        private static let key = "settingsBackupV1"

        static func save(_ s: AppSettings) {
            UserDefaults.standard.set(
                [s.defaultIncome, s.defaultNeedsPct, s.defaultSavingsPct, s.defaultWantsPct],
                forKey: key)
        }
        static func restore(into s: AppSettings) {
            guard let values = UserDefaults.standard.array(forKey: key) as? [Double],
                  values.count == 4 else { return }
            s.defaultIncome = values[0]
            s.defaultNeedsPct = values[1]
            s.defaultSavingsPct = values[2]
            s.defaultWantsPct = values[3]
        }
        static func clear() { UserDefaults.standard.removeObject(forKey: key) }
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
        // Settings — only when the file actually carried them; a partial file
        // without a settings object must not reset income/split to defaults.
        if archive.hadSettings {
            let settings = settings(in: context)
            settings.defaultIncome = archive.settings.defaultIncome
            settings.defaultSplit = BudgetSplit(needs: archive.settings.needsPct,
                                                savings: archive.settings.savingsPct,
                                                wants: archive.settings.wantsPct)
        }

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
                                      date: txnDTO.date,
                                      recurringRuleID: txnDTO.recurringRuleID)
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

    // MARK: Reset

    /// Delete everything — months, transactions, recurring rules, and settings.
    /// With CloudKit enabled, these deletions sync, so it clears the user's data
    /// across all their devices. Irreversible.
    static func resetAllData(in context: ModelContext) {
        for txn in (try? context.fetch(FetchDescriptor<Transaction>())) ?? [] { context.delete(txn) }
        for month in (try? context.fetch(FetchDescriptor<MonthRecord>())) ?? [] { context.delete(month) }
        for rule in (try? context.fetch(FetchDescriptor<RecurringRule>())) ?? [] { context.delete(rule) }
        for settings in (try? context.fetch(FetchDescriptor<AppSettings>())) ?? [] { context.delete(settings) }
        // A reset must not resurrect cached settings or finish stale merges.
        SettingsBackup.clear()
        MonthDeleteGrace.clear()
        try? context.save()
    }
}

// MARK: - Draft transaction (command bar)

/// A proposed transaction produced by the "Tell Ledger" command bar, shown for
/// review before it's committed. Plain value type so the UI compiles on every OS.
struct DraftTxn: Identifiable {
    let id = UUID()
    var note: String
    var amount: Double
    var category: BudgetCategory
}

/// A short, structured monthly summary. Computed entirely in Swift so the
/// figures are always correct and consistent (the on-device model proved too
/// unreliable at arithmetic / category mapping for this).
struct MonthInsight {
    var headline: String
    var observations: [String]
    var suggestion: String
}

// MARK: - Widget snapshot

/// A tiny current-month summary the app writes to the shared App Group so the
/// widgets can render without touching SwiftData. The widget target keeps an
/// identical copy of this struct (same JSON shape) — keep them in sync.
struct BudgetSnapshot: Codable {
    var monthKey: String
    var monthName: String
    var shortMonthName: String
    var safeToSpend: Double
    var needsSpent: Double
    var needsBudget: Double
    var savingsSpent: Double
    var savingsBudget: Double
    var wantsSpent: Double
    var wantsBudget: Double
    var savingsRate: Double
    var updatedAt: Date
}

enum BudgetSnapshotStore {
    static let appGroup = "group.com.anthonystacy.Ledger"
    static let key = "currentBudgetSnapshot"

    /// Build a snapshot for the month the user is actively budgeting and write it
    /// to the shared container, then ask WidgetKit to refresh. No-ops if the App
    /// Group isn't available or there's no suitable month yet.
    ///
    /// The widget should reflect the real current calendar month — but if you've
    /// closed it early and advanced (e.g. wrapping up June on the 30th and moving
    /// to July), it follows the next open month instead, so the widget tracks the
    /// month you're actually budgeting rather than a frozen, closed one.
    static func update(from months: [MonthRecord]) {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return }
        let current = MonthKey.current
        // Collapse to one canonical record per key first, so a duplicate month
        // waiting out its delete-grace period can't feed the widget bad data.
        let unique = LedgerService.canonicalMonths(months)
        let month = unique.first(where: { $0.key == current && !$0.isClosed })
            ?? unique.filter { !$0.isClosed && $0.key > current }.min(by: { $0.key < $1.key })
            ?? unique.first(where: { $0.key == current })
        guard let month else {
            // No month to show (e.g. after "reset all data") — clear the stale
            // snapshot so widgets fall back to their placeholder instead of
            // displaying the wiped budget indefinitely.
            if defaults.data(forKey: key) != nil {
                defaults.removeObject(forKey: key)
                WidgetCenter.shared.reloadAllTimelines()
            }
            return
        }
        let snapshot = BudgetSnapshot(
            monthKey: month.key,
            monthName: MonthKey.displayName(month.key),
            shortMonthName: MonthKey.shortMonthName(month.key),
            safeToSpend: month.safeToSpend,
            needsSpent: month.spent(for: .needs),
            needsBudget: month.budget(for: .needs),
            savingsSpent: month.spent(for: .savings),
            savingsBudget: month.budget(for: .savings),
            wantsSpent: month.spent(for: .wants),
            wantsBudget: month.budget(for: .wants),
            savingsRate: month.savingsRate,
            updatedAt: Date())
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: key)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

// MARK: - Budget alerts (local notifications)

/// Local notifications when a bucket gets close to or over its limit, for the
/// current month. Off until the user enables it in Settings; entirely on-device
/// (no push entitlement). Savings is never flagged for going over — that's good.
enum BudgetAlerts {
    static let enabledKey = "budgetAlertsEnabled"
    private static let warnThreshold = 0.80

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    /// Ask iOS for permission to show alerts. Returns whether it was granted.
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Re-check the current month's Needs & Wants after a spend change and fire a
    /// one-time alert when a bucket crosses 80% or goes over. Safe to call from
    /// every mutation path; no-ops unless enabled and on the (open) current month.
    static func evaluate(_ month: MonthRecord?) {
        guard isEnabled,
              let month, month.key == MonthKey.current, !month.isClosed else { return }
        let defaults = UserDefaults.standard
        for category in [BudgetCategory.needs, .wants] {   // Savings stays silent
            let budget = month.budget(for: category)
            guard budget > 0 else { continue }
            let spent = month.spent(for: category)
            let fraction = spent / budget
            let warnKey = key(month.key, category, "warn")
            let overKey = key(month.key, category, "over")

            if fraction >= 1.0 {
                if !defaults.bool(forKey: overKey) {
                    notify("\(category.title) over budget",
                           "\(category.title) is over by \(Money.string(spent - budget)) this month.")
                    defaults.set(true, forKey: overKey)
                    defaults.set(true, forKey: warnKey)   // suppress a redundant 80% ping
                }
            } else if fraction >= warnThreshold {
                defaults.set(false, forKey: overKey)       // re-arm "over" (back under 100%)
                if !defaults.bool(forKey: warnKey) {
                    notify("\(category.title) at \(Int((fraction * 100).rounded()))%",
                           "\(Money.string(budget - spent)) left in \(category.title) this month.")
                    defaults.set(true, forKey: warnKey)
                }
            } else {
                defaults.set(false, forKey: warnKey)       // fully re-armed below 80%
                defaults.set(false, forKey: overKey)
            }
        }
    }

    private static func key(_ month: String, _ c: BudgetCategory, _ kind: String) -> String {
        "alert.\(month).\(c.rawValue).\(kind)"
    }

    private static func notify(_ title: String, _ body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: nil)   // deliver immediately
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Learned merchant categories

/// Remembers the category you chose for a given merchant/description so the
/// command bar can pre-fill it next time, overriding the model's guess. Stored
/// locally in UserDefaults (tiny, capped, not synced — iCloud sync is a 2.0
/// idea, deliberately deferred). Self-correcting: a newer choice overwrites.
enum CategoryMemory {
    private static let storageKey = "merchantCategoryMemoryV1"
    private static let cap = 200

    private struct Entry: Codable { var key: String; var category: String }

    /// The remembered category for a description, if any.
    static func category(for note: String) -> BudgetCategory? {
        let k = normalize(note)
        guard !k.isEmpty else { return nil }
        if let entry = load().last(where: { $0.key == k }) {
            return BudgetCategory(rawValue: entry.category)
        }
        return nil
    }

    /// Record (or update) the category for a description. Most recent wins.
    static func remember(_ note: String, as category: BudgetCategory) {
        let k = normalize(note)
        guard !k.isEmpty else { return }
        var entries = load().filter { $0.key != k }
        entries.append(Entry(key: k, category: category.rawValue))
        if entries.count > cap { entries.removeFirst(entries.count - cap) }
        save(entries)
    }

    static var count: Int { load().count }

    static func reset() { UserDefaults.standard.removeObject(forKey: storageKey) }

    private static func normalize(_ s: String) -> String {
        s.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static func load() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let entries = try? JSONDecoder().decode([Entry].self, from: data)
        else { return [] }
        return entries
    }

    private static func save(_ entries: [Entry]) {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

// MARK: - On-device intelligence

/// Wraps all Apple Foundation Models use behind availability gates. On devices
/// without Apple Intelligence (or OSes < 26) it reports unavailable and the AI
/// UI is hidden; a small regex fallback still parses the simplest commands.
///
/// Core principle: the model only *extracts* structured drafts. Swift validates
/// the amounts/categories and performs the actual mutation — the model never
/// does arithmetic or writes to the store.
enum IntelligenceService {

    /// Whether the on-device model is ready to use right now.
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    /// Human-readable status for the Settings blurb.
    static var statusMessage: String {
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return "On-device AI is ready. Tap the sparkle button on the Budget screen to add transactions just by typing what you spent — it's processed entirely on your device."
            case .unavailable(.deviceNotEligible):
                return "This device doesn't support Apple Intelligence, so the AI command bar is hidden. Everything else works normally — add transactions with the + button."
            case .unavailable(.appleIntelligenceNotEnabled):
                return "Turn on Apple Intelligence in System Settings to enable the AI command bar."
            case .unavailable(.modelNotReady):
                return "The on-device AI model is still downloading. The command bar will appear once it's ready."
            case .unavailable:
                return "The AI command bar is currently unavailable on this device."
            @unknown default:
                return "The AI command bar is currently unavailable on this device."
            }
        }
        #endif
        return "The AI command bar is available on Apple Intelligence-capable devices running iOS 26 or macOS 26. Everything else works on every device."
    }

    /// Parse free text into draft transactions. Uses the on-device model when
    /// available; falls back to a small regex parser otherwise.
    static func parse(_ text: String) async -> [DraftTxn] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var drafts: [DraftTxn] = []
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *), isAvailable {
            drafts = (try? await parseWithModel(trimmed)) ?? []
        }
        #endif
        if drafts.isEmpty { drafts = parseHeuristic(trimmed) }
        // Your remembered choice for a known merchant wins over the model's guess.
        return drafts.map { draft in
            var d = draft
            if let learned = CategoryMemory.category(for: d.note) { d.category = learned }
            return d
        }
    }

    /// Warm up the on-device model so the first real interpretation is fast
    /// (the cold first call can otherwise take ~30s while the model loads).
    /// Safe to call repeatedly; no-op when AI is unavailable.
    static func prewarm() {
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *), isAvailable {
            sharedSession().prewarm()
        }
        #endif
    }

    /// Reused so the model + schema only warm up once per launch.
    private static var _session: Any?

    // MARK: Heuristic fallback

    /// Best-effort "$X <desc> to <bucket>" parser, splitting on "and"/commas.
    static func parseHeuristic(_ text: String) -> [DraftTxn] {
        text.replacingOccurrences(of: " and ", with: ",")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .compactMap(parseChunk)
    }

    private static func parseChunk(_ chunk: String) -> DraftTxn? {
        guard let amount = firstAmount(in: chunk), amount > 0 else { return nil }
        let category = bucket(in: chunk) ?? guessCategory(chunk)
        let note = cleanNote(chunk)
        return DraftTxn(note: note.isEmpty ? category.title : note,
                        amount: amount, category: category)
    }

    // Allows US thousands separators so "$1,200" parses as 1200, not 1.
    // The lookbehind stops digits glued to letters from reading as amounts —
    // without it, "PS5 $1,000" parses the "5" in PS5 as the amount and mangles
    // the note.
    private static let amountPattern = #"(?<![A-Za-z0-9])\$?\s?\d+(?:,\d{3})*(?:\.\d{1,2})?"#

    private static func firstAmount(in s: String) -> Double? {
        guard let range = s.range(of: amountPattern, options: .regularExpression) else { return nil }
        return Double(s[range].filter { $0.isNumber || $0 == "." })
    }

    private static func bucket(in s: String) -> BudgetCategory? {
        let lower = s.lowercased()
        if lower.contains("need") { return .needs }
        if lower.contains("saving") || lower.contains("save") { return .savings }
        if lower.contains("want") { return .wants }
        return nil
    }

    /// Keyword-based bucket guess for the fallback when no bucket is named.
    private static func guessCategory(_ text: String) -> BudgetCategory {
        let l = text.lowercased()
        let savings = ["saving", "save", "invest", "401k", "ira", "emergency fund"]
        let wants = ["takeout", "take out", "dining", "dinner", "lunch", "coffee",
                     "movie", "game", "tv", "television", "netflix", "spotify",
                     "subscription", "concert", "clothes", "shopping", "bar",
                     "drinks", "gift", "vacation", "travel", "hobby", "gadget",
                     "electronics", "restaurant", "doordash", "uber eats", "ubereats",
                     "grubhub", "starbucks", "ps5", "playstation", "xbox", "nintendo",
                     "steam", "amazon", "chipotle", "mcdonald"]
        if savings.contains(where: l.contains) { return .savings }
        if wants.contains(where: l.contains) { return .wants }
        return .needs
    }

    private static func cleanNote(_ s: String) -> String {
        var out = s
        if let r = out.range(of: amountPattern, options: .regularExpression) {
            out.removeSubrange(r)
        }
        let fillers: Set<String> = ["add", "to", "for", "the", "needs", "savings",
                                    "saving", "save", "wants", "in", "a", "an", "$", "spent", "on"]
        let words = out.split(whereSeparator: { $0 == " " }).map(String.init)
            .filter { !fillers.contains($0.lowercased()) && !$0.isEmpty }
        return words.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    // MARK: On-device model

    #if canImport(FoundationModels)
    @available(iOS 26, macOS 26, *)
    private static func sharedSession() -> LanguageModelSession {
        if let existing = _session as? LanguageModelSession { return existing }
        let created = LanguageModelSession { Self.instructions }
        _session = created
        return created
    }

    @available(iOS 26, macOS 26, *)
    private static func parseWithModel(_ text: String) async throws -> [DraftTxn] {
        let session = sharedSession()
        let response = try await session.respond(to: text, generating: CommandResultAI.self)
        return response.content.transactions.compactMap { ai in
            guard ai.amount > 0 else { return nil }
            let category = BudgetCategory(rawValue: ai.category.lowercased()) ?? .needs
            let note = ai.note.trimmingCharacters(in: .whitespacesAndNewlines)
            return DraftTxn(note: note.isEmpty ? category.title : note,
                            amount: (ai.amount * 100).rounded() / 100,
                            category: category)
        }
    }

    private static let instructions = """
    You turn a person's plain-language note about money into structured transactions for a 50/30/20 budget.
    For each distinct transaction, extract a short note, a positive dollar amount, and one bucket: needs, savings, or wants.

    Always choose the bucket from the description, even when the person doesn't name it:
    - needs = essentials: rent, mortgage, groceries, utilities, electric/water/gas bills, fuel, transit, insurance, phone bill, medicine, childcare.
    - wants = discretionary: takeout, dining out, coffee, alcohol, movies, games, electronics, a TV, gadgets, clothes, hobbies, streaming subscriptions, gifts, travel, concerts.
    - savings = money set aside or invested: transfers to savings, emergency fund, 401k, IRA, brokerage/investments.

    Common brands/services: DoorDash, Uber Eats, Grubhub, Starbucks, McDonald's, Chipotle, restaurants -> wants (food delivery / dining out). PS5, PlayStation, Xbox, Nintendo, Steam games -> wants. Amazon / Target shopping -> usually wants. Netflix, Spotify, Hulu, Disney+ -> wants. Uber, Lyft, gas, transit -> needs. Costco/grocery stores -> needs.

    Examples:
    - "groceries $100" -> note: Groceries, amount: 100, category: needs
    - "doordash $30" -> note: DoorDash, amount: 30, category: wants
    - "bought a PS5 for $500" -> note: PS5, amount: 500, category: wants
    - "rent 1800" -> note: Rent, amount: 1800, category: needs
    - "put 500 into savings" -> note: Savings, amount: 500, category: savings
    - "$60 gift for mom" -> note: Gift, amount: 60, category: wants

    Only include transactions the person actually mentioned. Amounts are positive numbers with no currency symbols.
    """
    #endif
}

#if canImport(FoundationModels)
@available(iOS 26, macOS 26, *)
@Generable
struct DraftTxnAI {
    @Guide(description: "Short description of the purchase, e.g. 'Groceries', 'Electric bill', 'Movie tickets'.")
    var note: String
    @Guide(description: "Amount in dollars as a positive number with no currency symbol.")
    var amount: Double
    @Guide(description: "Exactly one of these words: needs, savings, wants.")
    var category: String
}

@available(iOS 26, macOS 26, *)
@Generable
struct CommandResultAI {
    @Guide(description: "Every transaction the user described, in order.")
    var transactions: [DraftTxnAI]
}
#endif

// MARK: - App Intents (Siri / Shortcuts / Spotlight)

/// Category choices exposed to Siri/Shortcuts.
enum BudgetCategoryAppEnum: String, AppEnum {
    case needs, savings, wants

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Category" }
    static var caseDisplayRepresentations: [BudgetCategoryAppEnum: DisplayRepresentation] {
        [.needs: "Needs", .savings: "Savings", .wants: "Wants"]
    }

    var budgetCategory: BudgetCategory {
        switch self {
        case .needs:   return .needs
        case .savings: return .savings
        case .wants:   return .wants
        }
    }
}

private func currencyCodeForIntents() -> String {
    Locale.current.currency?.identifier ?? "USD"
}

/// "Add $12 groceries to Wants" — adds a transaction to the current month.
struct AddTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Transaction"
    static var description = IntentDescription("Add a transaction to the current month in Ledger.")

    // Amount is a String so Siri accepts "50", "$50", "50 dollars", "1,200.50",
    // or even "fifty" — parsed leniently in perform().
    @Parameter(title: "Amount", requestValueDialog: "How much?")
    var amount: String
    @Parameter(title: "Description", requestValueDialog: "What's it for?")
    var note: String
    @Parameter(title: "Category")
    var category: BudgetCategoryAppEnum

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$amount) for \(\.$note) to \(\.$category)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let value = Self.parseAmount(amount), value > 0 else {
            throw $amount.needsValueError("Sorry, how much? Try a number like 50.")
        }
        let context = AppModelContainer.shared.mainContext
        let month = LedgerService.ensureMonth(forKey: MonthKey.current, in: context)
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        LedgerService.addTransaction(to: month,
                                     desc: cleanNote,
                                     amount: value,
                                     category: category.budgetCategory,
                                     date: Date(),
                                     in: context)
        try? context.save()
        BudgetSnapshotStore.update(from: LedgerService.allMonths(in: context))
        let amountText = value.formatted(.currency(code: currencyCodeForIntents()))
        let label = cleanNote.isEmpty ? category.budgetCategory.title : cleanNote
        return .result(dialog: "Added \(amountText) for \(label) to \(category.budgetCategory.title).")
    }

    /// Parse "50", "$50", "50 dollars", "1,200.50", or "fifty" into a Double.
    static func parseAmount(_ s: String) -> Double? {
        let digits = s.filter { $0.isNumber || $0 == "." }
        if let d = Double(digits), d > 0 { return d }
        let spell = NumberFormatter()
        spell.numberStyle = .spellOut
        if let n = spell.number(from: s.lowercased()) { return n.doubleValue }
        return nil
    }
}

/// "What's safe to spend in Ledger?" — read-only.
struct SafeToSpendIntent: AppIntent {
    static var title: LocalizedStringResource = "Safe to Spend"
    static var description = IntentDescription("Check how much is left to spend this month in Ledger.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = AppModelContainer.shared.mainContext
        guard let month = LedgerService.month(forKey: MonthKey.current, in: context) else {
            return .result(dialog: "You haven't started this month in Ledger yet.")
        }
        let name = MonthKey.displayName(month.key)
        if month.safeToSpend >= 0 {
            let amt = month.safeToSpend.formatted(.currency(code: currencyCodeForIntents()))
            return .result(dialog: "You have \(amt) left to spend in \(name).")
        } else {
            let amt = abs(month.safeToSpend).formatted(.currency(code: currencyCodeForIntents()))
            return .result(dialog: "You're \(amt) over budget in \(name).")
        }
    }
}

/// One-press quick add — just opens Ledger to the new-transaction sheet (no
/// parameters), ideal for the Action Button or Control Center.
struct AddTransactionQuickIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Add Transaction"
    static var description = IntentDescription("Open Ledger and start a new transaction.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickAdd.request()
        return .result()
    }
}

/// A tiny hand-off flag: the Quick Add intent only launches the app, so it leaves
/// this for the UI to pick up and pop the add sheet once a screen is on.
enum QuickAdd {
    private static let key = "pendingQuickAdd"
    static func request() { UserDefaults.standard.set(true, forKey: key) }
    /// Returns true at most once, then clears itself.
    static func consume() -> Bool {
        guard UserDefaults.standard.bool(forKey: key) else { return false }
        UserDefaults.standard.set(false, forKey: key)
        return true
    }
}

struct LedgerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTransactionIntent(),
            phrases: [
                "Add a transaction to \(.applicationName)",
                "Log spending in \(.applicationName)"
            ],
            shortTitle: "Add Transaction",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: AddTransactionQuickIntent(),
            phrases: [
                "Quick add in \(.applicationName)",
                "New transaction in \(.applicationName)"
            ],
            shortTitle: "Quick Add",
            systemImageName: "plus.app"
        )
        AppShortcut(
            intent: SafeToSpendIntent(),
            phrases: [
                "What's safe to spend in \(.applicationName)",
                "How much can I spend in \(.applicationName)"
            ],
            shortTitle: "Safe to Spend",
            systemImageName: "dollarsign.circle"
        )
    }
}
