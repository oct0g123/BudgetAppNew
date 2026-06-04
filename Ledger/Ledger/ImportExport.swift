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

// MARK: - DTOs

struct ExportData: Codable {
    var version: Int = 1
    var exportedAt: Date = Date()
    var settings: SettingsDTO
    var months: [MonthDTO]
}

struct SettingsDTO: Codable {
    var defaultIncome: Double
    var needsPct: Double
    var savingsPct: Double
    var wantsPct: Double
}

struct MonthDTO: Codable {
    var key: String
    var income: Double
    var needsPct: Double
    var savingsPct: Double
    var wantsPct: Double
    var isClosed: Bool
    var createdAt: Date
    var transactions: [TransactionDTO]
}

struct TransactionDTO: Codable {
    var id: UUID
    var desc: String
    var amount: Double
    var category: String
    var date: Date
}

// MARK: - Mapping

enum LedgerArchive {

    static func makeExport(settings: AppSettings?, months: [MonthRecord]) -> ExportData {
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
        return ExportData(settings: settingsDTO, months: monthDTOs)
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
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ExportData.self, from: data)
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
        let iso = ISO8601DateFormatter()
        let lines = text.split(whereSeparator: \.isNewline)
        guard lines.count > 1 else { return result }

        for line in lines.dropFirst() {
            let cols = parseCSVLine(String(line))
            guard cols.count >= 5 else { continue }
            let monthKey = cols[0]
            let date = iso.date(from: cols[1]) ?? Date()
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

// MARK: - FileDocuments

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }
    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        text = String(data: data, encoding: .utf8) ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
