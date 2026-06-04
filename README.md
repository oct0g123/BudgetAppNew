# Ledger

A 50/30/20 budget tracker for **iPhone, iPad, Mac, and Apple Vision Pro**, built
with SwiftUI and SwiftData. Your data syncs privately across all your devices
through your own iCloud account — no backend, no account to create.

> This is a native Apple-platforms app. It started from a web (single-file HTML)
> brief, but per the project goals the web-specific constraints (localStorage,
> single `.html` file, etc.) were intentionally dropped in favor of a real
> multiplatform app with iCloud sync.

## Features

- **Monthly income → auto-split** into Needs / Savings / Wants buckets.
- **Adjustable allocation model** — pick 50/30/20, 50/20/30, or fully custom
  percentages (must sum to 100%). The split is stored **per month**, so closing
  or editing the default never rewrites history.
- **Transactions** with description, amount, category, and date; live progress
  bars show spent vs. budget and remaining per bucket. Long-press a row to delete.
- **Recurring transactions** — monthly templates (rent, subscriptions,
  paychecks) that auto-populate each new month on a chosen day. Toggle active,
  edit, or delete; closed months are never altered retroactively.
- **Insights** — Swift Charts dashboards: savings-rate trajectory, spend by
  category over time, and budget-vs-actual for the current month.
- **Filter** transactions by category.
- **Month navigation** (prev/next); the viewed month persists across launches.
- **Close month** to archive it read-only and roll into a fresh next month.
- **History** view summarizing income, spend, split, and savings rate per month.
- **Settings** with a default income that carries forward to new months.
- **Backup & exchange**: export to JSON (full, incl. recurring rules) or CSV,
  import from JSON or CSV (file picker or paste), and copy JSON to the clipboard.
- **iCloud sync** via SwiftData + CloudKit, with a "Saved" indicator.

## Month keys

Months use 1-indexed, human-readable keys: `2026-05` == **May 2026**. Swift's
`Calendar` is already 1-indexed (unlike JavaScript), and all key math is funneled
through `MonthKey.swift` so the classic off-by-one can't return.

## Project layout

```
Ledger.xcodeproj
Ledger/
  LedgerApp.swift        App entry + SwiftData/CloudKit container
  Models.swift           MonthRecord, Transaction, AppSettings, BudgetSplit
  MonthKey.swift         1-indexed month-key helpers
  LedgerService.swift    Mutations (create month, add txn, close, import)
  ImportExport.swift     JSON/CSV DTOs + FileDocument types
  Theme.swift            Dark editorial palette, fonts, currency formatting
  RootView.swift         Tab container
  BudgetView.swift       Main screen (buckets, progress, transactions)
  AddTransactionView.swift
  HistoryView.swift
  SettingsView.swift
  Assets.xcassets, Ledger.entitlements
```

## Before you build

1. Open `Ledger.xcodeproj` in Xcode 16+ (targets iOS 18 / iPadOS 18 / macOS 15 /
   visionOS 2).
2. Select the **Ledger** target → **Signing & Capabilities**:
   - Set your **Team**.
   - Change the **Bundle Identifier** from `com.example.Ledger` to your own.
   - Update the **iCloud container** in `Ledger.entitlements` from
     `iCloud.com.example.Ledger` to match (Xcode can create it for you under the
     iCloud → CloudKit capability).
3. Build & run on any of the four platforms.

If you're not signed into iCloud (or run without the CloudKit entitlement), the
app falls back to a local-only store so it still works for development.

## Fonts

The design calls for **Playfair Display** (headings) and **DM Mono** (numbers).
To keep the project buildable with zero bundled assets, these are approximated
with the system serif (New York) and system monospaced (SF Mono) faces. To use
the real fonts, add the `.ttf` files to the target, list them under
"Fonts provided by application", and swap the `Font.system(...)` calls in
`Theme.swift` for `Font.custom(...)`.

## Roadmap

The `Insights` tab is a first cut at reporting. Next candidates: budget rollover
of unspent buckets, Home/Lock Screen widgets, spending alerts, tags/sub-
categories, and richer charts (category trends, drill-down).
