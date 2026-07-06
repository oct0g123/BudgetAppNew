# App Store listing — Ledger — 50/30/20

Copy/paste-ready metadata for App Store Connect. Bracketed `[…]` items need a
choice or a value from you.

---

## Name (already set)
**Ledger — 50/30/20**  *(30-char limit; current name fits)*

## Subtitle  *(30-char limit — pick one)*
1. **Simple 50/30/20 budgeting**  *(25) ← recommended*
2. Private 50/30/20 budgeting  *(26)*
3. Budget: Needs/Savings/Wants  *(28)*

## Promotional text  *(170 chars; editable anytime without review)*
> A calm, private budget built on the 50/30/20 rule. Split your income into
> Needs, Savings, and Wants — track spending and sync across your devices,
> all on-device.

## Keywords  *(100-char limit, comma-separated, no spaces)*

**v1.0.1+ (current recommendation — keywords only change with a version update):**
```
budget,money,manager,expense,tracker,spending,savings,goal,planner,finance,personal,paycheck,bills
```
*(98 chars.)* Apple combines individual keywords across name + subtitle +
this field to match multi-word queries, so this unlocks the high-volume
phrases: **money manager, expense tracker, spending tracker, budget planner,
budget tracker, savings goal, personal finance, paycheck budget, bill
tracker.** Dropped from the 1.0 string: `50/30/20` (already indexed from the
app name — repeating wastes chars), `allowance` (low volume), `private`
(positioning, not a search query — it lives in the subtitle/description).

Rules: no competitor names (rejection risk; ignored anyway) · singular forms
(plurals match automatically) · no spaces after commas · never repeat
name/subtitle words.

*Shipped with 1.0:*
```
budget,50/30/20,money,savings,spending,expense,tracker,finance,paycheck,planner,allowance,private
```

**Later ASO levers (optional):**
- **Subtitle** outweighs the keyword field. "Simple 50/30/20 budgeting" is
  on-brand; "Budget, expenses & savings" (29) is worth more algorithmically.
  Revisit only if downloads plateau.
- **es-MX localization trick:** the US storefront also indexes the Spanish
  (Mexico) localization's keyword field — adding that localization doubles
  keyword space for US search.
- **Ratings count/velocity beats keyword tuning** — see the review-prompt
  item in ROADMAP.md.

## Description  *(4000-char limit)*
```
Ledger is a calm, private way to budget with the proven 50/30/20 rule.

Your income splits into three simple buckets — Needs, Savings, and Wants — and
Ledger shows you exactly where you stand at a glance. No spreadsheets, no bank
logins, no clutter.

BUILT ON 50/30/20
• Set your monthly income and let Ledger split it into Needs (50%), Savings
  (20%), and Wants (30%) — or customize the percentages to fit your life.
• Watch each bucket fill as you log spending, with clear "remaining" and
  "over budget" cues.
• Close out each month and start fresh; past months stay archived.

PRIVATE BY DESIGN
• No account, no sign-in, no ads, no tracking, no analytics.
• Your data lives on your device and syncs through your own iCloud — the
  developer never sees it.
• Optional Face ID lock.

EVERYWHERE YOU ARE
• Native apps for iPhone, iPad, Mac, and Apple Vision Pro.
• Home Screen and Lock Screen widgets for a glance at what's safe to spend.
• Quick-add with Siri, the Action Button, and Shortcuts.

THOUGHTFUL TOUCHES
• An on-device AI command bar: type "spent $40 on groceries and $12 on coffee"
  and Ledger drafts the transactions — processed entirely on your device.
• Budget alerts when a bucket nears or passes its limit.
• Beautiful themes with full Light and Dark support.
• Export your data anytime as JSON or CSV.

Ledger isn't trying to connect to your bank or sell you anything. It's a
simple, honest tool to help you spend with intention.
```

## What's New (version notes for 1.0)
```
The first release of Ledger. Thanks for trying it!
```

## URLs
- **Support URL** *(required)*: a public page where users can get help. Options:
  - Reuse your privacy-policy site (e.g. the GitHub Pages URL) with the contact
    email on it, **or**
  - your public GitHub repo URL.
- **Marketing URL** *(optional)*: leave blank, or the same site.
- **Privacy Policy URL** *(required)*: the hosted `docs/privacy.html` (see the
  release checklist for hosting).

## Category
- **Primary:** Finance
- **Secondary** *(optional):* Productivity

## Age rating
Answer **None** to every content question → **4+**.

## App Privacy ("nutrition label")
Answer **"No, we do not collect data from this app."** → label shows
**Data Not Collected**. Rationale: no analytics, no third-party SDKs, and data
synced via the user's own iCloud (CloudKit private database) is the user's data
that you cannot access — Apple does not count that as "collected."

## Pricing
- **Tier:** $0.99 (USD) — Apple maps it to local prices automatically.
- **Requires:** an **active Paid Applications Agreement** (banking + tax on
  file). See the release checklist.
