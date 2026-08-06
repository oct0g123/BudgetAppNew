# What's New — Ledger 1.2

Paste-ready copy for the App Store Connect **What's New in This Version** field.
Same text works for all four platforms (iPhone, iPad, Mac, Vision Pro) — see the
platform note at the bottom before shipping.

---

## Primary (recommended)

```
This week, at a glance
The bar above the tabs now shows what you have left to spend on Wants this
week — not just for the month. It resets each week and adjusts to what you
have already spent, so it is a number you can actually act on before you buy
something.

Notes on transactions
Add a short note to any transaction — "split with Kate," "reimbursable" — and
search your notes right alongside descriptions.

Recurring transactions are marked
Rent, subscriptions, and anything else driven by a recurring rule now carry a
small repeat symbol, so a month's fixed costs stand out at a glance.

Fixes and refinements
• The number pad now has a Done button, and scrolling dismisses it — no more
  stuck keyboard while editing your income.
• Editing monthly income is quick again; it no longer stutters as you type.
• Budget pacing now reads "$778/wk pace" in whole dollars, so it is clearer
  that it is an estimate for the rest of the month.
```

---

## Short version

Use if you would rather keep it to a glance.

```
• Your Wants budget for the current week now lives in the bar above the tabs —
  it resets weekly and adjusts to what you have already spent.
• Add notes to transactions, and search them.
• Recurring charges are marked with a repeat symbol.
• Fixed a stuck keyboard when editing income, and the lag that came with it.
```

---

## Promotional text (optional, 170 characters)

Editable any time without submitting a build — useful for testing hooks.

```
Know what you can spend this week, not just this month. Ledger splits your pay
into Needs, Savings, and Wants — and now paces the week for you.
```

---

## Before submitting

1. **Promote the CloudKit schema.** 1.2 adds a `memo` field to `Transaction` —
   the only schema change in this release. Run a Development build (SwiftData
   adds the field to the Dev schema automatically), promote Dev → Production in
   the CloudKit Dashboard, *then* archive. Shipping before promoting means notes
   silently do not sync in production, with no error to notice.
2. **Bump `MARKETING_VERSION` to 1.2 on BOTH targets** (app and widget).
   Currently 1.1 in `project.pbxproj`. A released version closes its train, so
   uploads against 1.1 will be rejected.
3. **Keywords are version-locked** — if any need changing, do it before the
   build goes to review.
4. **Platform note:** the weekly bar is the tab accessory, which is iOS 26 and
   iPadOS 26 only. Mac and Vision Pro do not show it, so the first bullet
   overstates things there. Either use the short version minus that bullet for
   the Mac listing, or ship the macOS toolbar equivalent first (macOS revamp,
   Phase 2 in ROADMAP.md).
