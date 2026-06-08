//
//  ImportExport.swift
//  Ledger
//
//  Codable DTOs plus JSON/CSV encode & decode, and the FileDocument types used
//  by .fileExporter / .fileImporter. Works on iOS, iPadOS, macOS and visionOS.
//

import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import CryptoKit

// MARK: - DTOs

struct ExportData: Codable {
    var version: Int = 1
    var exportedAt: Date = Date()
    var settings: SettingsDTO = SettingsDTO(defaultIncome: 0, needsPct: 50, savingsPct: 20, wantsPct: 30)
    var months: [MonthDTO] = []
    /// Optional for backward/forward compatibility with older exports.
    var rules: [RuleDTO]? = []

    init(version: Int = 1, exportedAt: Date = Date(), settings: SettingsDTO,
         months: [MonthDTO], rules: [RuleDTO]? = []) {
        self.version = version; self.exportedAt = exportedAt
        self.settings = settings; self.months = months; self.rules = rules
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        exportedAt = try c.decodeIfPresent(Date.self, forKey: .exportedAt) ?? Date()
        settings = try c.decodeIfPresent(SettingsDTO.self, forKey: .settings)
            ?? SettingsDTO(defaultIncome: 0, needsPct: 50, savingsPct: 20, wantsPct: 30)
        months = try c.decodeIfPresent([MonthDTO].self, forKey: .months) ?? []
        rules = try c.decodeIfPresent([RuleDTO].self, forKey: .rules) ?? []
    }
}

struct RuleDTO: Codable {
    var id: UUID = UUID()
    var desc: String = ""
    var amount: Double = 0
    var category: String = "needs"
    var dayOfMonth: Int = 1
    var isActive: Bool = true
    var startKey: String = ""

    init(id: UUID, desc: String, amount: Double, category: String,
         dayOfMonth: Int, isActive: Bool, startKey: String) {
        self.id = id; self.desc = desc; self.amount = amount; self.category = category
        self.dayOfMonth = dayOfMonth; self.isActive = isActive; self.startKey = startKey
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        desc = try c.decodeIfPresent(String.self, forKey: .desc) ?? ""
        amount = try c.decodeIfPresent(Double.self, forKey: .amount) ?? 0
        category = (try c.decodeIfPresent(String.self, forKey: .category) ?? "needs").lowercased()
        dayOfMonth = try c.decodeIfPresent(Int.self, forKey: .dayOfMonth) ?? 1
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        startKey = try c.decodeIfPresent(String.self, forKey: .startKey) ?? ""
    }
}

// The DTOs decode forgivingly: missing fields fall back to sensible defaults so
// hand-written or partial test files still import. Encoding always writes every
// field.

struct SettingsDTO: Codable {
    var defaultIncome: Double = 0
    var needsPct: Double = 50
    var savingsPct: Double = 20
    var wantsPct: Double = 30

    init(defaultIncome: Double, needsPct: Double, savingsPct: Double, wantsPct: Double) {
        self.defaultIncome = defaultIncome
        self.needsPct = needsPct
        self.savingsPct = savingsPct
        self.wantsPct = wantsPct
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        defaultIncome = try c.decodeIfPresent(Double.self, forKey: .defaultIncome) ?? 0
        needsPct = try c.decodeIfPresent(Double.self, forKey: .needsPct) ?? 50
        savingsPct = try c.decodeIfPresent(Double.self, forKey: .savingsPct) ?? 20
        wantsPct = try c.decodeIfPresent(Double.self, forKey: .wantsPct) ?? 30
    }
}

struct MonthDTO: Codable {
    var key: String = ""
    var income: Double = 0
    var needsPct: Double = 50
    var savingsPct: Double = 20
    var wantsPct: Double = 30
    var isClosed: Bool = false
    var createdAt: Date = Date()
    var transactions: [TransactionDTO] = []

