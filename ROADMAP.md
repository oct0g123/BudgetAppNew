# Ledger — Roadmap

A living list of where the app is and where it's going. Not a commitment to
order or scope — just so good ideas don't get lost.

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
offline, no-cost AI features. **Principle: compute numbers deterministically;
the model only explains/classifies/converses — never does the math.**
- Plain-language monthly insight summaries generated from the real aggregates
- Auto-categorize transactions (Needs/Savings/Wants) from the description
- Natural-language entry ("40 on groceries yesterday" → structured transaction
  via `@Generable`)
- Ask-your-data Q&A via tool calling into `LedgerService`
- Merchant name cleanup / suggested tags
- Gate on `SystemLanguageModel.default.availability`; opt-in; graceful fallback
  to deterministic insights on unsupported devices

### Core features
- **Edit transactions** (currently add/delete only) — highest-priority gap
- **Undo + confirmation** on destructive actions (delete, close-month)
- **"Safe to spend"** / projected end-of-month number
- **Budget rollover** — carry unspent buckets into the next month
- Savings-rate definition option: money-moved vs. leftover (or show both)
- Tags / sub-categories within the three buckets
- Search & sort transactions

### Reporting
- Month-over-month comparison, category trends, average daily spend
- Category drill-down from the charts

### Platform power-ups
- **Home/Lock Screen widgets** + Control Center control (remaining budget)
- **App Intents / Siri / Shortcuts** ("how's my budget this month?")
- **Budget alerts** (notify at 80% / over a bucket)
- **Biometric lock** (Face ID) for privacy
- CloudKit **sharing** for household/shared budgets

### Polish & correctness
- First-run onboarding (income + split)
- Accessibility pass (Dynamic Type everywhere, VoiceOver labels, contrast)
- Currency picker (today follows device locale only)
- Unit tests: month-key math, import/export round-trip, savings calc

### Maybe
- Export back to the original web-app JSON format (round-trip compatibility)
- watchOS companion
