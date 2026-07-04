# Ledger — Deep Code Audit (pre/post v1.0)

Structured audit for **correctness, stability, performance, and extensibility**.
Nothing here is applied — each item logs the defect and the proposed fix so you
can triage. Findings are grouped by class and ranked most-severe first within
each group. Line numbers are approximate (they drift as the file changes).

**Severity legend:** 🔴 data loss / correctness · 🟠 wrong behavior · 🟡 perf /
churn · ⚪ polish / hygiene.

**Status — Wave 1 applied (2026-06-30):** B1, B2, B7, C1, D3, D4, D5, D7, D8 are
✅ fixed on the branch (low-risk mechanical set). Still open: the §A merge/dedupe
cluster (Wave 2, with F2), B3–B6, C2, D1, D2, D6, and the §F refactors.

> Context: most 🔴 items are **multi-device CloudKit races** — they need two
> devices (or one device + a re-install restoring from iCloud) to trigger, so
> they're invisible in single-device TestFlight but real once the app has users
> syncing across iPhone/iPad/Mac. None block the current v1.0 (single-device is
> safe); they should land before the app has a meaningful multi-device install
> base. All are good **v1.0.1 / v1.1** candidates.

---

## A. Data-integrity: the dedupe/merge subsystem (🔴)

These share one root cause: `mergeDuplicates` reconciles CloudKit duplicates
using **non-deterministic tie-breaks** and **id-only** matching, run
independently on each device. When two devices disagree on the "winner," their
deletions both sync and compound. The deeper fix (see §F) is deterministic
record identity so this subsystem mostly disappears.

### A1 🔴 `dedupeTransactions` can delete *both* copies of a transaction across devices
`LedgerService.swift:~192`. The survivor is "first seen" while iterating
`month.txns`, but a SwiftData to-many relationship has **no defined order** — it
varies per device/launch. Two devices each keep a *different* copy of the same
`id` and delete the other; both deletions sync → the transaction vanishes.
**Fix:** choose the survivor deterministically — e.g. sort the id-group by
`persistentModelID` (or `createdAt`, or a stored ordinal) and always keep
`.first`, so every device converges on the same survivor.

### A2 🔴 `mergeDuplicateMonths` can delete *both* month records, orphaning all their transactions
`LedgerService.swift:~166`. Canonical = "most transactions," but during sync
month records typically arrive **before** their transactions. Device A sees its
own June (10 txns) next to B's just-synced empty June; B sees the mirror image.
Each picks *its own* as canonical and deletes the other → after sync both June
records are gone, and transactions that arrive later point at a deleted month
(`txn.month == nil`), so they never appear in any view (all UI reads
`month.txns`). Silent, permanent-in-practice loss from ordinary two-device use.
**Fix:** canonical month = deterministic key that doesn't depend on
relationship-fault timing (earliest `createdAt`, tie-broken by
`persistentModelID`); never delete a month that still owns transactions —
reparent first, then delete only if empty; consider deferring month-merge until
an import batch settles.

### A3 🔴 Recurring rule double-materializes across devices → permanent double charge
`LedgerService.swift:~79` (`applyRecurringRules`). The `existingRuleIDs` guard is
**local-only**. On the 1st, both phones call `ensureMonth` and each materializes
Rent with a *fresh* `Transaction.id` (same `recurringRuleID`). After sync the
months merge, but `dedupeTransactions` compares only `txn.id` → both Rent rows
survive → the month shows Rent twice forever.
**Fix (root):** give materialized recurring transactions a **deterministic id**
derived from `recurringRuleID + monthKey` (e.g. a UUID hashed from that seed, the
same trick already used for legacy import in `ImportExport.deterministicUUID`).
Then both devices produce the *same* id and normal id-dedupe collapses them.
This also fixes A1 for recurring rows. **Additionally:** `dedupeTransactions`
should collapse rows sharing `(recurringRuleID, month)` even if ids differ, as a
belt-and-suspenders.

### A4 🔴 `mergeDuplicateSettings` can delete *all* settings rows → income reset
`LedgerService.swift:~158`. Unsorted fetch; keep = `first(where: income != 0) ??
all[0]`. If both duplicated rows are configured (both devices set income before
first sync), each device prefers its own and deletes the other → zero rows remain
→ `settings(in:)` recreates a default row with `defaultIncome = 0`, silently
wiping the user's income and split.
**Fix:** deterministic keep (earliest `persistentModelID`); merge fields from the
loser into the survivor before deleting; never delete the last row.

---

## B. Import / restore & intent correctness (🟠, one 🔴)

