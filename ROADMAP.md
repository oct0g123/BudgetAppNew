# Ledger — Roadmap

A living list of where the app is and where it's going. Not a commitment to
order or scope — just so good ideas don't get lost.

The plan is split into **1.0** (what we're building now — a polished, single-user
app across Apple platforms) and **Ledger 2.0** (deliberately deferred: bigger,
multi-user, or better-served-later ideas).

## Open decisions (1.0)

Revisit before final polish / before building the related feature:
- **Font:** keep Playfair Display, or revert headings to the system serif
  (New York)? One-line change in `Typography.serif`. Decide near the end.
- **Purchase types (Phase 5c):** persistent stored sub-category tags (richer:
  filter/chart/trend by type) vs. AI narrative-only (lighter, nothing stored).

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
- **iCloud/CloudKit sync (enabled):** cross-device sync of the SwiftData store,
  an in-app **sync status panel** (last received/sent + errors), and automatic
  **merge of duplicate months/settings** created across devices before sync
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

- [x] **5a — Command bar ("Tell Ledger")** — shipped.
- [ ] **5b — AI insights (Insights tab)** ← next. Compute real aggregates
      (savings rate, per-bucket spend, MoM deltas, top transactions) in Swift,
      feed the *summary* (not raw rows) to the model, render a structured
      `MonthInsight { headline, observations, suggestion }` beside the real
      figures. On-demand generate + per-month cache.
- [ ] **5c — Understanding purchase types.** Cluster transaction *descriptions*
      into finer types (Dining, Groceries, Subscriptions, Transport, Health,
      Shopping…). Powers "Dining up 40%" / "6 subscriptions = $94/mo". (Stored
      tags vs. narrative-only is an Open decision.)
- [ ] **5d — Ask-your-data Q&A.** Conversational mode via tool calling: expose
      `monthSummary(...)`, `spendByCategory(...)` so answers are grounded in
      real data.

## Platform expansion

Glanceability is the real win for a budget app. These share infrastructure —
an **App Group + the CloudKit-synced store**. Order: iOS widgets → watch
complications → watch app → App Intents. Effort tags: (S)mall/(M)edium/(L)arge.

**iOS — widgets & system integration**
- (M) Home Screen widgets: buckets remaining, safe-to-spend, savings ring —
  reuses figures we already compute
- (S–M) Lock Screen widgets: inline "$X left", circular bucket ring; free
  StandBy support once Home widgets exist
- (S–M) Control Center control + Action Button: one-tap "Add Transaction"
  deep-link, or remaining-budget readout
- (M) App Intents / Siri / Shortcuts / Spotlight ("how much is left?",
  "add $12 groceries") — **shares the 5a parser**. WWDC26: App/Entity/Intent
  Schemas, View Annotations, Spotlight semantic index. Validate with
  AppIntentsTesting.

**watchOS**
- (M) Watch-face **complications**: glanceable "$X left" / bucket ring — the
  standout wrist feature
- (M–L) Companion app: quick-add (Crown amount + category), recents, glance
- Dictation quick-add → leans on the AI parser
- Syncs via CloudKit (shares the iCloud store)

**visionOS (polish only in 1.0)**
- (S) Easy wins: ornament for month nav / filter; verify materials in the
  Shared Space

## Core features
- **"Safe to spend"** / projected end-of-month number (partly in the tab bar)
- **Budget rollover** — carry unspent buckets into the next month
- Savings-rate definition option: money-moved vs. leftover (or show both)
- Tags / sub-categories within the three buckets (ties to 5c)
- Search & sort transactions

## Reporting
- Month-over-month comparison, category trends, average daily spend
- Category drill-down from the charts

## System features
- (M) **Budget alerts** — local notifications at 80% / over a bucket (no push
  entitlement needed)
- (S–M) **Biometric lock** (Face ID) for privacy

## Polish & correctness
- First-run onboarding (income + split)
- Accessibility pass (Dynamic Type everywhere, VoiceOver labels, contrast)
- Currency picker (today follows device locale only)
- Final palette tuning + font decision
- Optional: live **"Syncing…"** state on the sync status panel

## Reliability & performance
- **Deploy CloudKit schema to Production** before any TestFlight/App Store build
  (App Store builds use Production; sync fails there until the schema is deployed)
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
- **Deeper AI via Private Cloud Compute / external providers** — for insights
  that exceed the on-device model, when warranted.
- **Ambitious visionOS** — volumetric 3D charts, multi-window (Budget + Insights).
  Low ROI; only if a spatial showpiece is wanted.
- **Round-trip export** to the original web-app JSON format (compatibility).
