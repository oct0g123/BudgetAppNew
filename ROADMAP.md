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
  - **📊 Data snapshots (for the flip decision):**
    - *Jul 7:* 9 first-time downloads · 2 redownloads · 1.3K impressions ·
      64 page views (~14% view→buy) · $7 proceeds · 1 organic 5★ review ·
      #8 Top Paid Finance.
    - *Jul 8:* 11 first-time · 4 redownloads · 2.52K impressions · 145 page
      views (~7.6% view→buy — more cold/stranger traffic in the mix) · $9
      proceeds · 9 updates (1.1 reaching users) · Day-1 retention ~1.7%
      (opt-in-only, tiny sample — not meaningful yet) · zero crash reports.
    - Reading so far: chart placement still feeding impressions; conversion
      holding at a healthy paid-app rate. No flip signal yet — keep watching.
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

### v1.1 — macOS + visionOS  🎉 **ALL FOUR PLATFORMS LIVE** *(macOS approved + released 2026-07-15)*
Ledger is now live natively on **iPhone, iPad, Mac, and Apple Vision Pro** — the
milestone the featuring nomination hinges on. 🎯 **Submit the featuring
nomination now** (App Store Connect → Featuring → Nominations; paste from
`appstore/featuring-nomination.md`). Note: 1.1.1 (glass, recap, keyboard fix,
etc.) is still working through review separately — it does NOT gate the
nomination; the four-platform story is already true. Lesson learned: use
**manual release** when coordinating.
Remaining work:
- **visionOS:** ✅ build uploaded; **layered app icon validated by App Store
  Connect** (`AppIconVision.solidimagestack`, 3-layer parallax, wired via
  `ASSETCATALOG_COMPILER_APPICON_NAME[sdk=xros*]`). Remaining: visionOS metadata
  + screenshots → attach build → submit. (Layer art can be refined later.)
- **macOS:** ✅ build uploaded; **icon fixed** — full macOS size set (16–1024px,
  rounded-rect) added to `AppIcon` to clear upload error 90236. Widget
  dark-palette bug ✅ fixed. Remaining: macOS metadata + screenshots → attach
  build → submit. (Optional later polish: Apple-style drop shadow on the Mac icon.)
  - ⏰ **REMINDER — Mac screenshots:** raw window captures need exact-size
    conversion (accepted: 2880×1800 / 2560×1600 / 1440×900 / 1280×800, 16:10,
    **no alpha channel**). Either the `sips` pad-don't-stretch recipe
    (`--resampleWidth 2880` then `-p 1800 2880 --padColor 12100D`), or upload
    the raw captures to the assistant to convert.
  - ✅ **Mac UX fixes (2026-07-08, on branch — rebuild to verify):** command-bar
    text fields rendered macOS-style (title-as-label + right-aligned input,
    making the placeholder look like a real entry) → prompt-based fields;
    heuristic parser no longer reads digits glued to letters ("PS5") as
    amounts; transaction filter bar compacts + caps width on macOS only.
- **Release together:** set all three platforms to **"Manually release this
  version"** (incl. iOS, already in review) so they go live at the same time once
  the last is approved.
- ⏰ **DO NOT FORGET — the moment 1.1 is live on all platforms: submit the App
  Store featuring nomination** (App Store Connect → Featuring → Nominations;
  full paste-ready draft in `appstore/featuring-nomination.md`). Primary target:
  "New on Vision Pro" collections — the thin visionOS catalog is the best
  featuring odds the app will ever have. **Prerequisite: the accessibility pass**
  (Dynamic Type / VoiceOver / Reduce Motion / contrast — pulled forward from
  Polish & correctness; editors check it). Second nomination fires at v1.5 with
  the 3-D visionOS charts as a "significant update" — nominate at BOTH moments
  (launches get featured more readily than updates; a decline costs nothing).
- Each platform = its own archive + its own App Store Connect platform tab +
  its own TestFlight section, under the same app record.

### v1.2 — "the month-close release" (planned shape, ~3–4 build days)
Theme: make closing a month the emotional core of the app; clear the behavior
backlog. No CloudKit schema changes anywhere in this list.
- ✅ **End-of-month recap** (built 2026-07-09): `RecapView` on the shared
  `buildInsight` engine (moved to LedgerService); close-month sheet + History
  cards open their month's recap (decision made: tap → recap, with "Open in
  Budget" inside). Later polish idea: shareable recap card (ShareLink +
  ImageRenderer).
- ✅ **Review prompt moved into the recap flow** (built): close → recap →
  dismiss → rating ask.
