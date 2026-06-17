# Ledger — Roadmap

A living list of where the app is and where it's going. Not a commitment to
order or scope — just so good ideas don't get lost.

## Pinned decisions (don't forget)

Things deliberately deferred — revisit before final polish / before building
the related feature:
- **Font:** keep Playfair Display, or revert headings to the system serif
  (New York)? One-line change in `Typography.serif`.
- **Purchase types (Phase 5c):** persistent stored sub-category tags (richer:
  filter/chart/trend by type) vs. AI narrative-only (lighter, nothing stored).

## Where we are

**Shipped (working):**
- Native SwiftUI multiplatform app (iOS, iPadOS, macOS, visionOS), SwiftData store
- 50/30/20 budgeting: monthly income auto-split into Needs/Savings/Wants with
  live progress bars
- Per-month allocation split (custom %, presets); historical months keep their
  own split
- Transactions (add/delete), category filter, month navigation, close-month
  archiving
- Recurring transactions (monthly templates, auto-materialized per month)
- Insights tab (Swift Charts): savings rate, spend-by-category, budget vs actual
- History tab: per-month summaries
- JSON + CSV export/import, with auto-detecting import of the original web app's
  backup format
- iCloud/CloudKit sync is opt-in (`enableCloudKitSync`), off by default so the
  app runs on a free Apple ID

## In progress — UI redesign (Liquid Glass + light/dark)

Branch: `claude/ledger-redesign-liquid-glass`. Direction: "native bones, custom
skin" — editorial identity (gold, serif, earth tones) on standard platform
components so we get Liquid Glass and cross-platform consistency for free.

- [x] **Phase 1 — Foundation:** design system (adaptive light/dark colors,
      Dynamic Type-aware typography, layout tokens)
- [x] **Phase 2 — Native structure:** real nav bars, `Form`/`List` on every
      screen, native sheets, light + dark enabled
- [ ] **Phase 3 — Liquid Glass accents** (glass goes on controls/chrome, not
      content, per HIG)
      - [x] Floating glass filter bar above transactions
      - [x] Floating glass add button (iOS)
      - [x] Tab-bar "safe to spend" accessory + minimizing tab bar (iOS 26)
      - [ ] Pinned "scrolls-under" filter bar (deferred — low priority)
- [ ] **Phase 4 — Identity polish**
      - [x] Bundle Playfair Display (variable) + DM Mono, registered at launch
            via CoreText (no Info.plist needed; falls back to system faces)
      - [x] Chart styling: DM Mono axes, hairline grid, avg savings-rate
            rule line
      - [x] Haptics (`sensoryFeedback`): filter selection, transaction saved,
            month closed, settings success/error toasts
      - [x] Animation: animated bucket progress bars, numeric rolling on
            amounts
      - [ ] Final palette tuning pass
      - [ ] **Open question:** keep Playfair or revert to the system serif
            (New York)? One-line change either way — decide near the end.

## Future ideas (post-redesign)

### Phase 5 — On-device intelligence (Apple Foundation Models)
Use Apple's on-device LLM (Foundation Models framework, iOS 26+) for private,
offline, no-cost AI. **Core principle: the model extracts structured data and
writes prose; Swift validates, computes, and mutates. The LLM never does
arithmetic or directly changes the ledger.**

Cross-cutting architecture:
- `IntelligenceService` wrapper isolates all model use; gate on
  `SystemLanguageModel.default.availability` so AI UI only appears on supported
  devices (A17 Pro / M-series, iOS 26+). Manual flows always remain.
- Guided generation with `@Generable` structs (no JSON parsing). `@Guide` to
  constrain fields; `@Guide(.anyOf([...]))` for controlled vocabularies.
- Privacy is a feature: 100% on-device — surface a "processed on your device"
  note.
- Stream responses; cache per-month results and regenerate on data change.

**WWDC26 updates that change this plan:**
- **Multimodal prompts** — Foundation Models now accepts images, and can call
  Vision OCR/barcode as tools. Simplifies receipt capture (5e) a lot (the model
  reads the image directly). The old "model is text-only" constraint is gone.
- **Private Cloud Compute** — a bigger, still-private Apple model at no cloud
  cost for App Store Small Business Program members (<2M downloads); the
  framework can also plug in external LLM providers (Claude/Gemini). Option for
  deeper insights (5b/5d) when on-device isn't enough.
- **Evaluations Framework** — adopt when building AI to verify the parser /
  insights behave correctly across inputs.
- **Dynamic Profiles** — swap model/tools/instructions mid-session; handy for
  the conversational 5d mode.

**5a — Natural-language command bar ("Tell Ledger")** (do first)
- Sparkle button → text field → e.g. "Add $500 to needs, utilities" → model
  returns `[DraftTxn]` (description/amount/category) → **preview card** →
  confirm → commit.
- Always preview before applying (money = confirm). Multi-action supported via
  array output. Model can infer bucket from the description.