### B1 🔴 Any JSON file "imports" as an empty archive and clobbers settings
`ImportExport.swift:31` + `LedgerService.swift:~227`. Every `ExportData` field is
`decodeIfPresent(...) ?? default`, so `decodeJSON("{}")` — or *any* unrelated
JSON object the user picks by mistake — succeeds with `months: []` and default
settings. `importArchive` then unconditionally sets `defaultIncome = 0` and the
split to 50/20/30. Wrong-file import silently resets the user's defaults, imports
nothing, shows no error.
**Fix:** require a Ledger fingerprint before treating a decode as valid — e.g. a
recognized top-level key (`version` present, or `months`/`settings` actually
present as keys, not defaulted). In `decodeAny`, if neither the legacy shape nor a
*keyed* native shape matches, throw so the UI shows "Not a Ledger backup." Don't
overwrite settings when `months` is empty and no settings key was present.

### B2 🟠 JSON backup drops `recurringRuleID` → restore can double-count rules later
`ImportExport.swift:125` (`TransactionDTO` has no `recurringRuleID`) and
`LedgerArchive.makeExport` / `importArchive` never carry it. After a
backup→restore, materialized recurring rows lose their rule link; a later
`applyRule` / new-month creation no longer sees them via `existingRuleIDs` and
re-materializes → duplicates.
**Fix:** add `recurringRuleID` to `TransactionDTO` (encode + decodeIfPresent for
back-compat) and set it on import.

### B3 🟠 CSV import double-counts recurring rules on a *first* import
`LedgerService.swift:~282`. `importCSVTransactions` → `ensureMonth` →
`applyRecurringRules`, which materializes active rules into each created month —
*on top of* the CSV's own historical copies of those charges. Distinct from the
known "re-import duplicates" issue; this fires on the first import when rules
already exist (e.g. synced from another device). `importArchive` (JSON) builds
months directly and doesn't have this.
**Fix:** import CSV months with rule-materialization suppressed (a variant of
`ensureMonth` that skips `applyRecurringRules`), or dedupe by
`(recurringRuleID|desc+amount, month)` after import.

