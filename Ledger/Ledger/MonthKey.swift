//
//  MonthKey.swift
//  Ledger
//
//  Helpers for the 1-indexed, human-readable month key ("2026-05" == May).
//  In Swift, `Calendar.component(.month)` is already 1-indexed, so there is no
//  JS-style off-by-one here — these helpers just keep formatting in one place
//  so the bug can never creep back in.
//

import Foundation

enum MonthKey {

    /// Calendar used for all key math. Fixed to Gregorian so keys are stable
    /// regardless of the user's locale calendar.
    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        return cal
    }

    /// "2026-05" for the given date (month is 1-indexed: 05 == May).
    static func key(for date: Date) -> String {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return key(year: comps.year ?? 2000, month: comps.month ?? 1)
    }

    static func key(year: Int, month: Int) -> String {
        return String(format: "%04d-%02d", year, month)
    }

    static var current: String { key(for: Date()) }

    /// Parsed (year, month) from a key, or nil if malformed.
    static func components(_ key: String) -> (year: Int, month: Int)? {
        let parts = key.split(separator: "-")
        guard parts.count == 2,
              let y = Int(parts[0]),
              let m = Int(parts[1]),
              (1...12).contains(m) else { return nil }
        return (y, m)
    }

    /// The key one month before/after the given key (offset may be negative).
    static func offset(_ key: String, by months: Int) -> String {
        guard let (y, m) = components(key) else { return key }
        // Convert to a zero-based absolute month count, shift, convert back.
        let absolute = y * 12 + (m - 1) + months
        let newYear = absolute / 12
        let newMonth = absolute % 12 + 1
        return MonthKey.key(year: newYear, month: newMonth)
    }

    /// Days left in the real current calendar month, INCLUDING today (min 1).
    /// Used to pace remaining budget ("$X/wk left").
    static func daysRemainingInCurrentMonth(from date: Date = Date()) -> Int {
        let day = calendar.component(.day, from: date)
        let length = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
        return max(length - day + 1, 1)
    }

    /// "May 2026" for display.
    static func displayName(_ key: String) -> String {
        guard let (y, m) = components(key) else { return key }
        let names = ["January", "February", "March", "April", "May", "June",
                     "July", "August", "September", "October", "November", "December"]
        return "\(names[m - 1]) \(y)"
    }

    /// "May" (no year) for compact display.
    static func shortMonthName(_ key: String) -> String {
        guard let (_, m) = components(key) else { return key }
        let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                     "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return names[m - 1]
    }
}