    init(key: String, income: Double, needsPct: Double, savingsPct: Double,
         wantsPct: Double, isClosed: Bool, createdAt: Date, transactions: [TransactionDTO]) {
        self.key = key; self.income = income; self.needsPct = needsPct
        self.savingsPct = savingsPct; self.wantsPct = wantsPct; self.isClosed = isClosed
        self.createdAt = createdAt; self.transactions = transactions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decodeIfPresent(String.self, forKey: .key) ?? ""
        income = try c.decodeIfPresent(Double.self, forKey: .income) ?? 0
        needsPct = try c.decodeIfPresent(Double.self, forKey: .needsPct) ?? 50
        savingsPct = try c.decodeIfPresent(Double.self, forKey: .savingsPct) ?? 20
        wantsPct = try c.decodeIfPresent(Double.self, forKey: .wantsPct) ?? 30
        isClosed = try c.decodeIfPresent(Bool.self, forKey: .isClosed) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        transactions = try c.decodeIfPresent([TransactionDTO].self, forKey: .transactions) ?? []
    }
}

struct TransactionDTO: Codable {
    var id: UUID = UUID()
    var desc: String = ""
    var amount: Double = 0
    var category: String = "needs"
    var date: Date = Date()

    init(id: UUID, desc: String, amount: Double, category: String, date: Date) {
        self.id = id; self.desc = desc; self.amount = amount
        self.category = category; self.date = date
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        // Accept either "desc" or "description".
        desc = try c.decodeIfPresent(String.self, forKey: .desc)
            ?? c.decodeIfPresent(String.self, forKey: .description) ?? ""
        amount = try c.decodeIfPresent(Double.self, forKey: .amount) ?? 0
        category = (try c.decodeIfPresent(String.self, forKey: .category) ?? "needs").lowercased()
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(desc, forKey: .desc)
        try c.encode(amount, forKey: .amount)
        try c.encode(category, forKey: .category)
        try c.encode(date, forKey: .date)
    }

    enum CodingKeys: String, CodingKey {
        case id, desc, description, amount, category, date
    }
}

// MARK: - Legacy web-app format
//
// The original single-file web app exported:
//   { "exportedAt": "...", "version": 1,
//     "data": { "currentMonthKey": "2026-06",
//               "months": { "2026-05": { "income": 7000,
//                                        "closed": true,
//                                        "transactions": [
//                                          { "id": 177..., "desc": "Rent",
//                                            "amount": 1966, "cat": "needs",
//                                            "ts": 1778282456380 } ] } } } }
// Note: months is a *dictionary*, `cat`/`ts` field names, `ts` is unix millis,
// numeric ids, no per-month split or settings.

struct LegacyArchive: Decodable {
    struct Payload: Decodable {
        var currentMonthKey: String?
        var months: [String: LegacyMonth]
    }
    var data: Payload
}

struct LegacyMonth: Decodable {
    var income: Double?
    var closed: Bool?
    var transactions: [LegacyTxn]?
}

struct LegacyTxn: Decodable {
    var id: Double?
    var desc: String?
    var amount: Double?
    var cat: String?
    var ts: Double?
}

// MARK: - Mapping

enum LedgerArchive {

    static func makeExport(settings: AppSettings?,
                           months: [MonthRecord],
                           rules: [RecurringRule] = []) -> ExportData {
        let settingsDTO = SettingsDTO(
            defaultIncome: settings?.defaultIncome ?? 0,
            needsPct: settings?.defaultNeedsPct ?? 50,
            savingsPct: settings?.defaultSavingsPct ?? 20,
            wantsPct: settings?.defaultWantsPct ?? 30
        )
        let monthDTOs = months
            .sorted { $0.key < $1.key }
            .map { month in
                MonthDTO(
                    key: month.key,
                    income: month.income,
                    needsPct: month.needsPct,
                    savingsPct: month.savingsPct,
                    wantsPct: month.wantsPct,
                    isClosed: month.isClosed,
                    createdAt: month.createdAt,
                    transactions: month.txns
                        .sorted { $0.date < $1.date }
                        .map { TransactionDTO(id: $0.id, desc: $0.desc, amount: $0.amount,
                                              category: $0.categoryRaw, date: $0.date) }
                )
            }
        let ruleDTOs = rules.map { rule in
            RuleDTO(id: rule.id, desc: rule.desc, amount: rule.amount,
                    category: rule.categoryRaw, dayOfMonth: rule.dayOfMonth,
                    isActive: rule.isActive, startKey: rule.startKey)
        }
        return ExportData(settings: settingsDTO, months: monthDTOs, rules: ruleDTOs)
    }

