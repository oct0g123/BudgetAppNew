# Ledger — Roadmap

A living list of where the app is and where it's going. Not a commitment to
order or scope — just so good ideas don't get lost.

The plan is split into **1.0** (what we're building now — a polished, single-user
app across Apple platforms) and **Ledger 2.0** (deliberately deferred: bigger,
multi-user, or better-served-later ideas).

## Open decisions (1.0)

Revisit before final polish / before building the related feature:
- ✅ **Budget page header — Option A implemented (2026-07-06), verify on device.**
  Chosen: left-aligned serif month + trailing grouped chevron pair (confirmed
  HIG-native — it's the system date-picker / UICalendarView layout); search
  relocated to sit directly above the transaction rows; income/category cards
  no longer hide while searching (results now appear under the field
  naturally). If the trailing chevrons still feel disconnected on device:
  optional bridge = make the month label tappable (▾ jump-to-month menu), or
  fall back to a tight-flanking `‹ July 2026 ›` cluster. Original diagnosis
  and Option B kept below for reference.
- ⚠️ **Budget page header — redesign options (diagnosed 2026-07-06, on hold).**
  Why it feels off: (1) *two stacked titles* — "Budget" (redundant with the tab
  bar) competes with "July 2026," so the biggest text carries the least info;
  (2) *unanchored month row* — centered text with chevrons pushed to the far
  edges = three small elements floating in space; spread chevrons read as
  whole-screen page-flippers, not a month control; (3) *search squats in the
  hero slot* between header and money, far from the transactions it searches.
  - **Option A (recommended, conservative):** keep the "Budget" large title;
    month row becomes left-aligned serif "July 2026" with the two chevrons
    **grouped side-by-side at the trailing edge** (Calendar/Health pattern);
    move search down to sit directly above the transaction rows (which also
    makes the hide-cards-while-searching workaround mostly unnecessary);
    tighten vertical gaps so title → month → income reads as one header block.
    Same bare-List structure — no `safeAreaInset` risk.
  - **Option B (bolder):** drop the "Budget" large title entirely; "July 2026"
    *is* the large title, chevrons in the same row. Maximal cleanup but changes
    the tab's feel; try A first.
  - Mockup of both options was produced for comparison (see session artifact).
  (Pinning the month selector was abandoned — `safeAreaInset` + a collapsing
  large title is broken on this OS; revisit only if a clean approach appears.)
- **Font:** keep Playfair Display, or revert headings to the system serif
  (New York)? One-line change in `Typography.serif`. Decide near the end.
- 💰 **Monetization: $0.99 paid vs. free + tip jar** *(decided 2026-07-06:
  wait for data, lean tip-jar)*. Revenue is coffee money either way at this
  scale, so decide on distribution + brand, not income:
  - **The plan:** keep **$0.99 for the first 2–4 weeks** post-launch and watch
    real download numbers. Paid→free is instant (no review) and one-way in
    practice (free→paid angers people), so walk through it with data.
  - **Flip criteria:** if downloads are anemic without marketing (likely),
    go **free + tip jar** in v1.1/v1.2. Free supercharges the ratings→rank
    flywheel, softens reviews, and especially helps the Mac/visionOS launches
    (Vision Pro owners try any free app in a thin catalog).
  - **Why tip jar fits the brand:** "no ads, no tracking, not trying to sell
    you anything" — the Overcast patronage model is the monetization that
    matches the pitch. A subscription would contradict it outright.
  - **Tip-jar design sketch (~a day):** three *consumable* IAPs in ASC
    ($1.99 / $4.99 / $9.99 — "Nice / Generous / Lavish tip"), StoreKit 2
    (consumables = simplest IAP, no restore needed), a warm "Support Ledger"
    screen in Settings: *"Ledger has no ads, no subscriptions, and never
    will. If it's helped you, a tip keeps it that way."*
  - **Expectations check:** tip conversion is ~0.5–2% of users, mostly
    once — it's a goodwill channel, not a business model.
  - ✅ Verify enrollment in the **App Store Small Business Program** (15%
    commission instead of 30%) — applies to paid and tips alike.
  - Early $0.99 buyers won't mind a later switch to free at this price point.
- **Purchase types (Phase 5c):** persistent stored sub-category tags (richer:
  filter/chart/trend by type) vs. AI narrative-only (lighter, nothing stored).

---

## Release plan (phased launch)

Shipping in stages to keep each release low-risk and scoped.

### v1.0 — iOS only, US App Store  🎉 **LIVE on the App Store** *(approved 2026-07-06)*
First public release: **iPhone + iPad, US availability only.**
- **Scope lock:** iOS only (Mac/visionOS deferred to 1.1) and **US-only** — the
  US-only choice also sidesteps the locale money-input bug below at zero code risk.
- ✅ Privacy policy hosted (GitHub Pages) + URL set in App Information.
- ✅ Screenshots (6.9" iPhone + 13" iPad, from the Simulator).
- ✅ Metadata, copyright, pricing ($0.99), App Privacy → Data Not Collected.
- ✅ Tax/banking (Paid Apps Agreement active), CloudKit schema promoted to
  Production (Jun 20).
- ✅ Build 3 archived ("Any iOS Device") + uploaded; attached to the version;
  submitted Jun 30 → **approved and released Jul 6.**
- **Now:** real-user smoke test of Wave 1 + the two TestFlight fixes (widget
  active-month, Settings allocation hang) — see v1.0.1 below.
- Carried into a later release (not blockers): Budget-page design sweep, font
  decision (see Open decisions).

### v1.0.1 — fast-follow  ✅ **SHIPPED — approved** *(2026-07-07)*
Contents: audit Wave 1 + widget active-month fix + Settings hang fix + Budget
header redesign (Option A). ⚠️ *Not included (on the branch, ship with the next
release):* empty-state month alignment, Insights entrance animation, Settings
version row. ⚠️ *Verify:* was the new keyword string pasted into 1.0.1? If not,
it rides the next version.
Original punch list:
- ✅ **Audit Wave 1** (see `docs/code-review-v1.0.md`): thousands-separator
  parse fix ("$1,200" → $1), import validation (wrong JSON no longer clobbers
  settings), backups now round-trip `recurringRuleID`, reset clears the widget
  snapshot, cached formatters (app + widget), lazy History list, Insights
  compute-once, search debounce.
- ✅ **Wave 2 built AND soak-tested (2026-07-08, two-device TestFlight,
  airplane-mode conflict recipes):** CloudKit merge/dedupe integrity cluster
  (§A) + deterministic record IDs (§F2). Results: duplicate-transaction race
  → **no dupes after the update** (dupes reproduced on the pre-update build,
  confirming both the bug and the fix); income-change conflict → the offline
  device **converged to the change on reconnect**. Shipping in 1.1 (build 1,
  on TestFlight). See `docs/code-review-v1.0.md` for mechanisms.
- ✅ **Review prompt built (2026-07-07, on branch):** one-time `requestReview()`
  1.5s after the user closes their first month; flag-guarded; ships next release.
- ✅ **Widget tracks the active budgeting month** (closing a month early no longer
  freezes the widget on it) — committed, not in the launch build.
- ✅ **~30s Settings hang when changing allocation %** — committed. Root cause:
  `SettingsView` observed `SyncMonitor` at its root, so a split write's CloudKit
  export/import event burst rebuilt the whole Settings form (steppers included)
  on the main thread. Fixed by scoping the observation to a `SyncStatusSection`
  subview on the Advanced screen. (Found via TestFlight + a focused code trace.)
  - Secondary optimizations surfaced by that trace, not yet done (lower risk to
    defer): (a) `mergeDuplicates` runs a main-thread `context.save()` on the
    reactive `onChange(of: months.count)` path — move off/​debounce to avoid a
    CloudKit-echo ping-pong; (b) `MonthRecord.spent(for:)` re-scans all txns on
    every call — cache per-category spend.
- **Review prompt (`requestReview`)** — small, high-leverage for App Store
  ranking (ratings count/velocity outweighs keyword tuning). Trigger at a
  natural success moment: after the user **closes their first month** (guard
  with a "hasPromptedReview" flag; Apple caps prompts at 3/year and decides
  whether to actually show it, so one well-placed call is enough). Pairs
  naturally with the future recap sheet — prompt after the recap is dismissed.
- **Updated keyword string** — ships with this version (keywords only change
  via version update); paste from `appstore/app-store-metadata.md`.
- Sweep in any other early TestFlight/launch feedback before cutting the build.

### v1.1 — macOS + visionOS  🚧 **builds uploaded — metadata + submit pending** *(2026-06-30)*
Both platform builds are archived and uploaded to App Store Connect; remaining
work is the per-platform metadata/paperwork, then submit + simultaneous release.
- **visionOS:** ✅ build uploaded; **layered app icon validated by App Store
  Connect** (`AppIconVision.solidimagestack`, 3-layer parallax, wired via
  `ASSETCATALOG_COMPILER_APPICON_NAME[sdk=xros*]`). Remaining: visionOS metadata
  + screenshots → attach build → submit. (Layer art can be refined later.)
- **macOS:** ✅ build uploaded; **icon fixed** — full macOS size set (16–1024px,
  rounded-rect) added to `AppIcon` to clear upload error 90236. Widget
  dark-palette bug ✅ fixed. Remaining: macOS metadata + screenshots → attach
  build → submit. (Optional later polish: Apple-style drop shadow on the Mac icon.)
- **Release together:** set all three platforms to **"Manually release this
  version"** (incl. iOS, already in review) so they go live at the same time once
  the last is approved.
- Each platform = its own archive + its own App Store Connect platform tab +
  its own TestFlight section, under the same app record.

### v1.2 — "the month-close release" (planned shape, ~3–4 build days)
Theme: make closing a month the emotional core of the app; clear the behavior
backlog. No CloudKit schema changes anywhere in this list.
- **End-of-month recap** (headliner, ~1 day; design done — see Reporting):
  shared `RecapView` on the `buildInsight()` engine; close-month sheet +
  History archive + Insights (already live). Make it screenshot/share-worthy.
  ⚠️ decision: History card tap → recap sheet (recommended) vs. keep
  tap-to-Budget.
- **Review prompt moves into the recap flow** (trivial): close → recap →
  dismiss → rating ask, at peak accomplishment.
- **Weekly safe-to-spend pacing** (~half day; see Core features): remaining
  Needs/Wants ÷ time left. ⚠️ decisions: weekly vs daily cadence; live vs
  fixed-at-week-start.
- **Adjustable alert threshold** (~30 min): 75/80/90 slider replaces the
  constant.
- **Wave-3 behavior fixes** (~half day, from the audit): Siri closed-month
  redirect (B4) · rule edits update the open month's charge (B6) · MoneyField
  commits on end-editing (C2).
- **Conditional — monetization flip** (~1 day): if the download-data window
  says free + tip jar, it lands here (price → $0, 3 consumable IAPs,
  "Support Ledger" screen).
- Filler if needed: widget snapshot skip-identical-writes (D2), predicated
  month queries (D6).

### v1.5 — advanced features
After the platforms are out, pull a focused few from the sections below
(reporting, budget rollover, watch complications, adjustable alert threshold,
native 3-D visionOS charts, …).

---

## Pre-launch code-review findings (triage)

From a full-app high-recall review. Verdicts: ✅ fixed · 🇺🇸 handled by US-only ·
1.1 / later = deferred.

- ✅ **Action-Button quick-add was dropped on cold launch** — fixed (ensures the
  month exists before presenting).
- ✅ **Search was narrowed by a leftover category filter** — fixed (filter ignored
  while searching + pills hidden).
- 🇺🇸 **Money input corrupts in comma-decimal locales** (`MoneyField`) — *not*
  fixed in code; **avoided by shipping US-only in 1.0.** ⚠️ MUST fix before any
  non-US release.
- ~~**1.0 if quick** — Editing a transaction's date across months leaves it
  counted under the original month.~~ ✅ **Fixed** — the editor now re-homes the
  transaction to the destination month (creating it if needed) when the edited
  date's month-key changes.
- ~~**1.1** — macOS widgets always render the dark palette~~ ✅ **Fixed** —
  `adaptive(light:dark:)` now resolves via an AppKit dynamic NSColor on macOS
  instead of pinning to the dark hex.
- ~~**Widget shows the wrong month when you close the current month early**~~
  ✅ **Fixed** (found in TestFlight) — the widget snapshot was built strictly for
  the real calendar month, so closing e.g. June on the 30th and advancing to July
  left the widget frozen on closed June and ignoring July edits. It now follows
  the current calendar month when open, else the next open month. **Not in the
  in-review 1.0 build** — rolls into the next build (1.0.1 / the platform rebuilds).
- **1.1 / later** — **CSV re-import duplicates everything** (needs stable IDs;
  JSON backup is unaffected; low frequency).
- **later (minor/rare):** enabling Face ID doesn't lock until next background ·
  theme switch resets other tabs' scroll/nav (`.id` rebuild trade-off) · CloudKit
  merge edge cases (reopened month re-closed by stale dup; settings-merge
  tiebreak) · CSV newline-in-description round-trip · stale `enableCloudKitSync`
  comment in `LedgerApp`.

**Verified clean:** budget-alert logic, bucket/over colors, Advanced-settings
presentation, SyncMonitor (no leaks/cycles), widget snapshot mirror + App Group
naming, division-by-zero guards, no crashes/force-unwraps. No happy-path data
corruption.

---

## Where we are

**Shipped (working):**
- Native SwiftUI multiplatform app (iOS, iPadOS, macOS, visionOS), SwiftData store
- 50/30/20 budgeting: monthly income auto-split into Needs/Savings/Wants with
  live progress bars
- Per-month allocation split (custom %, presets); historical months keep their
  own split
- Transactions: add / **edit** / delete, **undo on delete**, category filter,
  month navigation, **close & reopen** month archiving
- Recurring transactions (monthly templates, auto-materialized) + a **quick
  "repeat monthly" toggle** on the add sheet
- Insights tab (Swift Charts): savings rate, spend-by-category, budget vs actual
- History tab: per-month summaries; **tap a month to jump to it**
- JSON + CSV export/import, with auto-detecting import of the original web app's
  backup format
- **Reset all data** (Settings → Danger Zone): one confirmed action wipes every
  month, transaction, recurring rule, and settings — clears all iCloud devices —
  and drops back into onboarding for a clean start
- **Themes** (Settings → Appearance): switch the whole app between **Ledger**
  (the original editorial gold/serif look), **Minimal** (quiet monochrome), and
  **Modern** (clean, system colors). Each ships its own light + dark palette and
  follows the system appearance. All colors resolve through `DS`/`Typography`
  against the active `ThemePalette` (Theming.swift) — zero call-site churn,
  cached per switch (no runtime cost)
- **iCloud/CloudKit sync (enabled):** cross-device sync of the SwiftData store,
  an in-app **sync status panel** (last received/sent + errors), and automatic
  **merge of duplicate months/settings** created across devices before sync
- **Home & Lock Screen widgets:** Safe to Spend, Buckets, and Savings Goal —
  fed by a shared App Group snapshot; tap to open the current month.
- **AI command bar (5a) — "Tell Ledger":** on-device Apple Foundation Models
  parse plain English into draft transactions → preview/edit → confirm. Gated to
  Apple-Intelligence devices, regex fallback, and **learns your merchant→category
  choices** (local) to pre-fill next time

### UI redesign status (Liquid Glass + light/dark)
Direction: "native bones, custom skin" — editorial identity (gold, serif, earth
tones) on standard platform components, so Liquid Glass + cross-platform
consistency come for free.

- [x] **Phase 1 — Foundation:** design system (adaptive colors, Dynamic
      Type-aware typography, layout tokens)
- [x] **Phase 2 — Native structure:** real nav bars, `Form`/`List`, native
      sheets, light + dark
- [x] **Phase 3 — Liquid Glass accents:** floating glass filter bar, floating
      glass add button, tab-bar "safe to spend" accessory + minimizing tab bar
      - [ ] Pinned "scrolls-under" filter bar (deferred — low priority)
- [~] **Phase 4 — Identity polish:** bundled Playfair + DM Mono, chart styling,
      haptics, animations all done
      - [ ] Final palette tuning pass
      - [ ] Font decision (see Open decisions)

---

# Ledger 1.0 — building now

## Phase 5 — On-device intelligence (Apple Foundation Models)

Use Apple's on-device LLM (Foundation Models, iOS/macOS 26+) for private,
offline, no-cost AI. **Core principle: the model extracts structured data and
writes prose; Swift validates, computes, and mutates. The LLM never does
arithmetic or directly changes the ledger.**

Cross-cutting architecture (established in 5a):
- `IntelligenceService` isolates all model use; gate on
  `SystemLanguageModel.default.availability` so AI UI only appears on supported
  devices. Manual flows always remain.
- Guided generation with `@Generable` structs (no JSON parsing).
- Privacy is a feature: 100% on-device — surface a "processed on your device" note.
- Prewarm + reuse the session; cache per-month results and regenerate on change.

WWDC26 notes (tooling lands a few months out):
- **Private Cloud Compute** — a bigger, still-private Apple model, and the
  ability to plug in external providers (Claude/Gemini). An *option* for deeper
  insights (5b/5d) if on-device isn't enough — see 2.0.
- **Evaluations Framework** — adopt to verify the parser/insights across inputs.
- **Dynamic Profiles** — swap model/tools/instructions mid-session; handy for 5d.

Decisions made: preview + confirm before applying ✅ · command scope = adding
transactions ✅ · purchase-type tags (5c) = undecided (see Open decisions).

- [x] **5a — Command bar ("Tell Ledger")** — shipped. Uses the on-device model
      for structured extraction (its strength), with a regex fallback +
      merchant-category learning.
- [x] **5b — Monthly summary (Insights tab)** — shipped, but **deterministic
      (Swift-computed), not model-generated.** We tried the on-device model and
      it was unreliable for factual financial prose: wrong arithmetic, swapped
      categories, and the safety **guardrail frequently refused budget content**
      ("may contain sensitive content") even when fed anonymized percentages.
      Lesson: the small on-device model is great at *extraction* (5a) but not at
      *generating accurate financial commentary*. Revisit AI prose here only if a
      bigger model (PCC) or a future OS with relaxed guardrails makes it reliable.

> **5c and 5d are deferred to 1.5 / 2.0** (see Ledger 2.0). 5c (finer purchase
> types) is held intentionally — the **three-bucket simplicity (Needs / Savings
> / Wants) is a core part of the app's identity**. 5d (Q&A) is gated on Private
> Cloud Compute. So Phase 5 in 1.0 is effectively **done** (5a + 5b shipped).

## Platform expansion

Glanceability is the real win for a budget app. These share infrastructure —
an **App Group + the CloudKit-synced store**. Order: iOS widgets → watch
complications → watch app → App Intents. Effort tags: (S)mall/(M)edium/(L)arge.

**iOS — widgets & system integration**
- [x] **Home Screen widgets — shipped.** Safe to Spend (small), Buckets
      (medium), Savings Goal ring (small). A `LedgerWidgets` extension reads a
      `BudgetSnapshot` the app writes to the App Group `group.com.anthonystacy.Ledger`.
- [x] **Lock Screen widgets — shipped.** Safe to Spend inline + rectangular,
      Savings Goal circular. (StandBy rides along.)
- (S–M) Control Center control + Action Button: one-tap "Add Transaction"
  deep-link, or remaining-budget readout
- (S) **"Add Transaction" widget** 📌 *pinned* — a one-tap Home/Lock Screen
  button that opens the add sheet via deep link (widgets can't take text input,
  so it launches the app rather than capturing inline). Deliberately deferred:
  it overlaps the existing Spotlight/Siri quick-add shortcut, so it's
  low-priority polish for whenever home-screen one-tap-add is wanted.
- (M) **App Intents / Siri / Shortcuts / Spotlight** ← **up next** ("how much is
  left?", "add $12 groceries"). WWDC26: App/Entity/Intent Schemas, View
  Annotations, Spotlight semantic index. Validate with AppIntentsTesting.

**iPadOS & macOS — already native**
- [x] **Runs natively on iPad and Mac today.** The app target is
      `TARGETED_DEVICE_FAMILY = "1,2,7"` (iPhone/iPad/Vision Pro) +
      `macosx`, and `RootView` uses `.tabViewStyle(.sidebarAdaptable)`, so iPad
      and Mac get a real sidebar layout for free.
- [x] **Themes work on iPad + Mac** — `DS`/`Typography`/`ThemeManager` are
      platform-agnostic and `Color(light:dark:)` has an AppKit branch, so all
      three themes (and light/dark) apply on every platform.
- [x] **Large-screen polish — shipped.** `readableContentWidth()` caps the four
      main screens to a centered column on iPad/Mac/Vision Pro (no-op on iPhone)
      so lists and cards don't stretch edge-to-edge.
- [x] **Widgets on iPad — shipped.** Widget target bumped to
      `TARGETED_DEVICE_FAMILY = "1,2"`, so the Home/Lock Screen widgets are now
      available on iPad too (no widget code change needed).
- (S) Optional Mac niceties: a dedicated `Settings` scene (⌘,), menu-bar
      commands (⌘N new transaction), window min-size — all additive.

**watchOS — deferred (decided to skip the watch app for v1)**
> ⚠️ **There is no watch app or watch complication today.** The shipped widgets
> are **iPhone Home/Lock Screen only** — they do **not** appear on Apple Watch.
> A watch face complication requires building the watchOS target below. Parked
> intentionally for now; revisit after TestFlight feedback.
- (M) Watch-face **complications**: glanceable "$X left" / bucket ring — the
  standout wrist feature (WidgetKit-based, reuses the `BudgetSnapshot` pattern)
- (M–L) Companion app: quick-add (Crown amount + category), recents, glance
- Dictation quick-add → leans on the AI parser
- Data via CloudKit (shares the iCloud store) or WatchConnectivity snapshot

**visionOS (polish only in 1.0)**
- [x] **Native visionOS app** (device family 7 + `xros` SDK) — not "Designed for
      iPad." Runs as a glass window with eye/pinch interaction; themes apply.
- [x] **Spatial polish — shipped.** Bottom **ornament** for month navigation and
      a trailing **ornament** for the add button; **hover highlights** on custom
      rows/pills (also benefits the iPad pointer); a sensible **default window
      size**. All gated to visionOS (hover compiles out on macOS), so no effect
      on the iPhone/iPad/Mac build.
- Larger spatial features (volumetric 3D charts, immersive space, multi-window)
  remain parked in 2.0.

## Core features
- **"Safe to spend"** / projected end-of-month number (partly in the tab bar)
- **Weekly safe-to-spend for Needs/Wants** — pace remaining budget over the days
  left in the month instead of just showing a lump remaining total. E.g.
  "remaining Wants budget ÷ weeks (or days) left in the month." Straightforward
  on today's model: `remaining(for:)` already exists on `MonthRecord`; just need
  days-remaining-in-month math (mirrors `dateForDay`'s month-length lookup in
  `LedgerService`) to divide by. Decide: weekly or daily cadence (or both), and
  whether it recalculates live as you spend or is fixed at the start of the
  week/month.
- **Budget rollover** — carry unspent buckets into the next month
- Savings-rate definition option: money-moved vs. leftover (or show both)
- Tags / sub-categories within the three buckets (ties to 5c)
- Search & sort transactions

## Beta feedback — UX polish
Captured from testing notes; the small wins below shipped together.
- [x] **Manual Light / Dark toggle — shipped.** A System / Light / Dark control
  in Settings → Appearance that overrides the OS appearance app-wide via
  `.preferredColorScheme` (`AppColorScheme`), independent of system Dark Mode.
- [x] **Budget tab header — shipped.** Large "Budget" title like Insights /
  History, with a centered month-selector row (‹ Month Year ›) beneath it; the
  old toolbar month chevrons are retired on iOS/macOS (visionOS keeps its
  ornament).
- [x] **Delete without swiping — shipped.** Context-menu (long-press /
  right-click) **Edit + Delete** on each transaction row, so iPad / Mac /
  visionOS don't depend on swipe (disabled on closed months; iPhone keeps swipe;
  the edit sheet's Delete button remains).
- [x] **Action Button quick-add — shipped.** `AddTransactionQuickIntent`
  (parameterless, `openAppWhenRun`) opens Ledger straight to the add sheet —
  assignable to the Action Button / Control Center / Shortcuts. Hand-off via a
  `QuickAdd` flag → RootView → Budget tab pops the sheet. (The parameterized Siri
  `AddTransactionIntent` is unchanged.)
- (M) **Native 3-D Insights charts on visionOS** — feasible: Swift Charts gained
  a 3-D API (`Chart3D` / `SurfacePlot`, iOS & visionOS 26), or RealityKit for a
  custom build; gate to visionOS. This is the "ambitious visionOS" showcase —
  see Ledger 2.0.

## Reporting
*Two distinct shapes — keep them separate from each other and from the shipped
5b Monthly Summary (which describes the live, in-progress current month):*

**Browse-anytime analytics** (passive, look whenever):
- Month-over-month comparison, category trends, average daily spend
- Category drill-down from the charts

**End-of-month analysis / recap** — *candidate: 1.x (post-launch)*
An event-driven recap surfaced when a month is **closed** (hooks into the existing
close-month flow), as opposed to the always-on analytics above or the live 5b
summary. The "here's how May went" moment:
- Final 50/30/20 actuals vs. targets; the month's savings rate.
- Biggest categories, notable overspend vs. wins, compared to the prior month.
- Deterministic (Swift-computed), same as 5b — **no AI prose** until a bigger/PCC
  model proves reliable for financial commentary (see the 5b lesson above).
- Optional later: deliver it as a notification when the month rolls over, and/or a
  shareable recap card. This is a *ritual* moment that passive reporting doesn't
  cover — closing a month earns you a wrap-up.

*Design shape (decided in discussion, pending final call on tap behavior):*
- **One reusable `RecapView(month:)`** built on the existing `MonthInsight` /
  `buildInsight()` engine (which already renders past-tense recap language for
  closed months). Extract `buildInsight` out of `InsightsView` into a shared
  spot; write the recap UI once, show it from three entry points:
  1. **The moment** — sheet pops right after `closeMonth` succeeds.
  2. **The archive — History** is the natural browse home for past recaps:
     tapping a month card opens that month's recap as a sheet, with an
     "Open in Budget →" button inside it.
  3. **Insights stays as-is** — its Monthly Summary card already shows the
     viewed month's recap content live.
- ⚠️ *Open decision:* History cards currently tap-through to the Budget tab.
  Proposal: make the recap sheet the tap destination (richer month detail;
  keeps your place in History) and move the Budget jump inside the sheet.
  Alternative if direct jump is preferred: context menu / small "recap"
  affordance on the card.
- Effort: ~a day for all three surfaces. No model changes, no CloudKit schema
  impact. Make the recap view screenshot-worthy (big headline, bucket results,
  savings rate, MoM delta highlight) — it's shareable-moment bait.

## System features
- [x] **Budget alerts — shipped.** On-device local notifications when **Needs or
  Wants** reaches **80%** or goes over, for the current month (no push
  entitlement). **Off by default**; toggle in Settings → Notifications (requests
  iOS permission on enable). **Savings stays silent.** Fires from every spend
  path (manual, Siri, command bar) via a hook in `LedgerService`; one ping per
  threshold per bucket per month, re-armed on refund/edit. Banners show even in
  the foreground (`UNUserNotificationCenterDelegate`).
  - (S) 📌 *pinned, optional later:* user-adjustable threshold (slider, e.g.
    75 / 80 / 90%) instead of the fixed 80%.
- [x] **Biometric lock** (Face ID) — shipped (Settings → Privacy). ⚠️ **Felt
      sluggish in Debug** — re-evaluate on a Release/TestFlight build and **remove
      it if it degrades launch/unlock** (iOS 18's built-in per-app "Require Face
      ID" is a fine native fallback). Isolated: `LockGate` + the Settings toggle.

## Polish & correctness
- First-run onboarding (income + split)
- Accessibility pass (Dynamic Type everywhere, VoiceOver labels, contrast)
- Currency picker (today follows device locale only)
- Final palette tuning + font decision
- Optional: live **"Syncing…"** state on the sync status panel

## Reliability & performance
- **Deploy CloudKit schema to Production** before any TestFlight/App Store build
  (App Store builds use Production; sync fails there until the schema is deployed)
- ⚠️ **TestFlight check — biometric lock performance.** It was sluggish in Debug;
  confirm it's fine on a Release build and **remove it if it still degrades
  launch/unlock** (per the decision above).
- Verify cold-launch time on a **Release** build (the ~20s first-launch is a
  Debug + first-install + Dev-CloudKit artifact; confirm it's a non-issue shipped)
- Optional: "delete this occurrence vs. the whole recurring rule" choice when
  deleting a materialized recurring transaction (today it deletes just the
  occurrence, by design)
- Unit tests: month-key math, import/export round-trip, savings calc
- General bug-fixing / reliability passes

---

# Ledger 2.0 — later

Deliberately deferred — bigger, multi-user, or better-built once Apple's
post-WWDC26 tooling ships.

- **5e — Receipt capture.** Scan with `VNDocumentCameraViewController`, feed the
  image to the multimodal model → `@Generable ReceiptDraft { merchant, total,
  date, suggestedCategory }` → preview → confirm. Vision-OCR fallback on older
  devices; optional photo attachment. *Deferred to 2.0+ — leans on newer
  multimodal tooling that lands a few months after WWDC26.*
- **CloudKit sharing** — household / shared budgets (multi-user; the big one).
- **Sync learned merchant categories across devices** — move `CategoryMemory`
  from local UserDefaults to the iCloud store (kept local in 1.0 to avoid sync
  risk).
- **5c — Understanding purchase types.** Cluster transaction *descriptions* into
  finer types (Dining, Groceries, Subscriptions, Transport, Health, Shopping…) to
  power insights like "Dining up 40%". *Deferred intentionally* — we value the
  three-bucket (Needs/Savings/Wants) simplicity, so finer types are a later,
  optional layer (stored tags vs. narrative-only still undecided).
- **5d — Ask-your-data Q&A** ("what did I overspend on?"). Tool-calling grounds
  answers in real numbers, but the on-device finance guardrail blocks free-form
  answers — so this needs **Private Cloud Compute** (still-private, larger model)
  once its tooling ships, or an external provider if the privacy trade-off is OK.
- **Deeper AI via Private Cloud Compute / external providers** — also the path for
  AI prose in the Insights summary (5b) if/when a bigger private model is viable.
- **Ambitious visionOS** — **native 3-D Insights charts** (now feasible via Swift
  Charts' `Chart3D` / `SurfacePlot`, iOS & visionOS 26, or RealityKit),
  multi-window (Budget + Insights). A real spatial showpiece; medium effort,
  gated to visionOS. Requested in beta — see "Beta feedback" in 1.0.
- **Round-trip export** to the original web-app JSON format (compatibility).
