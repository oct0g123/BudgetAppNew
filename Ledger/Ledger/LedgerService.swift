//
//  LedgerService.swift
//  Ledger
//
//  Mutation helpers that operate on a SwiftData ModelContext. Views read data
//  reactively with @Query and call into here to make changes.
//

import Foundation
import SwiftData
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

    // MARK: Deduplication
    //
    // With iCloud sync, two devices can independently create "singleton-ish"
    // records before they've synced — most commonly the current month (each
    // device makes its own on first launch) and the settings row. After they
    // sync you end up with duplicates: e.g. two "2026-06" months, one of which
    // holds the transactions while the other (empty) one is what the UI happens
    // to show. This consolidates them. It's safe to run repeatedly and on every
    // device — the canonical record is chosen the same way everywhere (the copy
    // with the most transactions, tie-broken by earliest creation), so devices
    // converge on deleting the same duplicates rather than fighting.

    static func mergeDuplicates(in context: ModelContext) {
        mergeDuplicateSettings(in: context)
        mergeDuplicateMonths(in: context)
        for month in allMonths(in: context) {
            dedupeTransactions(in: month, context: context)
        }
        dedupeRecurringRules(in: context)
        try? context.save()
    }

    private static func mergeDuplicateSettings(in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<AppSettings>())) ?? []
        guard all.count > 1 else { return }
        // Prefer a row that actually has data over a freshly-defaulted one.
        let keep = all.first(where: { $0.defaultIncome != 0 }) ?? all[0]
        for s in all where s !== keep { context.delete(s) }
    }

    private static func mergeDuplicateMonths(in context: ModelContext) {
        let groups = Dictionary(grouping: allMonths(in: context), by: { $0.key })
        for (_, group) in groups where group.count > 1 {
            // Canonical = most transactions, then earliest createdAt (deterministic).
            let canonical = group.sorted { a, b in
                if a.txns.count != b.txns.count { return a.txns.count > b.txns.count }
                return a.createdAt < b.createdAt
            }.first!

            for dup in group where dup !== canonical {
                // If the canonical copy is the empty one, carry over real metadata.
                if canonical.income == 0, dup.income != 0 {
                    canonical.income = dup.income
                    canonical.needsPct = dup.needsPct
                    canonical.savingsPct = dup.savingsPct
                    canonical.wantsPct = dup.wantsPct
                }
                if dup.isClosed { canonical.isClosed = true }
                for txn in dup.txns { txn.month = canonical }
                context.delete(dup)
            }
        }
    }

    /// Remove transactions that share an id within a month (can happen when the
    /// same data was imported on two devices, since imports preserve ids).
    private static func dedupeTransactions(in month: MonthRecord, context: ModelContext) {
        var seen = Set<UUID>()
        for txn in month.txns {
            if seen.contains(txn.id) { context.delete(txn) } else { seen.insert(txn.id) }
        }
    }

    private static func dedupeRecurringRules(in context: ModelContext) {
        var seen = Set<UUID>()
        for rule in allRecurringRules(in: context) {
            if seen.contains(rule.id) { context.delete(rule) } else { seen.insert(rule.id) }
        }
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

// MARK: - Draft transaction (command bar)

/// A proposed transaction produced by the "Tell Ledger" command bar, shown for
/// review before it's committed. Plain value type so the UI compiles on every OS.
struct DraftTxn: Identifiable {
    let id = UUID()
    var note: String
    var amount: Double
    var category: BudgetCategory
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
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *), isAvailable {
            if let drafts = try? await parseWithModel(trimmed), !drafts.isEmpty {
                return drafts
            }
        }
        #endif
        return parseHeuristic(trimmed)
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

    private static let amountPattern = #"\$?\s?\d+(?:\.\d{1,2})?"#

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
                     "electronics", "restaurant"]
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

    Examples:
    - "groceries $100" -> note: Groceries, amount: 100, category: needs
    - "takeout $30" -> note: Takeout, amount: 30, category: wants
    - "bought a tv for $1000" -> note: TV, amount: 1000, category: wants
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
