# Widgets — implementation plan (for review)

Status: **planned, not built.** Widgets need a new Xcode target + an App Group
capability, which must be set up in Xcode (and tested), so we'll build this in a
guided session at the Mac. This doc is the plan to review first.

## Goal (v1) — finalized set

Three widget kinds, all reading one shared snapshot of the **current month**.
Tapping any of them deep-links into the app (Budget tab). No editing from the
widget in v1.

1. **Safe to Spend** — families: **small** (Home), **accessoryInline** +
   **accessoryRectangular** (Lock).
   - Hero = **safe to spend** = *remaining Needs + remaining Wants* (savings is
     reserved — the corrected definition; never counts unmet savings as
     spendable). Small adds a slim 3-segment bar of bucket usage; rectangular
     adds a one-line bucket readout; inline shows "Jun · $274 left".
2. **Buckets** — family: **medium** (Home).
   - Mini-Budget: Needs / Savings / Wants, each with spent/budget, a progress
     bar, and remaining. Over = red for Needs/Wants, sage when Savings exceeds
     its goal.
3. **Savings Goal** — families: **small** (Home), **accessoryCircular** (Lock).
   - A ring of **savings saved vs. goal** with the amount/percentage in the
     center. (Chosen over an "income used" ring.)

StandBy / iPad ride along automatically once Home + Lock widgets exist.

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
- Shape: `struct BudgetSnapshot: Codable` with `monthKey`, `monthName`,
  `safeToSpend`, and per-bucket `spent`/`budget` for Needs/Savings/Wants
  (progress bars + remaining are derived), plus `savingsRate` and `updatedAt`.
  The savings ring uses Savings `spent`/`budget`. Written by a small
  `SnapshotWriter` on save / month change / app background.

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
