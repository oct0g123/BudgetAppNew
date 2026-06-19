# Widgets — implementation plan (for review)

Status: **planned, not built.** Widgets need a new Xcode target + an App Group
capability, which must be set up in Xcode (and tested), so we'll build this in a
guided session at the Mac. This doc is the plan to review first.

## Goal (v1)
Glanceable Home Screen + Lock Screen widgets that show, for the current month:
- **Safe to spend** (income − total spent)
- **Buckets remaining** (Needs / Savings / Wants left)
- A **savings ring** (savings spent vs. goal)

Tapping a widget deep-links into the app. No editing from the widget in v1.

## Why this needs an Xcode session (not buildable blind)
1. **New Widget Extension target.** Created via Xcode → File → New → Target →
   Widget Extension. This edits the `.xcodeproj` in ways that are fragile to do
   by hand — you'll add it in the UI.
2. **App Group** shared between app + widget so the widget can read the data.
   Added as a capability on **both** targets (e.g. `group.com.anthonystacy.Ledger`).
3. **Shared store location.** The SwiftData store must live in the App Group
   container so both processes open the same database. Changing where the store
   lives is a data-migration-sensitive change — must be done with the ability to
   test, or existing local data can be orphaned.

## Data-sharing approach — two options

### Option A (recommended for v1): shared snapshot, not the live store
The app writes a tiny `Codable` summary (the few numbers the widget shows) into
the **App Group `UserDefaults`** whenever data changes. The widget reads that.
- **Pros:** simple, fast, robust; widget never touches SwiftData/CloudKit;
  **no store-location change → lowest risk** to the working app.
- **Cons:** widget shows only what we snapshot (fine for v1's glance numbers).
- Shape: `struct BudgetSnapshot: Codable { month, income, safeToSpend,
  needsRemaining, savingsRemaining, wantsRemaining, savingsRate, updatedAt }`,
  written by a small `SnapshotWriter` on save / month change / app background.

### Option B: widget opens the shared SwiftData store directly
Move the `ModelContainer` to the App Group container; the widget builds the same
container (read-only) and queries live.
- **Pros:** always current, no snapshot to maintain.
- **Cons:** **store-location migration** (risk), heavier widget, must handle
  CloudKit in an extension. Save for later if v1's snapshot proves limiting.

**Plan: ship Option A first.** It gets the widgets out with minimal risk; we can
graduate to B in 2.0 if needed.

## Build steps (the guided session)
1. **You, in Xcode:** File → New → Target → **Widget Extension** (name e.g.
   `LedgerWidgets`); uncheck "Include Live Activity" for v1.
2. **You, in Xcode:** add **App Group** capability (`group.com.anthonystacy.Ledger`)
   to **both** the app target and the widget target.
3. **Me (code, no project surgery):**
   - `BudgetSnapshot` + `SnapshotWriter` (writes to the App Group `UserDefaults`),
     called from the app on save / scene background. Lives in a file shared with
     both targets, or duplicated minimally.
   - Widget: `TimelineProvider` reads the snapshot; SwiftUI views for Home
     (small/medium) and Lock Screen (`.accessoryInline`, `.accessoryCircular`)
     using the existing design tokens.
   - Deep-link URLs (`ledger://budget`) handled in the app via `.onOpenURL`.
4. **You:** build the widget scheme to the phone, add the widget, verify it
   shows real numbers and updates after you add a transaction.

## Refresh behavior
- Widgets refresh on their own schedule (WidgetKit budgets timeline reloads).
- The app calls `WidgetCenter.shared.reloadAllTimelines()` after writing a new
  snapshot, so the widget updates promptly when the app is open.
- Lock Screen / StandBy support comes largely for free once Home widgets exist.

## Out of scope for v1 (later / 2.0)
- Control Center control + Action Button quick-add (App Intents).
- Interactive widgets (add a transaction from the widget).
- watchOS complications (separate target; shares the same snapshot idea).
