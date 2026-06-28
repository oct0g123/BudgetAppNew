# Ledger — Roadmap

A living list of where the app is and where it's going. Not a commitment to
order or scope — just so good ideas don't get lost.

The plan is split into **1.0** (what we're building now — a polished, single-user
app across Apple platforms) and **Ledger 2.0** (deliberately deferred: bigger,
multi-user, or better-served-later ideas).

## Open decisions (1.0)

Revisit before final polish / before building the related feature:
- ⚠️ **Budget page design — re-check before release.** The header/month-selector
  layout works (large "Budget" title + scrolling month selector + search), but
  the overall composition "feels off" and deserves a design pass before
  shipping. (Pinning the month selector was abandoned — `safeAreaInset` + a
  collapsing large title is broken on this OS; revisit only if a clean approach
  appears.)
- **Font:** keep Playfair Display, or revert headings to the system serif
  (New York)? One-line change in `Typography.serif`. Decide near the end.
- **Purchase types (Phase 5c):** persistent stored sub-category tags (richer:
  filter/chart/trend by type) vs. AI narrative-only (lighter, nothing stored).

---

## Release plan (phased launch)

Shipping in stages to keep each release low-risk and scoped.

### v1.0 — iOS only, US App Store  *(now → ~1–2 days)*
First public release: **iPhone + iPad, US availability only.**
- **Scope lock:** iOS only (Mac/visionOS deferred to 1.1) and **US-only** — the
  US-only choice also sidesteps the locale money-input bug below at zero code risk.
- Final **design sweep** (esp. the Budget page — see Open decisions).
- Final **bug sweep** (triage below).
- **1–2 more days of TestFlight feedback** on the latest build.
- Then **submit**: privacy URL + screenshots + metadata (see
  `appstore/release-checklist.md`).

### v1.1 — macOS + visionOS
Add the other platforms once their builds are verified and have their own assets.
- **visionOS:** layered app icon (Icon Composer) + visionOS screenshots.
- **macOS:** verify build/run, Mac screenshots; fix the macOS widget dark-palette
  bug (below).
- Each platform = its own archive + submission under the same app record.

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
- **1.0 if quick, else 1.1** — **Editing a transaction's date across months**
  leaves it counted under the original month. Small fix; do in the 1.0 bug sweep
  if time permits.
- **1.1** — **macOS widgets always render the dark palette** (Mac-only cosmetic;
  rides with the macOS release).
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
- Month-over-month comparison, category trends, average daily spend
- Category drill-down from the charts

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