### B4 🟠 Siri "Add Transaction" writes into a *closed* month, invisibly
`LedgerService.swift:~770` (`AddTransactionIntent.perform`). It calls
`ensureMonth(MonthKey.current)` and adds with no `isClosed` check. If the user
closed the current calendar month early (exactly the flow behind the widget bug),
Siri silently files the transaction into a closed month that the Budget UI hides.
**Fix:** if the current month is closed, either target the next open month
(mirror the widget's "active month" logic) or return a spoken "This month is
closed — reopen it to add transactions."

### B5 🟠 New-transaction sheet doesn't re-home a cross-month date (edit path does)
`AddTransactionView.swift:~122`. The edit path now re-homes when the date's month
changes (commit `ddd78ab`), but the **new**-transaction path pins the txn to the
sheet's `month` regardless of the picked date. Add a transaction dated in June
while viewing July → it's counted in July with a June date.
**Fix:** apply the same `MonthKey.key(for: date)` re-home in the create branch —
or factor both branches through one "place transaction in the month its date
belongs to" helper.

### B6 🟠 Editing a recurring rule's amount doesn't update the current month's already-added charge
`RecurringView.swift:~205` → `LedgerService.applyRule`. Editing Rent $1800→$2000
and saving re-runs `applyRecurringRules`, which only **inserts** missing rows and
skips months that already contain the rule (`existingRuleIDs`). So the open month
keeps the old $1800 row; only future months get $2000. This contradicts the UI's
own footer ("Editing… never changes closed months," implying it *does* change open
ones) and user expectation.
**Fix:** when a rule is edited, update the matching materialized transaction in
each **open** month (match by `recurringRuleID`) — amount, category, and date
(day) — rather than only inserting missing ones. Decide explicitly whether
deleting/pausing a rule should also remove the open month's charge (currently it
doesn't; document or fix to match intent).

### B7 🟠 Heuristic command-bar parser reads "$1,200" as $1
`LedgerService.swift:~610`. `amountPattern = #"\$?\s?\d+(?:\.\d{1,2})?"#` stops at
the thousands comma, so `firstAmount("rent $1,200")` = 1.0 and the note is
mangled. This is the fallback used on every device *without* Apple Intelligence —
i.e. exactly the US-formatted input a US-only launch will see. Distinct from the
known `MoneyField` comma-*decimal* locale bug.
**Fix:** allow grouping in the pattern (`\$?\s?\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?`)
and strip commas before `Double(...)`.

---

## C. Widget / shared-state (🟠 / ⚪)

### C1 🟠 `resetAllData` leaves a stale widget snapshot forever
`LedgerService.swift:~301` + `BudgetSnapshotStore.update:~368`. Reset empties
SwiftData but never clears the App Group snapshot, and `update(from: [])` returns
at its `guard let month`. The Lock/Home Screen widget keeps showing the wiped
budget's income/spend indefinitely — also a mild privacy leak on a handed-off
device.
**Fix:** in `resetAllData` (or `performReset`), remove the snapshot key from the
App Group defaults and call `WidgetCenter.shared.reloadAllTimelines()`; make
`update` clear the key when it has no month to show.

### C2 🟠 `MoneyField` commits to the model on every keystroke → CloudKit export churn + transient synced values
`BudgetView.swift:~281` (`month.income`) and `SettingsView.swift:~227`
(`settings.defaultIncome`). Each keystroke writes the model → autosave → CloudKit
export. Typing "7000" persists and syncs 7, 70, 700, 7000; other devices and the
widget snapshot can briefly capture the intermediate value.
**Fix:** bind `MoneyField` to local `@State` and commit to the model on
end-editing / submit (or debounce ~0.5s). Applies to both income fields.

---

## D. Performance (🟡) — remaining hot spots after the Settings-hang fix

The 30s Settings hang is fixed; these are the next tier, all main-thread and all
scaling with months × transactions.

### D1 🟡 `mergeDuplicates` faults the whole store on the main thread, re-fired per sync batch
`LedgerService.swift:~148`, triggered from `RootView.swift:71–92` (`.task`,
every `scenePhase == .active`, **and** `.onChange(of: months.count)`). It fetches
all months twice and iterates `month.txns` for every month (faulting all
transactions) plus a main-thread `context.save()`. A first CloudKit import
delivers months in batches; each batch changes `months.count` → re-runs the whole
pass, and the save itself deletes months → changes count → re-enters. At 60
months × 200 txns that's ~10 full-store faulting passes (~120k faults) during
launch.
**Fix:** cheap precheck first (fetch only `MonthRecord.key` via
`propertiesToFetch`, bail if no duplicate keys and settings count ≤ 1); debounce
the `months.count` handler (~2s after the last change); run the merge on a
background `ModelContext`.

### D2 🟡 `BudgetSnapshotStore.update` + `reloadAllTimelines` fired from 3 reactive hooks, unconditionally
`LedgerService.swift:~384`, from `RootView.swift:74/84/91`. The scenePhase hook
runs on *every* transition (it's outside the `.active` check → 2+ per app switch);
the count hook fires per import batch. Each call re-encodes JSON and reloads
timelines even when bytes are identical. WidgetKit throttles reload bursts →
a real later edit may not reach the Lock Screen for hours.
**Fix:** skip the write + reload when the freshly-encoded snapshot equals the
stored bytes; debounce the import-burst path; only reload on real change.

### D3 🟡 `HistoryView` builds every month card eagerly, each rescanning its txns ~6×
`HistoryView.swift:~27`. `ScrollView` + plain `VStack` + `ForEach(months)` — not
lazy, so all 60 cards build on first open; each does ~6 `spent`/`totalSpent`
scans and 4–5 `Money.string` formatter allocations, plus `totalSaved` reduces
across all months.
**Fix:** `LazyVStack` (one-word change → only visible cards build); compute each
card's per-category totals in a single pass instead of repeated `spent(for:)`.

### D4 🟡 `InsightsView` recomputes `recentMonths` (~5×) and `buildInsight()` (3×) per render
`InsightsView.swift:~19` and `~247`. `recentMonths` is a computed property that
filters all months calling `totalSpent` (faults every txn) and is read ~5× per
body pass; `insight` is a computed property so `buildInsight()` runs once each for
`headline`/`observations`/`suggestion`.
**Fix:** compute `let recent = recentMonths` and `let insight = buildInsight()`
once at the top of `body`; or cache per-month aggregates.

### D5 🟡 `Money.string` (and widget `widgetMoney`) allocate a `NumberFormatter` per call
`Theme.swift:~14`, `LedgerWidgets.swift:~44`. `NumberFormatter` init is
ICU-backed and expensive; it's called once per `TransactionRow`, ~4× per
`BucketRow`, in the always-mounted `SafeToSpendBar`, and 8× per widget render
(inside the memory-capped extension).
**Fix:** one `static let` cached formatter per target (optionally reset on
`NSLocale.currentLocaleDidChangeNotification`).

### D6 🟡 Unpredicated all-months `@Query` in three simultaneous places to render one month
`RootView.swift:28`, `SafeToSpendBar` `RootView.swift:~131`, `BudgetView.swift:18`.
Each queries **all** `MonthRecord`s (faulting cascades) and linear-searches for
`viewedKey`. `SafeToSpendBar` is the tab accessory → mounted on all four tabs and
re-renders whenever *any* month/txn changes (including years-old months syncing).
**Fix:** predicate the query on `key == viewedKey` via an `init`-injected
`#Predicate`, so only the visible month is fetched and observed.

### D7 🟡 `filteredTransactions` re-filters + sorts on every keystroke
`BudgetView.swift:~377`. Each character re-renders the body → two filter passes +
`sorted` over `month.txns`, allocating a lowercased string and re-parsing
`category` per txn; `onDelete` recomputes it too.
**Fix:** debounce the query (`.task(id: searchText)` ~250ms), precompute
lowercased descriptions, sort once and filter the sorted array.

### D8 🟡 `relativeTime` allocates a `RelativeDateTimeFormatter` per sync row
`SettingsView.swift:~410`. Now correctly scoped to the Advanced screen, but with
that screen open during a sync, 3 rows × many CloudKit events = many ICU
formatter inits.
**Fix:** one `private static let` formatter.

---

## E. Hygiene (⚪)

- **Stale `enableCloudKitSync` guidance.** `LedgerApp.swift:7–17,143` — the big
  "flip to true when you have a paid account" comment predates sync being on
  (`= true`). Trim to avoid future confusion. (Already noted in roadmap.)
- **`MonthKey.offset` negative-year math** (`MonthKey.swift:49`) uses truncating
  division; only wrong for year ≤ 0, unreachable with real dates. Leave as-is or
  add a comment.

---

## F. Extensibility — can we build the roadmap on this?

**Short answer: yes, comfortably, with two structural investments worth making
before the bigger v1.5 features.** The core model (per-month records owning
transactions, per-month split, string month keys) is clean and the roadmap items
mostly slot in. Two places will otherwise force you to touch many call sites:

### F1 — A single mutation chokepoint (unblocks recap, alerts, rollover, widget)
Today, three concerns are wired ad hoc at each call site: `BudgetAlerts.evaluate`,
`BudgetSnapshotStore.update`, and (implicitly) "which month is active." Every new
mutation path (Siri, command bar, import, a future watch app) has to remember all
three — and some already forget (B4: Siri skips the closed-month guard; several
paths skip the snapshot update). Route all writes through one
`LedgerService.commit(...)` that performs the mutation, evaluates alerts, and
refreshes the snapshot **once**. This directly enables:
- **End-of-month recap / budget rollover** — both hook "month close"; today
  `closeMonth` is one function but the surrounding logic is spread across views.
  One close path = one place to add the recap trigger and the rollover carry.
- **Adjustable alert threshold** — trivial once `BudgetAlerts` isn't duplicated
  ad hoc (swap the `0.80` constant for a stored value).

### F2 — Deterministic record identity (unblocks reliable sync + eliminates §A)
The entire dedupe/merge subsystem (§A, ~70 lines of fragile reconciliation) exists
because records lack stable natural keys. Deterministic ids —
`monthKey` as the month's identity, `recurringRuleID+monthKey` for materialized
rows — let CloudKit's own last-writer-wins converge without custom merge, and make
**CSV stable IDs** (a roadmap item) fall out for free.

### Roadmap items — difficulty on today's architecture
| Item | Fits today? | Note |
|---|---|---|
| End-of-month recap | ✅ easy | Needs F1 (one close path); data all present. |
| Month-over-month reporting / drill-down | ✅ easy | `spent(for:)` per month exists; add caching (D3/D4) so it's cheap. |
| Budget rollover | 🟠 medium | Needs F1 + a "carry" field on `MonthRecord`; model change → CloudKit re-deploy. |
| Adjustable alert threshold | ✅ trivial | Store a Double, replace the constant. |
| Watch complications | 🟠 medium | Reuses `BudgetSnapshot` — but it's **duplicated** across app+widget already; a 3rd copy hurts. Move it to one file shared by all targets first. |
| 3-D visionOS charts | ✅ easy | Additive view; data ready. |
| **Currency picker** | 🟠 medium | Money formatting is scattered (D5) and hardcodes `Locale.current`. Centralize into one `CurrencyStyle` first (also fixes the known comma-decimal `MoneyField` bug). |
| Non-US locales | 🟠 medium | Same `CurrencyStyle` centralization + the `MoneyField` parse fix (known). |
| CSV stable IDs | ✅ easy | Falls out of F2. |
| Purchase-type tags (5c) | 🟠 medium | `BudgetCategory` is a fixed enum; tags want a free-form field on `Transaction` — additive model change, not a rewrite. |

**Bottom line:** nothing in the roadmap is blocked or requires a rewrite. Doing
**F1 (mutation chokepoint)** and **F2 (deterministic ids)** early pays for itself
by erasing the §A bug class and de-risking every feature that touches money
mutations or sync. The `BudgetSnapshot` duplication and scattered money
formatting are the two "touch it before it multiplies" cleanups.

---

*Method: 9 parallel finder angles (line-by-line, state/lifecycle, cross-file,
language pitfalls, mirror-drift, reuse, simplification, efficiency, architecture)
+ a gap sweep, findings verified against the source. Conventions angle skipped
(no CLAUDE.md in repo).*