    // MARK: JSON

    static func encodeJSON(_ data: ExportData) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(data)
    }

    static func decodeJSON(_ data: Data) throws -> ExportData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { dec in
            let container = try dec.singleValueContainer()
            if let s = try? container.decode(String.self) {
                if let d = flexibleDate(s) { return d }
                throw DecodingError.dataCorruptedError(
                    in: container, debugDescription: "Unrecognized date format: \"\(s)\"")
            }
            if let t = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: t) // unix seconds
            }
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Date must be a string or number")
        }
        return try decoder.decode(ExportData.self, from: data)
    }

    /// Parse the common date encodings we might see in imported files.
    static func flexibleDate(_ s: String) -> Date? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return Date() }

        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFrac.date(from: trimmed) { return d }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: trimmed) { return d }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "UTC")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss",
                    "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd", "MM/dd/yyyy", "M/d/yyyy"] {
            df.dateFormat = fmt
            if let d = df.date(from: trimmed) { return d }
        }
        // Numeric string as unix seconds.
        if let t = Double(trimmed) { return Date(timeIntervalSince1970: t) }
        return nil
    }

    // MARK: Auto-detecting decode (native or legacy web-app format)

    /// Decode either this app's native export or the original web app's backup
    /// format, returning a native ExportData either way. `defaultSplit` is used
    /// for legacy months, which carry no allocation of their own.
    static func decodeAny(_ data: Data, defaultSplit: BudgetSplit) throws -> ExportData {
        // Legacy files nest everything under "data" with a months *dictionary*.
        // Native files have no top-level "data", so this decode fails and we
        // fall through.
        if let legacy = try? JSONDecoder().decode(LegacyArchive.self, from: data),
           !legacy.data.months.isEmpty {
            return convertLegacy(legacy, defaultSplit: defaultSplit)
        }
        return try decodeJSON(data)
    }

    private static func convertLegacy(_ legacy: LegacyArchive,
                                      defaultSplit: BudgetSplit) -> ExportData {
        var monthDTOs: [MonthDTO] = []
        for (key, m) in legacy.data.months {
            let txns: [TransactionDTO] = (m.transactions ?? []).map { t in
                let cat = BudgetCategory(rawValue: (t.cat ?? "needs").lowercased())?.rawValue
                    ?? BudgetCategory.needs.rawValue
                // `ts` is unix milliseconds in the web app.
                let date = t.ts.map { Date(timeIntervalSince1970: $0 / 1000) } ?? firstOfMonth(key)
                let seed = "legacy|\(key)|\(t.id ?? 0)|\(t.ts ?? 0)|\(t.desc ?? "")"
                return TransactionDTO(id: deterministicUUID(seed),
                                      desc: t.desc ?? "",
                                      amount: t.amount ?? 0,
                                      category: cat,
                                      date: date)
            }
            monthDTOs.append(MonthDTO(key: key,
                                      income: m.income ?? 0,
                                      needsPct: defaultSplit.needs,
                                      savingsPct: defaultSplit.savings,
                                      wantsPct: defaultSplit.wants,
                                      isClosed: m.closed ?? false,
                                      createdAt: firstOfMonth(key),
                                      transactions: txns))
        }
        monthDTOs.sort { $0.key < $1.key }

        // The web app stored no default income; use the "current" month's income
        // (or the most recent month) as a sensible carry-forward default.
        let currentIncome = legacy.data.currentMonthKey
            .flatMap { legacy.data.months[$0]?.income }
        let defaultIncome = currentIncome ?? monthDTOs.last?.income ?? 0
        let settings = SettingsDTO(defaultIncome: defaultIncome,
                                   needsPct: defaultSplit.needs,
                                   savingsPct: defaultSplit.savings,
                                   wantsPct: defaultSplit.wants)
        return ExportData(settings: settings, months: monthDTOs, rules: [])
    }

    private static func firstOfMonth(_ key: String) -> Date {
        guard let (y, m) = MonthKey.components(key) else { return Date() }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        var c = DateComponents()
        c.year = y; c.month = m; c.day = 1
        return cal.date(from: c) ?? Date()
    }

    /// Stable UUID derived from a seed string, so re-importing the same legacy
    /// file doesn't create duplicate transactions.
    private static func deterministicUUID(_ seed: String) -> UUID {
        let digest = Insecure.MD5.hash(data: Data(seed.utf8))
        let b = Array(digest) // exactly 16 bytes
        let bytes: uuid_t = (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                             b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15])
        return UUID(uuid: bytes)
    }

    // MARK: CSV (transactions, flat)

    static func encodeCSV(_ data: ExportData) -> String {
        var rows = ["month,date,description,category,amount"]
        let iso = ISO8601DateFormatter()
        for month in data.months {
            for txn in month.transactions {
                let fields = [
                    month.key,
                    iso.string(from: txn.date),
                    txn.desc,
                    txn.category,
                    String(format: "%.2f", txn.amount)
                ].map(csvEscape)
                rows.append(fields.joined(separator: ","))
            }
        }
        return rows.joined(separator: "\n")
    }

    /// Parse a flat transactions CSV into per-month buckets. Months that don't
    /// already exist are created on import with the current default split.
    static func decodeCSV(_ text: String) -> [String: [TransactionDTO]] {
        var result: [String: [TransactionDTO]] = [:]
        let lines = text.split(whereSeparator: \.isNewline)
        guard lines.count > 1 else { return result }

        // Tolerate an optional header row (skip the first line if it looks like
        // a header rather than data).
        let firstCols = parseCSVLine(String(lines[0]))
        let hasHeader = firstCols.contains { $0.lowercased() == "amount" || $0.lowercased() == "category" }
        let dataLines = hasHeader ? lines.dropFirst() : lines[...]

        for line in dataLines {
            let cols = parseCSVLine(String(line))
            guard cols.count >= 5 else { continue }
            let monthKey = cols[0]
            let date = flexibleDate(cols[1]) ?? Date()
            let desc = cols[2]
            let category = BudgetCategory(rawValue: cols[3].lowercased())?.rawValue
                ?? BudgetCategory.needs.rawValue
            let amount = Double(cols[4]) ?? 0
            let dto = TransactionDTO(id: UUID(), desc: desc, amount: amount,
                                     category: category, date: date)
            result[monthKey, default: []].append(dto)
        }
        return result
    }

    private static func csvEscape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = line.makeIterator()
        var pending: Character? = iterator.next()
        while let ch = pending {
            pending = iterator.next()
            if inQuotes {
                if ch == "\"" {
                    if pending == "\"" {        // escaped quote
                        current.append("\"")
                        pending = iterator.next()
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(ch)
                }
            } else {
                switch ch {
                case "\"": inQuotes = true
                case ",":  fields.append(current); current = ""
                default:   current.append(ch)
                }
            }
        }
        fields.append(current)
        return fields
    }
}

// MARK: - FileDocument

/// One document type for both JSON and CSV export. Using a single FileDocument
/// (and a single `.fileExporter`) avoids the SwiftUI issue where stacking
/// multiple file exporters on one view leaves some of them inert.
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText, .plainText] }
    static var writableContentTypes: [UTType] { [.json, .commaSeparatedText, .plainText] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