- ✅ **Weekly safe-to-spend pacing** (built; decisions made: live-recalculating,
  weekly, auto-switching to per-day in the final week): "$X/wk" appended to
  Needs/Wants status on the live month.
  - 👁 **Watch item:** the math is remaining ÷ days-left × 7 (a live pace),
    NOT remaining ÷ 4 — correct but initially surprising (user expected 750,
    saw 954.55). If it keeps reading as "wrong," options: label it as a pace
    ("~$954/wk pace", whole dollars, no false-precision cents) or switch to
    fixed weekly buckets (remaining ÷ whole-weeks-left). Decided 2026-07-09
    to keep live pace and observe.
  - 💡 **"This Week" detail view (idea, 2026-07-11):** a granular weekly card —
    a per-week allowance for Needs/Wants that starts at the week's slice and
    *dwindles as you spend*, so you watch it drain in real time. This is the
    fixed-weekly-bucket model the pace label deliberately isn't. **Feasibility:
    easy-medium (~half day).** All the inputs exist: `remaining(for:)`,
    `daysRemainingInCurrentMonth`, and per-txn dates. The real work is two
    design decisions: (1) *week definition* — calendar weeks (Sun–Sat, resets
    weekly, simplest) vs. rolling 7-day vs. "remaining ÷ weeks-left" evolving
    buckets; (2) *what "spent this week" counts* — filter txns by date within
    the current week window. Needs a small `weekSpent`/`weekBudget` helper on
    MonthRecord + a card or expandable section on the Budget page. No model or
    CloudKit change. Pairs naturally with the pacing watch-item above — could
    replace or complement the "$X/wk" inline label.
  - ✍️ **Design settled 2026-08-06** (user: "once you're halfway through a week
    it's a little hard to tell how much you've spent that week, without combing
    through the transactions"). **Stateless, anchored at the week's start:**

    ```
    window       = current calendar week (Calendar.current.firstWeekday, so US = Sun–Sat),
                   CLIPPED to the month: [max(weekStart, monthStart) … min(weekEnd, monthEnd)]
    spentThisWeek(cat) = Σ txns in window
    weekBudget(cat)    = (remaining(cat) + spentThisWeek(cat))
                         ÷ daysFromWindowStartToMonthEnd × daysInWindow
    leftThisWeek(cat)  = weekBudget(cat) − spentThisWeek(cat)
    ```

    **Why this shape:** the numerator `remaining + spentThisWeek` is *invariant*
    to spending inside the week — spend $50 and `remaining` drops 50 while
    `spentThisWeek` rises 50. So `weekBudget` holds steady all week and only
    `leftThisWeek` drains, which is exactly the "watch it dwindle" feel. It's
    also the SAME even-pace math as the existing `$X/wk` label, just anchored at
    the week's start instead of today — so the two numbers agree instead of
    telling competing stories. And it needs **no stored state**: no new model
    field, no CloudKit schema change, nothing to sync or migrate.
  - Edge cases handled by the clipping: a week that starts before the month
    (month begins mid-week) and a short final week both shrink `daysInWindow`
    proportionally. Editing/deleting a *previous* week's transaction correctly
    re-raises this week's budget. Gate on `month.key == MonthKey.current &&
    !month.isClosed`, same as `paceText`.
  - **Placement (recommended):** one compact "This Week" section on the Budget
    page between income and the buckets — `THIS WEEK · Aug 4–10` with a Needs
    row and a Wants row (`$312 left of $450` + thin bar). Savings excluded,
    matching `safeToSpend`. Keep the existing `$X/wk` pace label as-is.
    Alternative if it reads heavy: a single combined Needs+Wants line that
    expands on tap.
  - ✅ **Watch item CLOSED 2026-08-06** (the "label it as a pace / drop the
    false-precision cents" option, logged 2026-07-09). The bucket detail line
    is now whole dollars on all three buckets (`$3,000 remaining · $778/wk
    pace`), and the pace label says the word **pace**. Prompted by the user
    hitting exactly the predicted confusion in the wild: `$777.78/wk` on the
    Wants row vs `$700.00 left for Wants` in the bar looked contradictory.
    They aren't — same formula, different anchor (pace recalculates from
    *today* with 27 days left; the bar is frozen at the *week's start* with 30)
    — but nothing on screen said so. Rule now: **derived figures are whole
    dollars, exact ledger amounts (spent / budget / transactions) keep cents.**
  - ✅ **DECIDED + BUILT 2026-08-06 — it replaced the safe-to-spend bar.**
    Mockup (card vs. bar variants, with the math):
    https://claude.ai/code/artifact/e405164b-bca3-4b8b-ab38-e62e6ebbac0e
    - **Shipped as the tab accessory, NOT a Budget card.** The bar is the
      most-seen surface in the app (on screen on every tab), which is where a
      number you're meant to *react* to belongs. The month figure it replaced
      was reassuring but rarely actionable — large early in the month and
      barely moving day to day, so you stop reading it. Option A's "This Week"
      card is **deferred, not dropped**: with the bar carrying the weekly
      number the card would repeat it a few hundred pixels away. Its remaining
      value is the Needs-vs-Wants *split*, which the bar can't show.
    - **Wants only** (user's call, and the right one): this is the
      before-you-spend number. Needs is mostly committed fixed costs, so
      folding it in makes the figure look healthy in a week where rent simply
      hasn't cleared yet. The label says so — `This week · $288.67 left for
      Wants` / `… over on Wants`.
    - **Falls back to the month's safe-to-spend** while browsing a past or
      closed month, so that figure isn't lost — just relocated to where it
      still makes sense.
    - **Surface built:** `MonthKey.weekWindow(inMonth:from:)` (clipped week
      window, user's `firstWeekday`, DST-safe day counts via `dateComponents`)
      + `MonthRecord.weekSpending(for:now:)` returning
      `(budget, spent, left)`; `SafeToSpendBar` in RootView rewritten around a
      shared `bar(leading:value:positive:negative:)`. No model field, no
      CloudKit schema change, no migration — all derived from transaction
      dates. iOS 26 only, same as the accessory itself (**macOS still has no
      equivalent — see the macOS revamp Phase 2 item**).
- ✅ **Adjustable alert threshold** (built 2026-07-09): 70–90% segmented picker
  in Settings → Notifications; caption reflects the chosen value.
- **Wave-3 behavior fixes:** ✅ Siri closed-month redirect (B4, built) ·
  ✅ rule edits update the open month's charge (B6, built; Recurring footer
  updated) · ✅ MoneyField keyboard + commit behavior (C2, built 2026-07-28 —
  see below).
- 🔴 **REGRESSION + PARTIAL REVERT (2026-08-06).** The keyboard-toolbar half of
  the fix below shipped a **blocking bug to TestFlight**: opening Add
  Transaction rendered an *empty* form and froze the app hard enough that taking
  a screenshot lagged. Intermittent — a second attempt worked, but the sheet
  stayed sluggish. Two tells in the user's screenshots:
  1. The **Done button appeared over an alphabetic keyboard.** That toolbar was
     attached only to `MoneyField` (`.decimalPad`), so it was showing while the
     *Description* field had focus — `ToolbarItemGroup(placement: .keyboard)` is
     **scene-ambient, not scoped to the view that declares it.** The
     "each field owns its own FocusState so only one Done appears" assumption
     was simply wrong; the command-bar duplicate-Done risk flagged earlier was
     the same defect showing up somewhere less harmful.
  2. The **accessory stayed up with no keyboard at all.** That's UIKit's first
     responder desynchronized from SwiftUI's `@FocusState` — caused by the
     `UIApplication.sendAction(resignFirstResponder)` "belt and braces"
     broadcast, which resigns the responder *behind SwiftUI's back*. SwiftUI
     still believes the field is focused and tries to restore it. Add a sheet
     with `.presentationDetents` (the accessory changes safe-area insets →
     detent re-measure → relayout → repeat) and that's the freeze and the
     collapsed form.
  - **Reverted:** `keyboardDoneButton`, `MoneyField`'s `@FocusState`, the
    recurring Day field's focus, and the `resignFirstResponder` broadcast — all
    gone. `MoneyField` is byte-identical to its pre-2026-07-28 shape.
  - **KEPT:** `.scrollDismissesKeyboard(.immediately)` on Settings, Add/Edit,
    the recurring editor and onboarding. This is the native single-mechanism
    fix for the original dead end — no accessory view, no responder games — and
    it needs no `@FocusState` at all.
  - **If Done ever comes back:** declare it ONCE per screen (not per field),
    never inside a sheet that also sets `presentationDetents`, and never pair
    it with a manual `resignFirstResponder`. Not worth attempting without a
    device to test on.
  - ⚠️ **Still unexplained:** the empty form is *consistent* with the
    detent/accessory relayout loop but isn't proven. If it recurs after this
    revert, next suspect is the memo field — `TextField(axis: .vertical)` with
    `.lineLimit(1...3)` inside a `Form` inside a detented sheet. Isolate by
    making it single-line.
- ✅ **Keyboard dismissal + income-typing lag (built 2026-07-28)** — reported
  live from Settings: the monthly-income keyboard could not be dismissed, and
  each keystroke lagged badly.
  - *Trap:* `.decimalPad`/`.numberPad` have no Return key, and the app had zero
    `@FocusState` and zero keyboard toolbars. Settings is a tab root that
    auto-saves (no Done button) and the keyboard covers the tab bar → force-quit
    was the only exit. Same dead end on Onboarding (`interactiveDismissDisabled`).
  - *Fix:* `keyboardDoneButton(_:)` helper in Theme.swift (`#if os(iOS)`, no-op
    on macOS/visionOS) + `@FocusState` inside `MoneyField`, so **all six money
    fields** get a "Done" above the keyboard; the Recurring "Day of month"
    number-pad field gets the same treatment.
  - *Lag:* the two direct-to-model bindings (Settings default income,
    Budget month income) wrote the model on **every keystroke** → SwiftData save
    → CloudKit export → `@Query` invalidation → full Form/List rebuild. Settings'
    privacy row then called `BiometricAuth.isAvailable`/`kindName` (each
    allocating an `LAContext` + `canEvaluatePolicy`) 3× per render. Typing
    "10000" cost 5 saves, 5 exports, 5 rebuilds, ~15 LAContext calls.
  - *Fix:* both income fields now type into a local draft and commit ~500 ms
    after typing stops (also committed on disappear; external sync changes still
    flow in). Biometric availability/name cached in `@State` via `loadDrafts()`.
    Budget's field is a small `MonthIncomeField` keyed by `month.key` so
    switching months resets the draft. Sheet Save buttons keep live validation —
    `MoneyField`'s binding still updates per keystroke; only the *model* write
    is debounced.
  - 👁 **Verify on device:** Command-bar review rows render a `MoneyField` per
    row in a `ForEach`, so several keyboard toolbars are declared at once —
    confirm only one "Done" appears when a row is focused.
- ✅ **Transaction notes / memos (built 2026-07-28)** — `Transaction.memo`
  (`String = ""`, defaulted not optional, so CloudKit is happy and no call site
  handles nil). Named `memo` because the command bar's parsed draft already uses
  `note` for the *description*.
  - *Entry:* one optional field in the Add/Edit sheet's second section, below
    Date, `axis: .vertical` with `lineLimit(1...3)` — the sheet's height is
    unchanged until you actually type. The primary flow (description → amount →
    Save) is untouched and Save validation still keys only off amount.
  - *Display:* the memo rides the existing caption line as `Aug 1 · split with
    Kate`, single-line and tail-truncated, so rows without one are pixel-identical
    and no third line appears. The amount got `.layoutPriority(1)` so a long memo
    truncates instead of squeezing the number.
  - *Search* now matches memo as well as description. VoiceOver appends
    "note: …".
  - *Round-trip:* JSON (`decodeIfPresent` → "", only encoded when non-empty),
    CSV (new `note` column appended **last**, so pre-1.2 exports with 5 columns
    still import), and the undo-delete buffer all carry it.
  - ⚠️ **This is a CloudKit schema change** — the only one in 1.2. Sequence:
    run a Development build so SwiftData adds the field to the Dev schema →
    promote Dev→Production in the CloudKit Dashboard → *then* submit. Shipping
    before promoting means memos silently don't sync in production. Old clients
    ignore the unknown field, so it's backward compatible.
  - Deliberately NOT done: memos on recurring *rules*. A memo is per-charge, so
    an auto-generated copy next month starts blank. Revisit if it feels wrong.
- ✅ **Recurring marker on transaction rows (built 2026-07-28)** — a small ⟳
  `repeat` glyph in gold-dim sits before the date on any transaction with a
  `recurringRuleID`, so a month's fixed costs read at a glance (pairs with the
  existing "Recurring first" sort). Glyph not color, so it survives color-blind
  vision and grayscale; VoiceOver appends "repeats monthly". The edit sheet
  gains a matching footer explaining that changes there affect only that
  month's charge. No model or CloudKit change — the flag already existed.
- ✅ **B5 fixed (2026-07-09, observed in the wild same day):** new transactions
  now land in the month their date belongs to (create path mirrors the edit
  path's re-home; falls back to the sheet's open month if the date's month is
  closed).
- ✅ **visionOS theme decision (2026-07-09):** Light/Dark override pinned to
  dark on visionOS (Light's near-black text vanished on glass — predicted in
  the glass-design note); Mode picker hidden there, themes still drive
  palette/accent. Recap sheet gets an explicit larger visionOS frame (default
  compact panel cut content invisibly).
- **Conditional — monetization flip** (~1 day): if the download-data window
  says free + tip jar, it lands here (price → $0, 3 consumable IAPs,
  "Support Ledger" screen).
- Filler if needed: widget snapshot skip-identical-writes (D2), predicated
  month queries (D6).

