# What's New — Ledger 1.2

Paste-ready copy for the App Store Connect **What's New in This Version** field.
One platform caveat at the bottom — see **Before submitting**.

---

## Primary (recommended)

```
Know what you can spend this week
The bar above the tabs now shows what is left for Wants this week, not just
for the month. It resets each week and adjusts to what you have already
spent, so it is a number you can act on before you buy something.

Cards
Add your cards by hand in Settings and tag a transaction with the one you
paid with. Ledger never connects to an account and never sees a card
number — it is a label, so you can finally answer "how much of this went on
the Amex". Sort the list by card, too.

Notes on transactions
Add a short note to any transaction — "split with Kate", "reimbursable" —
and search your notes right alongside descriptions.

Recurring transactions that end
Paying something off over three months? A recurring transaction can now
stop on its own after a set number of months. Recurring charges are also
marked in the list, so a month's fixed costs stand out at a glance.

A proper Mac app
Ledger on the Mac now has a real menu bar: New Transaction, month
navigation, Find, and export all have keyboard shortcuts, and Settings
opens in its own window. The week's spending sits in the toolbar.

Fixes
• The number pad can be dismissed again, and editing your income no longer
  lags as you type.
• Editing a recurring transaction no longer changes months that have
  already been and gone.
• Budget pacing reads in whole dollars, so it is clearer that it is an
  estimate rather than an exact figure.
```

---

## Short version

```
• Your Wants budget for the current week now lives in the bar above the
  tabs — it resets weekly and adjusts to what you have already spent.
• Add your cards by hand and tag transactions with how you paid. No account
  connection, no card numbers.
• Add notes to transactions, and search them.
• Recurring transactions can now end after a set number of months.
• Ledger on the Mac gains a full menu bar and its own Settings window.
```

---

## Promotional text (optional, 170 characters)

Editable any time without submitting a build — a free place to test hooks.

```
Know what you can spend this week, not just this month. Ledger splits your
pay into Needs, Savings and Wants — privately, on your device.
```

---

## Before submitting

1. ✅ **CloudKit schema promoted 2026-08-29.** All three additions
   (`Transaction.memo`, `RecurringRule.endKey`, `PaymentCard` + `Transaction.cardID`)
   are live in Production. The deploy was additions only — 3 record-type changes,
   3 index groups, and permission entries for the new type on the `_world` /
   `_icloud` / `_creator` roles, which is routine bookkeeping when a record type
   is added. No further schema work is needed for 1.2.
2. **`MARKETING_VERSION` is already 1.2** on both targets (bumped 2026-08-29).
   Build number stays 1, which is right for a new train.
3. **Build all four targets before archiving.** A lot of `#if`-gated Mac code has
   never been seen by the iOS compiler, and vice versa.
4. **Keywords are version-locked** — change them before the build goes to review
   if you want to.
5. ⚠️ **visionOS only:** the weekly bar rides the tab accessory, which visionOS
   doesn't have. Mac now shows it in the toolbar, so only the Vision Pro listing
   overstates it — drop that first paragraph there, or use the short version
   without its first bullet.