- Heuristic regex fallback for "add $X to <bucket>" so the common case works
  even without the model.
- Natural extension point for App Intents / Siri / Shortcuts.

**5b — AI insights (Insights tab)**
- Narrative summaries: compute real aggregates (savings rate, per-bucket spend,
  MoM deltas, top transactions), feed the *summary* (not raw rows) to the
  model, get a structured `MonthInsight { headline, observations, suggestion }`
  rendered next to the actual figures.
- On-demand generate + per-month cache.

**5c — Understanding purchase types**
- Model clusters transaction *descriptions* into finer types (Dining,
  Groceries, Subscriptions, Transport, Health, Shopping…). Powers insights like
  "Dining up 40%" or "6 subscriptions = $94/mo".
- Decision: STORED sub-category tags (richer — filter/chart/trend by type, but
  a data-model addition) vs. on-the-fly narrative only (lighter, nothing
  stored).

**5d — Ask-your-data Q&A (later)**
- Conversational mode using tool calling: expose `monthSummary(...)`,
  `spendByCategory(...)` etc. so the model grounds answers in real data.

**5e — Receipt capture (after 5a — shares the parser)** — simplified by WWDC26
- Capture with `VNDocumentCameraViewController` (scan/deskew), then feed the
  **image directly** to the multimodal model → `@Generable ReceiptDraft
  { merchant, total, date, suggestedCategory }`. The model can also call Vision
  OCR/barcode as a tool when helpful.
- Preview → confirm/edit → add transaction (same pattern as 5a).
- Fallback on older devices: Vision OCR + heuristic "find the TOTAL". Fully
  on-device/private. iOS/iPadOS capture (Mac: drag image / Continuity Camera).
  Optional: attach the receipt photo to the transaction.

Decisions made:
- Commands show a **preview + confirm** before applying (not instant). ✅
- v1 command scope: **adding transactions only** (one or many per phrase). ✅
- Purchase-type tags (5c): **undecided — pinned** (see Pinned decisions).

### Core features
- [x] **Edit transactions** — tap a row to edit/delete (open months only)
- [x] **Reopen a closed month** (from the closed-month banner)
- [x] **Close-month confirmation**
- **Undo on delete** — swipe-delete is instant; add a "Deleted · Undo" toast
- **"Safe to spend"** / projected end-of-month number (partly in the tab bar)
- **Budget rollover** — carry unspent buckets into the next month
- Savings-rate definition option: money-moved vs. leftover (or show both)
- Tags / sub-categories within the three buckets
- Search & sort transactions

### Reporting
- Month-over-month comparison, category trends, average daily spend
- Category drill-down from the charts

### Platform expansion

Glanceability is the real win for a budget app. These share infrastructure —
an **App Group + the CloudKit-synced store** (unlocked by the paid developer
account). Natural order: iCloud sync → iOS widgets → watch complications →
watch app → App Intents. Effort tags: (S)mall / (M)edium / (L)arge.

**iOS — widgets & system integration (highest ROI)**
- (M) Home Screen widgets: buckets remaining, safe-to-spend, savings ring —
  reuses figures we already compute
- (S–M) Lock Screen widgets: inline "$X left", circular bucket ring; free
  StandBy support once Home widgets exist
- (S–M) Control Center control + Action Button: one-tap "Add Transaction"
  deep-link, or remaining-budget readout
- (M) App Intents / Siri / Shortcuts / Spotlight ("how much is left?",
  "add $12 groceries") — **shares the AI command parser (5a)**. WWDC26: use
  **App/Entity/Intent Schemas** to expose transactions/budgets to Siri with
  little code, **View Annotations** for on-screen references, and the
  **Spotlight semantic index** so "show my restaurant spending" works
  (ties to tags / purchase-types 5c). Validate with **AppIntentsTesting**.

**watchOS**
- (M) Watch-face **complications**: glanceable "$X left" / bucket ring — the
  standout wrist feature for budgeting
- (M–L) Companion app: quick-add (Crown amount + category), recents, glance
- Dictation quick-add → leans on the AI parser
- Syncs via CloudKit (shares the iCloud store)

**visionOS (already a supported destination — polish, not a killer app)**
- (S) Easy wins: ornament for month nav / filter; verify materials in the
  Shared Space
- (L, low ROI) Ambitious/gimmicky: volumetric 3D charts, multi-window
  (Budget + Insights). Skip unless a spatial showpiece is wanted.

**Other system features**
- (M) **Budget alerts** — local notifications at 80% / over a bucket (no push
  entitlement needed)
- (S–M) **Biometric lock** (Face ID) for privacy
- (L) CloudKit **sharing** — household / shared budgets

### Polish & correctness
- First-run onboarding (income + split)
- Accessibility pass (Dynamic Type everywhere, VoiceOver labels, contrast)
- Currency picker (today follows device locale only)
- Unit tests: month-key math, import/export round-trip, savings calc

### Maybe
- Export back to the original web-app JSON format (round-trip compatibility)