### 🖥 macOS revamp (specced 2026-08-06) — "feels sloppy next to the others"
**Root cause:** it's an iPad app in a window. The layout adapts fine; almost
none of the things that make a Mac app feel like a Mac app exist yet. Audited
the whole target — the gaps are concrete, not vibes:

1. **No menu bar.** Zero `.commands {}` in the project, so File/Edit/View hold
   only what the system provides free. On Mac the menu bar *is* the app.
2. **No keyboard shortcuts.** Not one `keyboardShortcut` anywhere. ⌘N, ⌘F,
   ⌘[ / ⌘], ⌘E are all reflexes that currently hit nothing.
3. **Settings is a sidebar tab, not a Settings window.** The most iPad-ish
   thing about it — Mac opens preferences with ⌘, in its own window.
4. **Mac silently loses the safe-to-spend bar.** `TabChrome` (RootView:123)
   installs the accessory only on iOS 26; Mac falls through to plain content.
   That's a missing *feature*, not just chrome.
5. **No way to force a sync.** Pull-to-refresh (BudgetView:297) is the only
   path and doesn't exist on Mac; no toolbar button replaces it.
6. **Nothing constrains the window.** `.defaultSize(920×680)` with no
   `windowResizability` — draggable to shapes the layout never anticipated.

#### ⚠️ Ground rule for the whole revamp
**Every change is either inside `#if os(macOS)` or purely additive.** No edits
to shared, ungated code paths. The two places it will be tempting to break this
are called out below (the navigator singleton, and Phase 3's type tokens) —
both would silently change iPhone/iPad/Vision Pro behavior. Holding this line
is what keeps the blast radius at zero for the three shipped platforms.

#### Phase 1 — menus + shortcuts ✅ **BUILT 2026-08-06** (untested on device)
Shipped, all behind `#if os(macOS)` / `#if !os(macOS)`. The diff is **purely
additive — zero lines removed** — so the iPhone / iPad / Vision Pro code paths
are byte-identical to what's on the App Store today.
- **File ▸ New Transaction (⌘N)** — via `focusedSceneValue`, jumps to Budget
  and pops the add sheet through the `requestAddTransaction` path the Siri /
  Action Button hand-off already built. Disabled when no window is focused.
- **View ▸ Budget / Insights / History (⌘1 ⌘2 ⌘3)**.
- **View ▸ Previous / Next / Current Month (⌘[ ⌘] ⇧⌘T)** — these need no view
  state at all; they read and write the same `@AppStorage("viewedMonthKey")`
  the Budget screen does.
- **Settings window (⌘,)** — a real `Settings` scene with its own model
  container and environment objects, and the Settings tab dropped from the Mac
  sidebar so it isn't in two places. `SettingsView` now branches: `macSettings`
  (General / Advanced `TabView`, fixed 580×560, no large title) vs
  `tabSettings` (the existing form, untouched). `advancedScreen` was already
  self-contained so it dropped straight in as the second tab.
- ⏸️ **File ▸ Export JSON / CSV (⌘E) deferred, deliberately.** Moving Settings
  into its own window means an export command in the *main* window can't reach
  SettingsView's export state at all. It now needs either a second focused
  value published from the Settings scene, or its own export path built
  straight off the model container. Phase 2 material — noting it so the gap
  isn't mistaken for an oversight.
- 🧪 **Untested — no Mac here.** Build all four targets before archiving.
  Watch for: the Settings window opening blank or trapping (missing
  environment object), ⌘N firing while the Settings window is frontmost, and
  the Recurring row still pushing correctly inside the General tab's stack.

#### Phase 1 spec (as written before building)
- ~~**Prereq:** `AppNavigator` becomes a shared singleton.~~ **RETRACTED
  2026-08-06 — this would have regressed iPad.** A singleton is shared across
  *scenes*, and `WindowGroup` gives iPadOS (Stage Manager / Split View) and
  visionOS multiple windows for free. Two Ledger windows would then share one
  `selectedTab`: switching tabs in one silently switches the other. Use
  **`.focusedSceneValue` + `@FocusedValue`** instead — it's per-scene, so only
  the focused window responds, and `AppNavigator` is left completely untouched:
  ```swift
  struct NewTransactionKey: FocusedValueKey { typealias Value = () -> Void }
  extension FocusedValues {
      var newTransaction: NewTransactionKey.Value? { … }
  }
  // RootView, #if os(macOS):
  .focusedSceneValue(\.newTransaction) { navigator.requestAddTransaction = true }
  // in .commands:
  @FocusedValue(\.newTransaction) private var newTransaction
  Button("New Transaction") { newTransaction?() }.keyboardShortcut("n")
  ```
  Slightly more scaffolding, but it's the correct shape *and* it drops the
  cross-platform risk of Phase 1 to nil.
- `LedgerApp`: add `.commands { … }` on the `WindowGroup`, all `#if os(macOS)`:
  - **File ▸ New Transaction — ⌘N** → `CommandGroup(replacing: .newItem)`,
    sets `AppNavigator.shared.selectedTab = .budget` +
    `requestAddTransaction = true` (BudgetView already consumes this via
    `handleQuickAdd()`, RootView:605 — no new plumbing).
  - **File ▸ Export JSON — ⌘E / Export CSV — ⇧⌘E** →
    `CommandGroup(after: .newItem)`. Needs the export trigger lifted out of
    SettingsView; simplest is an `AppNavigator.requestExport: ExportKind?`
    that Settings observes, OR do it after Phase 3 when Settings moves.
  - **View ▸ Previous / Next Month — ⌘[ / ⌘]** → `CommandMenu` or
    `CommandGroup(after: .sidebar)`; both just write `@AppStorage
    "viewedMonthKey"` via `MonthKey.offset(_:by:)`, which commands can read and
    write directly — no view state needed.
  - **View ▸ Budget / Insights / History — ⌘1…⌘3** → sets
    `AppNavigator.shared.selectedTab`.
- **Settings scene (⌘,):** add a `Settings { SettingsView() }` scene in
  `LedgerApp.body`. ⚠️ It's a *separate* scene, so it needs its own
  `.modelContainer(AppModelContainer.shared)` **and**
  `.environmentObject(SyncMonitor.shared)` (SyncStatusSection declares
  `@EnvironmentObject`) or it will crash on open. Then drop the Settings tab on
  Mac only — `#if !os(macOS)` around the `Tab(…, value: .settings)` in
  RootView:55 — so it isn't duplicated.
- ⚠️ SettingsView's `NavigationStack` + `.navigationTitle("Settings")` reads
  wrong in a Settings window; on Mac it should be a plain `Form` (no stack, no
  title) and the Advanced `NavigationLink` needs a different affordance —
  simplest is to inline the Advanced sections behind a `TabView` with
  General / Advanced tabs, which is the Mac-standard preferences shape.

#### Phase 2 — restore parity ✅ **BUILT 2026-08-06** (untested on device)
All `#if os(macOS)`; nothing outside a gate. Shipped:
- **Safe-to-spend readout on Mac** — `ToolbarItem(placement: .status)` on
  BudgetView rendering `SafeToSpendBar` *verbatim* (no refactor of the shared
  view, so iOS can't be affected). Closes the parity gap where the weekly
  Wants allowance existed only on the iOS tab accessory.
- **Sync Now button** beside Sort, calling `refreshFromCloud(in:)` with a
  spinner — the Mac stand-in for pull-to-refresh, which has no gesture there.
  Its `syncing` @State is itself gated.
- **Window constraints** — `.windowResizability(.contentMinSize)` plus a
  720×520 minimum on RootView, so the three-bucket layout can't be squeezed
  into a shape it was never designed for.
- **File ▸ Export JSON (⌘E) / CSV (⇧⌘E)** — the Phase 1 deferral, now done.
  `LedgerExport` reads the shared container directly and drives an
  `NSSavePanel`, because Settings is its own scene on Mac and a main-window
  command has no route to its export state. Uses the same `LedgerArchive`
  builder as the in-app export, so the files are byte-identical.
- 🧪 **Untested.** Watch for: two `.primaryAction` items plus `.status`
  crowding the toolbar at small widths; the Sync spinner leaving the button
  stuck if `refreshFromCloud` throws; ⌘E colliding with anything system-level.

#### Phase 2 spec (as written before building)
- **Safe-to-spend on Mac:** add a `ToolbarItem(placement: .status)` to
  `BudgetView` under `#if os(macOS)` rendering the existing `SafeToSpendBar`
  content ("Aug · $2,867 left to spend"). `.status` is the natural Mac
  placement (centered in the toolbar). Reuses the view already written for the
  iOS tab accessory — extract its body so both call it.
- **Sync button:** `#if os(macOS)` toolbar item beside Sort calling
  `await LedgerService.refreshFromCloud(in: context)` (LedgerService:521 —
  already `@MainActor`, already waits out in-flight imports), with a
  `ProgressView` while running. This is the Mac stand-in for pull-to-refresh.
- **Window:** `.windowResizability(.contentMinSize)` on the `WindowGroup` plus
  a `#if os(macOS) .frame(minWidth: 720, minHeight: 520)` on `RootView`, so the
  window can't be dragged below what the three-bucket layout needs.

#### Cross-platform risk register (assessed 2026-08-06)
| Change | Risk to iOS / iPadOS / visionOS |
|---|---|
| `.commands` block, `Settings` scene, `windowResizability`, Mac min-frame | **None** — macOS-only APIs behind `#if os(macOS)`; they don't exist in the other builds. |
| Safe-to-spend in the Mac toolbar | **None** — `SafeToSpendBar` is already a self-contained `View`. Reuse it as-is; do NOT refactor it. |
| Dropping the Settings tab on Mac | **None** — `#if !os(macOS)` around the `Tab`, compile-time only. |
| SettingsView Mac restructure (no NavigationStack, General/Advanced tabs) | **Low, contained** — must be `#if os(macOS)` branches *inside* the file. This is the file most likely to get broken by accident; the iOS path should come out byte-identical. |
| ~~AppNavigator singleton~~ | **Would have been real** — see the retraction above. Avoided entirely by `focusedSceneValue`. |
| Phase 3 type/density tuning | **Real if done wrong.** Editing `Typography.baseSize()` or `Spacing` tokens to fix Mac changes *every* platform. Any Phase 3 change must be macOS-scoped, never a global token edit. |
| Compile breakage | **The actual likely failure.** `#if os(macOS)` branches are invisible to the iOS compiler, so a Mac-only mistake surfaces only when that target builds — and vice versa, which is exactly how `scrollDismissesKeyboard` slipped through to a visionOS archive. **Build all four targets before archiving anything.** |

- `CommandGroup(replacing: .newItem)` also *removes* File ▸ New Window. Use
  `CommandGroup(after: .newItem)` unless single-window is a deliberate choice.
- **Sequencing:** ship 1.2 first. The Mac work can't touch the iOS/visionOS
  binaries, but it does change the *Mac* binary — so don't submit a Mac build
  mid-revamp. Land 1.2 everywhere, then treat the Mac revamp as 1.3.

#### Phase 3 — visual density 🚧 **STARTED 2026-08-06** (screenshots received)
- ✅ **Root cause of "the Budget screen needs the most work" found and fixed in
  one line.** `HistoryView`, `InsightsView` and `SettingsView` all call
  `readableContentWidth()` (720pt, centred). **`BudgetView` never did.** On a
  985pt Mac window it stretched to fill, so progress bars ran ~830pt, the
  `$2,901.00 / $3,311.50` and `88% used` figures sat ~4pt from the window edge,
  the month header and its chevrons ended up ~800pt apart, and the income slab
  read as full-bleed rather than a card. Every *other* tab already sat in a tidy
  column — which is exactly why the user described the others as cohesive and
  this one as wrong. Now `#if os(macOS) .readableContentWidth()`.
- ✅ **Follow-up: the scroller was parked mid-window.** `readableContentWidth()`
  works on History/Insights because they apply it to the inner VStack *inside* a
  ScrollView — the scroll view stays full-width, so the scroller lands at the
  window edge. **A `List` IS the scroll view**, so constraining it dragged the
  scroller inward with the content. Budget now uses `contentMargins(.horizontal,
  …, for: .scrollContent)` from a `GeometryReader`, which insets the rows and
  leaves the scroller where macOS expects it. Rows stay in the same 720pt column.
  - ⚠️ **First attempt came out full-bleed:** `contentMargins` was applied to
    the ancestor `Group`, where it silently does nothing. It has to sit on the
    **scroll view itself**, so `monthList` now wraps a `listContent(_:)` helper
    and applies the modifier to the `List` directly. No error, no warning — it
    just quietly doesn't apply, which is the worst kind of API to get wrong
    without a device to check on.
  - ❌ **`contentMargins` doesn't work here at all.** Tried on the ancestor
    (silently ignored) and directly on the `List` (also ignored) — it does not
    drive a List's row insets on macOS. **Settled: constrain the width and
    `.scrollIndicators(.hidden)` on Mac.** macOS auto-hides overlay scrollers by
    default, so this only differs for people who set "Show scroll bars: Always";
    trackpad and wheel scrolling are untouched.
  - 🔁 **If the missing scroller ever matters**, the mechanism that *would* keep
    it at the window edge is a dynamic `listRowInsets` on every section, fed by
    a `GeometryReader`. Not done because `listRowInsets` takes full `EdgeInsets`
    — it would force explicit vertical padding onto rows currently using system
    defaults, disturbing spacing the user had just approved. Six call sites,
    and untestable from here.
  - Rule for later: **constrain content inside a scroll view, never the scroll
    view itself** — the codebase already did this correctly in two places and I
    picked the wrong one of the two patterns.
  - `SettingsView` has the same shape (`readableContentWidth()` on the Form) but
    is harmless on Mac now: the Settings window is a fixed 580pt, below the
    720pt cap, so nothing is constrained and no scroller floats.
- 📋 **Deliberately ONE change, then re-judge.** Typography is still iPhone-sized
  on Mac ("August 2026" ~28pt, income ~34pt) and row height is generous for a
  pointer-driven list. Both are real, but most of the "stretched" feeling comes
  from width, and changing five things at once means learning nothing about
  which mattered. Next screenshot decides whether type/density work is needed.
- ⚠️ **Type/density work, if it happens, must be macOS-scoped.** Editing
  `Typography.baseSize()` or the `Spacing` tokens to fix Mac reflows *every*
  platform — see the revamp's ground rule.
- 💭 **Same inconsistency exists on iPadOS** — Budget is full-bleed there too
  while the other three tabs are constrained. Not touched: iPad ships that way
  today and this was a Mac complaint. Worth a deliberate decision later rather
  than a drive-by change.
- ✅ **Sheet polish + ⌘N fix (2026-08-06, second screenshot round).**
  - **⌘N did nothing while ⌘1–3 worked.** Not the focused-value plumbing (⌘1–3
    proves that works) — a `WindowGroup` **automatically binds File ▸ New Window
    to ⌘N**, so the `CommandGroup(after: .newItem)` item asking for ⌘N was a
    duplicate binding and the system's won. Switched to
    `CommandGroup(replacing: .newItem)`, which claims ⌘N and drops New Window.
    Right trade here: in a budgeting app "New" means a transaction, and a second
    window onto the same synced data earns very little.
  - **"Amount            Amount"** in the add sheet: on macOS a TextField's
    *title* becomes the form label and the *prompt* becomes placeholder text, so
    passing the same string for both printed it twice. The money field now
    prompts with the zero value (`$0`) on macOS; the Note row prompts "Optional"
    since "Note" is already its label. iOS keeps today's text — it hides labels,
    so the placeholder is its only hint.
  - Mac sheets resized for a pointer: add/edit 520×470, recurring editor
    520×470, card editor 460×360 (were 400×320/340 — phone-sized).
  - 📌 **PINNED FOR ~1.5 — another pass on the add/edit sheet.** User after the
    fixes: *"far better… idk if the submenu is perfect."* Not broken, just not
    finished. Candidates, none started:
    - The **"Amount" label renders in bold mono** because the caller applies
      `.font(Typography.mono(…))` to the whole `MoneyField` and on macOS that
      reaches the label too. Sits oddly beside a regular-weight "Description".
      Fixing it means moving the font *inside* `MoneyField`, which changes iOS —
      so it needs its own decision, not a drive-by.
    - The segmented category picker is intrinsic-width and left-aligned; a Mac
      form usually wants it filling the row.
    - `NavigationStack` + `navigationTitle` gives the sheet a title bar; Mac
      sheets more often use a plain bold heading or none.
    - Grouped-form row boxes inside an already-boxed sheet read as double
      framing on Mac.
  - ⚠️ **Caught two of my own edits before commit:** `#if` can't sit inside a
    function's argument list, nor between a base expression and its trailing
    modifier chain. Both became computed properties returning `Text`. Worth
    remembering — `#if` in Swift is statement/declaration level, not expression
    level, and the compiler that would have caught it isn't in this environment.
- ⚠️ **The 2026-08-06 screenshots were from a PRE-Phase-1 build** (Settings still
  a sidebar tab; income footer still the old "Carried forward to each new
  month"). So they show none of Phases 1–2 — no Settings window, no toolbar
  safe-to-spend, no Sync button. Re-shoot after pulling before judging chrome.

#### 🔴 Settings window missing from the Mac menu bar (2026-08-06)
User couldn't find Settings anywhere: not in the sidebar (correct — Phase 1
removed it there) and **not under Ledger ▸ Settings… either**, which a `Settings`
scene registers automatically. So the scene wasn't registering, even though the
other half of the same commit (dropping the sidebar tab) clearly took effect.
- **Suspected cause:** the `Settings` scene was declared inline after two `#if`
  blocks of *WindowGroup modifiers*, and was most likely parsed as a
  continuation of that modifier chain rather than as a second scene. It compiled
  either way, which is why nothing surfaced.
- **Fix:** each scene is now its own computed property (`mainWindow`,
  `settingsWindow`), so there's no chain for it to be absorbed into.
- **Also added a visible way in:** a gear in the Budget toolbar's *leading* slot
  (away from the crowded action cluster) calling `@Environment(\.openSettings)`.
  The user failed to find Phase 1 features twice because they live in the menu
  bar — ⌘, is correct for Mac, but correct and discoverable aren't the same
  thing, and a real user won't have the spec to consult.
- ⏭ **If ⌘, and the gear both still do nothing**, the scene genuinely isn't
  registering and the fallback is to drop the `Settings` scene entirely and put
  the Settings tab back in the Mac sidebar — less idiomatic, but it demonstrably
  worked before Phase 1 touched it.

#### Phase 1 addendum — ⌘F (built 2026-08-06)
Listed in the original spec's shortcut list and then never built; user found it
the same way. **Edit ▸ Find (⌘F)** focuses the Budget search field, published as
a focused value **from `BudgetView`** rather than RootView because that's where
the field lives — so it greys out on Insights and History, which is honest:
Ledger's search only covers transactions. Nothing claims ⌘F automatically the
way `WindowGroup` claims ⌘N, so there was no collision to design around.

Remaining Mac keyboard gap, not built: **⌘Z for the delete-undo toast.** The app
runs its own undo (a 4-second toast + `pendingUndo` buffer) rather than the
system's `UndoManager`, so wiring ⌘Z means bridging the two. Bigger than it
looks; left alone deliberately.

#### Phase 3 spec (as written before screenshots)
Typography is sized for touch and reads large on Mac; `.formStyle(.grouped)`
with custom `DS.rowBackground()` fills looks transplanted; toolbar spacing
wants Mac-specific tuning. **Blocked on Mac screenshots of Budget + Settings**
— "sloppy" is visual, and this has been reviewed blind so far. Handle it the
way the visionOS glass pass went: screenshot → targeted diagnosis → option A/B.

### 📋 Code review round 2 (2026-07-11) — findings pinned, fixes NOT yet applied
Full review of everything since Wave 1 (39 commits). 8 verified findings +
cleanup/perf batches. **Sequencing plan (agreed risk tiers):**
- **Batch 1 (low risk, do first):** #1 applyRule must not rewrite a
  just-created txn's date / must not mutate on bare isActive toggle / must
  evaluate alerts + refresh snapshot (policy: only explicit rule EDITS update
  open months; date moves only if dayOfMonth changed) · #5 command bar gets
  the B5 date-based month targeting (behavior change: files to current month,
  not viewed month) · #6 edit-path re-home gets the closed-month guard (show
  "month is closed" message, no silent fallback) · #7 RootView merge hooks
  re-fetch months after merging before feeding the widget snapshot ·
  #8 threshold change triggers immediate BudgetAlerts.evaluate.
- **Batch 2 (medium, needs two-device airplane retest):** #2 month(forKey:)/
  ensureMonth return the canonical duplicate (min by monthPrecedes) so writers
  can't target hidden grace-window dups (also: applyRule iterates canonical
  months only) · #3 one-time full merge pass per app-version upgrade to heal
  legacy same-rule/different-id double-rent (needsMerge can't detect it).
- **Batch 3:** #4 reset-resurrection mitigation — only restore SettingsBackup
  when the store still contains months/txns (proper fix = synced reset
  tombstone → CloudKit schema addition; deferred).
- **Below-cut batches (whenever):** perf (needsMerge full-table scans;
  MonthKey.calendar → static let; HistoryView.months computed 5×/render;
  refresh redundant fetches; RecapView per-render buildInsight) · cleanup
  (RecapView uses Card + shared stat/bullet/suggestion views; one
  previousMonth helper — Insights copy skips canonicalization; tuple sort
  keys replace %-format strings; contentEquals → synthesized Equatable;
  sparkle-button #if collapse; mergeDuplicateSettings simplification;
  grace-check first in needsMerge) · a11y/UX (History card chevron implies
  push but opens sheet; VoiceOver hint) · altitude: **F1 targetMonth
  chokepoint** (5 divergent month-targeting shapes) retires findings
  #2/#5/#6/#8's class — best done as its own focused refactor.

### 📋 Performance & battery audit (2026-07-28) — findings pinned, fixes NOT applied
Triggered by "still getting intermittent lag on the Settings page, at least on
iOS" — i.e. lag that *survives* the per-keystroke income fix shipped the same
day. Read-only pass; nothing changed. **Circle back after the 2026-07-28 device
test** (keyboard Done / income latency / recurring ⟳ / memos) so the two sets of
changes stay attributable. Claude to re-flag this section once that feedback
lands.

- 🔴 **P1 — the whole app re-renders on every CloudKit event.**
  `LedgerApp.swift:207` holds `@StateObject private var syncMonitor =
  SyncMonitor.shared`. `@StateObject` *subscribes*, and `SyncMonitor`
  republishes on every `NSPersistentCloudKitContainer` event (setup / import /
  export, begin **and** end, per batch — dozens per sync burst). Each one
  invalidates the App body → `WindowGroup` → `LockGate` → `RootView` → the
  active tab. The App never reads a published property; it only forwards the
  object via `.environmentObject`.
  - Note the irony: `SyncMonitor`'s own doc comment (`LedgerApp.swift:94`) and
    the `SyncStatusSection` extraction (`SettingsView.swift:365`) both exist
    *because* of "the old Settings-hang bug" — but the App-level subscription
    re-broadcasts to everything anyway, so that extraction only ever recovered
    part of the win.
  - Settings feels it worst (9 sections, ~25 rows, segmented pickers, a
    `ForEach` of theme rows), and "intermittent" fits exactly: it hits when a
    sync burst overlaps with being on that screen.
  - **Fix (1 line):** `private let syncMonitor = SyncMonitor.shared`. Safe —
    `.shared` is a `static let` with app lifetime, so there's nothing for
    `@StateObject` to own, and only `SyncStatusSection` (which declares
    `@EnvironmentObject`) still re-renders. **Bonus:** make `Phase` `Equatable`
    and skip the assignment when unchanged, so redundant events never publish.
- 🟠 **P2 — Settings holds two live `@Query`s it never displays.**
  `SettingsView.swift:23-24` (`months`, `rules`) are read only by `archive()`
  (line 718, Advanced screen, on demand) and one button action (line 308).
  Nothing in the visible form uses them — but any `MonthRecord` / `Transaction`
  / `RecurringRule` change, including every CloudKit import batch, invalidates
  them and rebuilds all nine sections. **Fix:** delete both; fetch on demand via
  the existing `LedgerService.allMonths(in:)` / `allRecurringRules(in:)`. Keep
  `allSettings` live — income needs it, and `AppSettings` rarely changes.
- 🟠 **P3 — the Advanced screen re-encodes the entire database per render.**
  `SettingsView.swift:142-144`: `.fileExporter(document:)` takes a plain
  parameter, not an autoclosure, so `ExportDocument(data: jsonData()/csvText())`
  is evaluated on **every body pass**, not when the sheet presents. While
  Advanced is open, each re-render maps every month + transaction to DTOs and
  JSON/CSV-encodes them — and combined with P1 that's a full export encode per
  CloudKit event. **Fix:** build the payload in the button action into `@State`
  and hand the exporter that.
- 🟢 **Battery profile is fundamentally clean.** No timers, no polling, no
  `TimelineView`, no background tasks, no location, no network beyond CloudKit.
  The widget is well-behaved: 2-hour `.after` policy plus change-driven reloads,
  and `BudgetSnapshotStore.update` already skips the write *and* the timeline
  reload when content is unchanged (`LedgerService.swift:740`) — correct, since
  WidgetKit throttles reload budgets. The one real drain in an app like this is
  **write amplification** (every model write is a CloudKit export), which was
  the per-keystroke income binding — fixed 2026-07-28.
- ⚪️ Minor, not worth acting on alone: `RootView.swift:87` runs
  `BudgetSnapshotStore.update` on *every* scene-phase transition (2–3× per app
  switch), each JSON-*decoding* the old snapshot just to compare — comparing
  encoded `Data` would skip that. And `MonthRecord.spent(for:)` is O(txns)
  called 3–6× per render; noise at realistic sizes, revisit only if someone
  imports years of history.
- **Caveat:** no profiler available in the review environment, so P1 is a
  code-level diagnosis, not a measurement. Confirmation signal: the hitch should
  stop correlating with sync activity.

### 👁 Monitoring — background CloudKit crash (0xdead10cc), low severity
TestFlight surfaced one crash (1.1.1, iPhone 17-class, iOS 26.5): RUNNINGBOARD
`0xdead10cc` = OS killed the app in the **background** while it held a SQLite
lock, opening the CloudKit store at launch (`AppModelContainer.shared`,
LedgerApp.swift:169). Triggered by a background CloudKit wake (we register for
remote notifications) while the device was locked / pre-first-unlock, so the
data-protected store file couldn't be read. **Not a foreground crash — users
never see it; not data corruption (clean store-open, interrupted).** Expected
pattern for NSPersistentCloudKitContainer apps.
- **Do NOT rush a fix:** the canonical mitigation is store file-protection =
  `completeUntilFirstUserAuthentication`, but SwiftData's `ModelConfiguration`
  doesn't expose it, so any fix restructures the launch-critical container init
  (get it wrong → app won't launch for anyone). Mitigation risk > bug severity.
- **Action:** watch App Store Connect → Analytics → crash-free rate. Noise at
  1 report. If it climbs, do a **device-tested** file-protection fix (set
  `.protectionKey` on the store files post-init via FileManager, or a
  protected-data-availability guard around the container build), never blind.

### ✅ Finite recurring rules — "for 3 months" **BUILT 2026-08-06**
Shipped as designed below, with three notes:
- **The "fix `applyRule` FIRST" warning was overstated** and is retracted. The
  bound is a single `rule.covers(month.key)` replacing `rule.startKey <=
  month.key` in both sites — it *narrows* the month range, so it neither
  compounds the retroactive-rewrite finding nor complicates its eventual fix.
- **Shrinking a rule now retracts charges past the new end.** `applyRule` gained
  an else-branch: in an open month strictly after `endKey`, transactions
  carrying that rule's id are deleted. Without it, cutting 6 months to 3 would
  leave three orphan charges with no rule behind them. Tightly bounded — open
  months only, only rows with the rule's id, closed months frozen, hand-entered
  transactions never touched — but it IS a delete triggered by an edit, so it's
  the thing to exercise first.
- `covers(_:)`, `hasFinished` and `monthCount` live on the model, so the window
  has exactly one definition and the two materialization sites can't drift.
- Editor gains a **Duration** section (toggle + 1–60 stepper) whose footer spells
  out the result: *"Charges 3 times — August 2026 through October 2026."* The
  rule row reads `… · through Oct`, flipping to `· ended Oct` and dimming once
  past. `hasFinished` stays separate from `isActive`: finished ≠ paused.
- Quick-add's "Repeat monthly" toggle still creates an open-ended rule; set a
  limit by editing it afterwards.
- ⚠️ **Second CloudKit field in 1.2** (`endKey`, optional String) alongside
  `memo`. Both are in the Dev schema after one Debug run, so **one** Dev→
  Production promotion now covers both.

#### Original design note (idea, logged 2026-08-06)
User: *"set a certain limit on recurring transactions. For example if you are
paying monthly on something for just 3 months."* Installment plans, a gym
contract, a trial — anything with a known end. Today every `RecurringRule` runs
forever until you remember to switch it off.

- **Store a declarative end, not a countdown.** Add `endKey: String?` to
  `RecurringRule` (inclusive last month, e.g. `"2026-10"`). A mutable
  `remainingCount` that decrements is the obvious design and the wrong one
  here: with CloudKit, two devices materializing the same month could each
  decrement it, and a sync conflict could silently lose one. `endKey` is
  idempotent — every device computes the same answer from the same data,
  which is the same rule the rest of the merge system follows.
- **Count in the UI, date in the model.** Ask "For how long?" — *Forever* /
  *For N months* with a stepper — then store
  `MonthKey.offset(startKey, by: n - 1)`. The user thinks in "3 months"; the
  model stores something that can't drift.
- **Where it gates:** `applyRecurringRules(to:in:)` (LedgerService:86) currently
  guards only `rule.startKey <= month.key`; it needs the upper bound too. Same
  for `applyRule(_:in:)`, which loops open months from `startKey`.
  ⚠️ **Both call sites are inside the known-buggy `applyRule` retroactive-rewrite
  finding** (pinned, code review round 2). Do that fix FIRST or together —
  adding a second bound to code that already rewrites the wrong months just
  makes the eventual fix harder.
- **Display:** the rule row should say `Ends Oct 2026` (or `3 of 6 charged`) and
  dim once past its end. `isActive` stays a separate, user-controlled toggle —
  an ended rule isn't a paused rule, and conflating them loses information.
- **Past months are untouched** — `endKey` only gates *future* materialization,
  so history keeps whatever was charged. Closed months are already immune.
- **Round-trip:** `RuleDTO` needs `endKey` with `decodeIfPresent`, same pattern
  as `memo`.
- ⚠️ **CloudKit schema change** (one optional String). If it lands before 1.2
  ships it can ride the same Dev→Production promotion as `memo`; otherwise it
  needs its own. Worth batching with the `AppSettings.updatedAt` field the
  income-merge fix wants, so there's one promotion instead of three.
- **Effort:** ~half day once `applyRule` is sorted.

### ✅ Payment cards **BUILT 2026-08-06** — shipping in 1.2 (user's call)
Built as specced below, going into **1.2 rather than 1.3**. I recommended the
opposite (ship the tested release, take the extra CloudKit promotion later);
user chose to combine, so 1.2 now carries three new schema items — `memo`,
`endKey`, and `PaymentCard` + `Transaction.cardID` — in one promotion.
- **Chip, not plain text** — user's call, reversing my recommendation, on the
  argument that the outline breaks the caption line up for readability. It's a
  fair read: that line can already carry ⟳ + date + memo.
- ⚠️ **Deviation from the mockup: no group headers in the by-card sort.**
  Grouping means splitting the transaction `ForEach` into per-card `Section`s,
  which would duplicate the row builder, its context menu, `onDelete` and the
  undo wiring — the busiest, most recently-broken screen in the app. It sorts
  by card name with unassigned last, and the chip STAYS visible in that view
  (the mockup hid it, relying on headers). Headers remain a clean follow-up.
- Picker is hidden entirely until at least one card exists, so the add sheet is
  untouched for anyone not using the feature. Archived cards stay selectable on
  a transaction that already uses one, so editing old rows never drops a label.
- ⚠️ **`CardsView` + `CardEditor` live in RecurringView.swift, not their own
  file.** I first shipped them as `CardsView.swift` on the belief that the
  project used synchronized root groups — it doesn't. **Only the LedgerWidgets
  target is synchronized; the main app target uses explicit file references**,
  so any new .swift file must be added to the target by hand in Xcode or the
  build fails with "cannot find X in scope". Folding them into RecurringView
  (their structural twin — same list + editor shape) avoids that entirely.
  **Remember this before creating any new file in `Ledger/Ledger/`.**
- 🔴 **Shipped a duplicate bug, fixed same day.** Adding two cards produced
  four copies of each in the picker. Cause: I added a new user-created record
  type and **never registered it with the merge system** — `needsMerge` checked
  settings, months, transactions and rules; `mergeDuplicates` deduped all four;
  cards were in neither. `dedupeRecurringRules` existing at all is the proof
  that CloudKit mirroring produces same-id repeats for user-created records in
  this app, so a new type without dedupe was always going to do this.
  **Rule for any future model: add it to `needsMerge` AND `mergeDuplicates` in
  the same commit that adds the model.**
  - `dedupeCards` handles both shapes: same-id repeats (delete extras; the
    survivor keeps the id, so `Transaction.cardID` still resolves) and distinct
    ids describing the same card (two devices adding "Amex Gold" before
    syncing — **re-point those transactions at the survivor before deleting**,
    or they'd silently lose their label).
  - Views call `PaymentCard.uniqued(_:)` so a pending merge can't hand
    SwiftUI's `ForEach` two rows with the same identity.
  - Re-adding an existing card by name + last 4 now edits it instead of
    stacking another.
- ✂️ **Last-4 digits cut 2026-08-06, after testing.** User: *"feels sketchy and
  isn't terribly useful."* Agreed — storing part of a card number invites the
  "does this app hold my card details?" question the feature exists to avoid,
  and it earned nothing: the abbreviation already tells cards apart, and it
  never appeared on a transaction row. A card is now just **name +
  abbreviation**. `cardKey` (dedupe + the `needsMerge` precheck) falls back to
  name alone, which is right: two cards a user can't tell apart on screen
  shouldn't stay separate in the store. Mockup updated to match.
  - Schema note: `PaymentCard` hasn't been promoted yet, so nothing in
    Production ever carried this. A `CD_last4` field may linger unused in the
    **Development** schema from an earlier Debug run — harmless, and not worth
    resetting the Dev environment over.
- Round-trip: `CardDTO` in the archive, `cardID` on `TransactionDTO`, both
  `decodeIfPresent`; CSV gains an export-only `card` column (names, not ids —
  a CSV is for reading in a spreadsheet). `resetAllData` clears cards too.

#### Original design note (idea, 2026-08-06)
User: *"add a credit card (manually, NOT connecting to it), then when making a
transaction, the option to add what card it was spent on… displayed inline with
the transaction, just like how a memo shows up. Maybe an abbreviation so it
doesn't take a ton of room. Sort based off the card as well. Add cards in
settings (name, maybe last 4 digits), then a simple picker when adding a
transaction. Optional, not required."*

**Mockup:** https://claude.ai/code/artifact/720964d1-12df-40a9-b81b-d0b49c5e558b
(list rows, plain-text vs. chip, Settings → Cards + editor, the picker, and the
by-card sort — with the open decisions called out.)

**Explicit non-goal: this is a label, not an account.** No balances, no
statement periods, no "how much do I owe on the Amex." It doesn't touch budgets
or the 50/30/20 math at all — a transaction counts exactly the same whichever
card carried it. Worth writing down because balance tracking is the obvious next
ask and it's a *much* bigger feature (it would need its own data model, payment
reconciliation, and a real answer for transfers).

- **New model `PaymentCard`:** `id`, `name` ("Chase Sapphire"), `abbrev`
  (short tag, cap ~6 chars), `last4` (optional), `isArchived`, `createdAt`.
  Must be added to the `Schema([...])` list in `AppModelContainer`.
- **Link by ID, NOT a SwiftData relationship.** `Transaction.cardID: UUID?`,
  mirroring the existing `recurringRuleID`. Two reasons: it matches the pattern
  the codebase already chose for CloudKit's sake, and a relationship with the
  wrong delete rule could **cascade-delete transactions** when a card is
  removed. A loose id can't. Deleting a card is then survivable by definition —
  the worst case is an unresolvable id, which renders as no card.
- **Resolve once, not per row.** `BudgetView` holds `@Query var cards` and
  builds a `[UUID: PaymentCard]` map, passing the resolved abbreviation into
  `TransactionRow`. A per-row lookup would be O(rows × cards) on every render.
- **Display — reuse the memo's caption line**, card BEFORE memo:
  `⟳ Aug 5 · CSP · Big dinner`. Order matters: the card is fixed-width
  structured data, the memo is free text that already truncates, so putting the
  card first means the truncation still lands on the thing designed to absorb
  it. ⚠️ That line now carries up to four things on an iPhone — check it on the
  smallest device before committing to plain text; the fallback is a small
  muted chip for the abbreviation, or dropping the card from the row and
  showing it only in the edit sheet.
- **Abbreviation:** auto-derive from initials ("Chase Sapphire" → "CS") or
  `•1234` when only last4 is given, always user-editable. Never auto-generate
  something the user can't override.
- **Settings → Cards** is a straight clone of the Recurring screen's shape:
  `CardsView` (list, swipe to delete, tap to edit) + `CardEditor` (name,
  abbreviation, last 4). That pattern already exists and works, so this is
  mostly assembly.
- **Picker in Add/Edit:** a `Picker` with "None" first, in the second section
  next to Date. Optional by default — no card is the normal case.
- **Sorting:** new `TxnSort` case, grouping by card name with **unassigned
  last** (an empty group at the top would be noise). 💭 *Filtering* by card is
  arguably more useful than sorting ("show me everything on the Amex"), but the
  filter pill row is already spoken for by categories — a second filter
  dimension is a separate design problem, not a freebie. Ship sort first.
- **Archive rather than hard-delete** where possible: `isArchived` hides a card
  from the picker while history still resolves its name. If a hard delete stays,
  its confirmation must say old transactions will lose the label.
- **Round-trip:** `ExportData` gains `cards: [CardDTO]?`, `TransactionDTO` gains
  `cardID` — both `decodeIfPresent`, so pre-1.3 backups import unchanged.
- 🔗 **Natural follow-on:** a `defaultCardID` on `RecurringRule` (rent always
  goes on the same card), and the AI command bar learning "on the amex". Both
  are cheap once the model exists; neither is v1.
- ⚠️ **CloudKit:** a new record type *plus* a new optional field on
  `Transaction`. Additive and safe, but it needs its own Dev→Production
  promotion unless it lands before 1.2 ships alongside `memo` and `endKey`.
- **Effort:** ~1 day.

### 💡 Advanced insights (idea, 2026-08-06) — and a correction on Private Cloud Compute
User asked about "more advanced insights, maybe powered by Apple Intelligence
private cloud compute?"

⚠️ **PCC isn't available to us.** The Foundation Models framework hands third-
party apps the ~3B **on-device** model only (`SystemLanguageModel.default`) —
there is no developer API for Private Cloud Compute. PCC backs Apple's *own*
system features (Siri, Writing Tools); apps can't call into it. So the realistic
options are (a) the on-device model Ledger already uses for the command bar, or
(b) our own server plus a hosted LLM — which would mean **transmitting the
user's financial data off-device**, contradicting the "on-device only, nothing
leaves your phone" line in Settings, the App Store privacy labels, and the
privacy pitch the featuring nomination leans on. (b) is a positioning decision,
not a technical one, and the answer is almost certainly no.

**The bigger point: most of the good insights don't need a model at all.**
`buildInsight` is already templated arithmetic. What's missing is *more
arithmetic*, not more language — and there's newly available data to compute on:

- **Trends:** category spend vs. a rolling 3-month average ("Wants up 22%").
- **Fixed vs. discretionary:** `recurringRuleID` already marks rule-driven
  charges — the split between committed and chosen spending is a genuinely
  useful number nobody surfaces.
- **By card:** now that `cardID` exists, "68% of Wants went on the Amex."
- **Biggest movers** between two months, by category and by merchant name.
- **Anomalies:** a transaction well outside the usual range for its category.
- **Streaks:** consecutive months hitting the savings target.
- **Forecast:** end-of-month projection from the existing pace math.
- **Year in review** — an annual version of the month recap, which is the kind
  of thing that gets shared.

**Where the on-device model genuinely helps:** turning those computed facts into
a paragraph that doesn't read like a template, and synthesising across several
of them ("your fixed costs rose while discretionary fell — you're spending less
by choice but committing more"). That's phrasing and connection, not maths.

🔒 **Rule if this gets built: the model NEVER does arithmetic.** Compute every
figure deterministically, pass the numbers in, let it only phrase them. An LLM
that quietly rounds or invents a number in a budgeting app is a trust-ending
bug, and it would be invisible in testing. Same discipline as the command bar,
which parses intent but doesn't compute balances.

- **Degradation is mandatory:** the on-device model needs Apple Intelligence
  hardware, so every insight must be fully useful with the model absent —
  `IntelligenceService.isAvailable` already gates the command bar this way.
  Model-written prose is a *garnish* on computed insight, never the substance.
- **Sequencing:** ship the arithmetic first. It works on every device, it's
  testable, and it's most of the value. Only then decide whether generated
  narrative earns its place.
- **Effort:** the computed insights are ~1–2 days spread across several cards;
  the narrative layer is half a day on top.

### v1.5 — advanced features
After the platforms are out, pull a focused few from the sections below
(reporting, budget rollover, watch complications, adjustable alert threshold,
native 3-D visionOS charts, …).
- 🎯 **Featuring nomination #2 rides this release:** the ambitious visionOS
  features (3-D Insights charts via Chart3D/RealityKit, spatial polish) are
  the editor-bait for a second, stronger "New on Vision Pro" nomination as a
  significant update. See `appstore/featuring-nomination.md` timing strategy.

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

**visionOS (polish shipped; spatial showcase planned for 1.x)**
- [x] **Native visionOS app** (device family 7 + `xros` SDK) — not "Designed for
      iPad." Runs as a glass window with eye/pinch interaction; themes apply.
- [x] **Spatial polish — shipped.** Bottom **ornament** for month navigation and
      a trailing **ornament** for the add button; **hover highlights** on custom
      rows/pills (also benefits the iPad pointer); a sensible **default window
      size**. All gated to visionOS (hover compiles out on macOS), so no effect
      on the iPhone/iPad/Mac build.
- **Goal for the next visionOS-focused release:** add a small amount of genuine
  spatial utility plus one memorable, screenshot-worthy showcase. Ledger should
  still feel like a calm budgeting tool, not a technology demo.
- (M) **Native spatial widget — highest utility.** Adapt the existing budget
  snapshot widgets for placement on a wall or desk. At a distance show the
  month + safe-to-spend amount; nearby reveal Needs / Savings / Wants progress
  and savings rate. Support visionOS proximity-aware detail and recessed /
  elevated mounting styles. This is the feature most likely to be useful every
  day even when the main app is closed.
- (S-M) **Consolidated Budget ornament.** Evaluate replacing the separate bottom
  month control and trailing add button with one intentional bottom rail:
  `‹  July 2026  ›    $1,284 safe    +`. This reduces eye travel, makes the
  controls read as one system, and puts Ledger's most valuable number outside
  the scrolling content. Verify in-headset before removing the current pair.
- (M) **Detachable Insights window.** Let the user open Insights beside Budget,
  synchronized to the selected month. Selecting a chart mark can filter or
  reveal the matching transactions in the main window. Windows open only on
  request; Ledger never scatters multiple windows automatically.
- (M) **Spatial month-close recap.** Give the existing recap a restrained
  visionOS presentation: the three bucket results settle at shallowly different
  depths, budget markers reveal the final variance, then savings rate and the
  month-over-month change appear. Keep ordinary controls for Open in Budget and
  Share Recap; support Reduce Motion and avoid a Full Space.
- (M-L) **Signature feature — Spatial Budget Board.** An optional volume or
  dedicated spatial Insights view with three data-driven columns for Needs,
  Savings, and Wants. Column height represents actual spending; a translucent
  budget marker shows the limit; remaining / overspent space is immediately
  legible. Look to highlight, pinch to inspect transactions, and animate between
  months. Prefer Swift Charts `Chart3D` / 3D `RectangleMark` on visionOS 26;
  use RealityKit only if Chart3D cannot deliver the interaction or finish.
- **Recommended sequence:** spatial widget -> consolidated ornament ->
  detachable Insights -> Spatial Budget Board -> recap depth polish. The widget
  supplies lasting utility; the Budget Board supplies the App Store / featuring
  story.
- **Restraint:** no immersive budgeting room, floating currency or coin stacks,
  constant particles, decorative depth on text, or automatic window spawning.
  Use depth only to communicate budget, actual, variance, selection, or hierarchy.

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
- (M-L) **Native 3-D Insights on visionOS** — tracked as the Spatial Budget
  Board in the visionOS plan above. Gate to visionOS 26 and keep the existing
  2-D charts as the accessible, cross-platform presentation.

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
- ✅ **Accessibility pass — VoiceOver + Dynamic Type + Reduce Motion done**
  (2026-07-08; grouped elements, spoken categories on txns, labels on
  image-only visionOS buttons, filter selected-state). **Still open (before
  claiming everything on the ASC accessibility form):**
  - **Differentiate Without Color Alone** — category is conveyed by dot COLOR
    only; sighted color-blind users need a shape/icon per bucket (small glyph
    in the dot, or distinct shapes). NOT done — don't check that ASC box yet.
  - **Sufficient Contrast** — never ran a real contrast-ratio audit across the
    three themes; verify (esp. muted text + Minimal/Modern) before claiming.
  - **Larger Text** — fonts use `relativeTo:` so they scale, but layout at the
    largest Dynamic Type sizes is untested (clipping/truncation in tight
    HStacks). Verify on-device.
  - Voice Control likely works (standard controls) but untested.
- Currency picker (today follows device locale only)
- Final palette tuning + font decision
- Optional: live **"Syncing…"** state on the sync status panel

## Growth & marketing (post-launch levers — logged 2026-07-08)
Ranked by effort-to-impact for a solo $0.99 app. None done yet.
- **Product Page Optimization** (ASC → Growth & Marketing) — free built-in A/B
  test of icon/screenshots. Turn on now; needs traffic to get a signal.
- **Custom Product Pages** — alternate screenshot sets per traffic source
  (e.g. a Vision-Pro-first page for a r/VisionPro link). Free, per-URL trackable.
- **The recap / share-card feature (v1.2)** — the only *compounding* channel:
  a shareable "closed my month, saved 10%" card spreads without per-user effort.
  Treat as the real growth investment, not just a feature.
- **Reddit** (r/personalfinance, r/visionpro — thin catalog, r/sideproject,
  r/iOSProgramming build-in-public), **Product Hunt** launch — free, time only;
  "I built X, here's why" beats "check out my app."
- **Apple Search Ads Basic** — small capped test to boost chart velocity +
  earn more organic reviews; thin margin at $0.99, not a profit play.
- Not worth it now: press outreach, paid influencers (don't pencil at $0.99).
- Verify **Small Business Program** enrollment (15% vs 30% commission).

## visionOS design — native glass treatment (logged 2026-07-08)
Observed other visionOS budget apps (MoneyCoach, Expenses/Blue Comet) using the
**system glass window** — a translucent frosted panel the room shows through —
where Ledger currently paints an **opaque dark fill** over the glass, so it reads
as a solid black slab floating in the room instead of a native panel.
- **Root cause:** every main view applies `.background(DS.background
  .ignoresSafeArea())` (RootView, BudgetView, SettingsView, RecurringView,
  AddTransactionView — 5 files), which covers the default `WindowGroup` glass.
- **First pass (low-risk, visionOS-gated):** on visionOS only, drop the opaque
  window fill so system glass shows; keep opaque `DS.surface` cards for content
  contrast. Gives the floating-glass look with zero change to iOS/Mac.
- **Fuller pass:** convert primary surfaces to a material (`.regular` glass) so
  the panels themselves are translucent like the reference apps — needs
  **on-device iteration** (glass reads totally differently in the headset).
- ⚠️ **Theme interaction:** glass pairs with **light content (dark) themes** —
  white/primary text on a frosted panel. The **Light** theme (dark text) would
  be low-contrast on glass showing a bright room. Options: (a) keep opaque
  cards so theme text-contrast is preserved and only the window backdrop is
  glass; (b) on visionOS pin to the glass/light-content treatment and let the
  theme picker drive accent/category/personality only, de-emphasizing the
  Light/Dark override there. Decide during the on-device pass.
- Candidate for a v1.5 visionOS-polish release (pairs with the 3-D charts +
  featuring nomination #2).

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

## Ideas for down the road (parking lot, not commitments)

These are deliberately parked ideas, not a plan to build everything below.
Several would dilute Ledger if promoted into the default workflow. Revisit them
only when user behavior or repeated requests justify the added surface area.

**Core test for every future feature**
> Does this make it easier to answer: What can I spend, where did it go, or how
> did the month end?

Guardrails:
- Needs / Savings / Wants remain the permanent top-level model.
- Additional detail is optional, inferred, or progressively disclosed.
- Prefer features that reuse existing transactions over features that demand
  more setup or daily bookkeeping.
- Financial calculations stay deterministic. AI can extract, categorize, or
  summarize grounded results, but never owns arithmetic or mutates without
  review and confirmation.
- Preserve local-first / private-iCloud behavior and useful offline operation.
- Give each release one coherent story rather than shipping a pile of unrelated
  additions.

**Confidence and insight candidates (roughly 1.5 territory)**
- **Reliability foundation:** automated coverage for sync reconciliation,
  imports, recurring transactions, month close/reopen, and money calculations;
  locale-correct money entry; CSV recurring-item protection; explicit save
  errors; less CloudKit churn; and a deliberate money-representation strategy.
  Mostly invisible, but it protects the numbers users trust.
- **Projected month outcome:** "At this pace, you'll finish with $430 left,"
  projected Needs / Wants variance, daily or weekly safe-to-spend, and flexible
  money after known recurring commitments. Derive it from existing data; no new
  required setup.
- **Focused reporting:** month-over-month bucket comparison; 3 / 6 / 12-month
  savings-rate trend; average Needs / Wants spend; largest changes from the
  previous month; tap a chart to reveal the transactions behind it. Avoid a
  customizable analytics-dashboard product.
- **visionOS showcase:** spatial widget, detachable Insights, Spatial Budget
  Board, and restrained recap depth. Detailed and sequenced in the visionOS
  section above.
- **Shareable recap:** an optional privacy-conscious month-close image with the
  month, savings rate, safe-to-spend result, and bucket outcomes. Hide income
  and exact amounts unless the user explicitly includes them.

**Planning without bookkeeping (possible 1.x follow-ons)**
- **Optional rollover:** separately choose whether each bucket resets, carries
  remaining money, or carries overspending. Default behavior stays the simple
  monthly reset; Savings can optionally accumulate.
- **Savings goals beneath Savings:** Emergency Fund, Vacation, New Computer,
  etc., with target amount and optional date. Goals are an optional layer inside
  Savings, never a fourth top-level bucket.
- **Lightweight purchase types:** Dining, Groceries, Transport, Subscriptions,
  Health, Shopping, etc. Suggested automatically from descriptions, editable,
  never required, and hidden unless richer insights are enabled. The three
  primary buckets remain the main classification.
- **Recurring-commitments forecast:** upcoming known charges, flexible money
  after commitments, expected dates, and unusually changed or missing recurring
  expenses. Do not turn this into a full bill-management calendar.
- **Grounded scenario tool:** a small "Can I afford this?" calculation using the
  current bucket, known commitments, and time remaining. It should explain the
  trade-off, not offer financial advice.

**Possible 2.0 directions — pick one, not all**
- **Shared Household Ledger:** invite a partner with CloudKit sharing; shared
  months and transactions; contributor attribution; clear shared-vs-personal
  boundaries; conflict-safe recurring rules. Highest functional expansion, but
  also the largest change to Ledger's single-user identity and sync complexity.
  Build only after repeated demand.
- **Goals and forward planning:** deeper Savings goals, planned purchases,
  optional rollover, recurring-income / expense forecasting, and grounded
  scenarios. This is the safest way to deepen Ledger without changing ownership
  or privacy; currently the preferred conceptual direction.
- **Frictionless capture:** receipt scan -> transaction draft, natural-language
  multi-entry, stronger Siri / Shortcuts support, and privately synced merchant
  memory. Capture should reduce typing, not turn Ledger into a receipt archive.

**High-risk scope expansion — approach cautiously or decline**
- **Bank synchronization:** operationally expensive, privacy-sensitive, commonly
  subscription-funded, and changes Ledger from a private manual budget into a
  financial-data service.
- **AI financial advice or open-ended financial Q&A:** high trust, grounding, and
  liability risk. Keep AI constrained to extraction, optional categorization,
  and summaries of Swift-computed facts.
- **Debt payoff systems, investments, net-worth tracking, or tax features:**
  valuable but effectively separate products that would blur the monthly-budget
  promise.
- **Too many required categories or tags:** setup and maintenance begin to feel
  like accounting. Any richer taxonomy must remain optional.
- **Mandatory receipt storage or attachments:** adds permissions, storage,
  backup, and privacy burden for limited core value.
- **Social comparison, streak pressure, or heavy gamification:** poor fit for
  private financial behavior and Ledger's calm tone.
- **A subscription for basic budgeting:** conflicts with the current simple,
  private, no-ads brand. If monetization expands, keep the core product honest
  and understandable.

This section is an idea shelf. Moving an item into a release plan requires a
clear user problem, a simplicity check, and an explicit decision about what does
*not* get built alongside it.

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
- **Ambitious visionOS** — see the focused 1.x visionOS plan above: spatial
  widget, detachable Insights, and the Spatial Budget Board. Keep reporting
  calculations shared with the existing 2-D Insights and recap views.
- **Round-trip export** to the original web-app JSON format (compatibility).
