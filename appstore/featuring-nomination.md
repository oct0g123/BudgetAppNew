# App Store Featuring Nomination — Ledger

Paste-ready material for **App Store Connect → Featuring → Nominations**.
Nominations are free, human-read, and repeatable per meaningful moment — so the
plan is TWO nominations (see "Timing strategy" at the bottom).

---

## Nomination type
**App launch** (for the v1.1 all-platforms moment) — or **Significant update**
if submitted later for v1.2/v1.5.

## One-line description
Ledger is a calm, private budgeting app built on the 50/30/20 rule — native on
iPhone, iPad, Mac, and Apple Vision Pro, with on-device intelligence and no
data collection at all.

## The pitch ("Why should we feature this app?")

> Ledger is a one-person indie app that takes a deliberately different path
> from every big budgeting app: no bank logins, no accounts, no ads, no
> analytics — its App Privacy label is simply **"Data Not Collected."** Your
> income splits into Needs, Savings, and Wants; the app shows what's safe to
> spend; and everything stays on device or in the user's own iCloud.
>
> It's built natively in SwiftUI for **iPhone, iPad, Mac, and Apple Vision
> Pro** — not a compatibility port on any of them. On Vision Pro it uses
> ornaments for month navigation and a layered parallax icon; on iOS 26 it
> adopts Liquid Glass, including a tab-accessory "safe to spend" bar.
>
> Its standout feature is the **"Tell Ledger" command bar, powered by Apple's
> on-device Foundation Models**: type "spent $80 on groceries and $25 on a
> movie" and Ledger drafts categorized transactions for review — processed
> entirely on device, in keeping with the app's privacy stance. The model
> extracts; Swift validates and computes, so the figures are always right.
>
> Ledger is what personal finance looks like when it's built Apple-first:
> private by architecture, native everywhere, and calm by design.

## Apple technologies adopted (the editors' checklist)
- **Foundation Models framework** — on-device natural-language transaction
  entry (Apple Intelligence), with a deterministic Swift validation layer
- **SwiftUI** end-to-end, one codebase, four platforms (iOS, iPadOS, macOS,
  visionOS — all native targets, no Catalyst, no "Designed for iPad")
- **SwiftData + CloudKit** — private-database sync via the user's own iCloud
- **WidgetKit** — Home Screen + Lock Screen widgets (safe-to-spend, buckets,
  savings goal)
- **App Intents** — Siri phrases, Shortcuts, Action Button quick-add,
  "What's safe to spend?" voice query
- **Liquid Glass (iOS/macOS 26)** — tab accessory bar, glass filter capsule
- **visionOS** — scene ornaments, layered app icon, hover effects
- **Local Authentication** — Face ID / Touch ID / Optic ID app lock (named
  correctly per platform)
- **StoreKit** RequestReviewAction, **Swift Charts** (Insights), full **Dark
  Mode** + three hand-tuned themes

## Accessibility
*(Complete the accessibility pass before submitting — then list:)*
- Dynamic Type throughout · VoiceOver labels on all controls & charts ·
  Reduce Motion respected (chart entrance animations disable) · WCAG-checked
  contrast in all three themes · no time-limited interactions

## Privacy & business model
- App Privacy: **Data Not Collected** (no analytics, no third-party SDKs,
  no accounts). CloudKit private database only — developer can access nothing.
- Paid up front ($0.99), no IAP, no ads, no subscription. One honest price.

## Availability
- United States (launch market), all four platforms under one purchase
  (universal). English.

## Suggested placements
- **"New on Vision Pro" / visionOS collections** (primary target — native
  finance apps are rare on the platform)
- Mac App Store: Finance / "Apps for getting organized"
- iOS: Finance category features, privacy-themed collections
  ("Apps that respect your data"), Apple Intelligence showcases

---

## Timing strategy

**Nomination 1 — when v1.1 is live on all four platforms** (the launch
moment). Launches are the strongest editorial hook; the visionOS-native debut
IS the story. Costs nothing, decided by humans, repeatable.

**Nomination 2 — at v1.5** with the ambitious visionOS features (native 3-D
Insights charts via Chart3D/RealityKit) as a "Significant update" nomination —
a second, stronger swing specifically at the Vision Pro collections.

> Recommendation: don't sit on Nomination 1 waiting for 1.5 — editors feature
> launches more readily than updates, and a decline costs nothing. Nominate at
> 1.1, again at 1.5.

## Pre-nomination checklist
- [ ] **Accessibility pass** (Dynamic Type / VoiceOver / contrast) — the one
      real gap editors check
- [ ] v1.1 live on iOS + macOS + visionOS (all listed on the product page)
- [ ] Product page complete: all-platform screenshots, updated keywords
- [ ] Fill the nomination form from this doc
