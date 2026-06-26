# App Store release checklist — Ledger ($0.99)

Order roughly top-to-bottom. ✅ = I can help/draft · 👤 = you do it in a browser.

## 1. Paid Applications Agreement (required for $0.99)  👤
In **App Store Connect → Business** (or Agreements, Tax, and Banking):
- [ ] **Accept** the Paid Applications Agreement.
- [ ] **Banking:** add a bank account for payouts (routing + account number).
- [ ] **Tax forms** — see "Tax info" below.
- [ ] Confirm the agreement shows **Active** (all sections green). You cannot set
      a non-zero price until it is.

## 2. Hosting the privacy policy  👤 (file ✅ drafted: `docs/privacy.html`)
You need a **public URL**. Easiest options:
- **GitHub Pages** (free) — if `budgetappnew` is **public**: repo Settings →
  Pages → Source = `main` / `/docs` → your policy goes live at
  `https://oct0g123.github.io/budgetappnew/privacy.html`.
  *(If the repo is **private**, Pages needs a paid plan — instead make a tiny
  separate public repo for just this file, or use any free static host.)*
- Before publishing: set the **effective date** and **support email** in the file.

## 3. Production CloudKit  👤
- [ ] CloudKit Dashboard → your container → **Deploy Schema Changes to
      Production.** App Store builds use Production CloudKit; if your TestFlight
      testers synced across devices it's likely already deployed — **verify.**

## 4. Screenshots  👤 (I'll advise sizes/staging ✅)
Required per the device sizes you support:
- [ ] **iPhone 6.9"** (e.g. 15/16 Pro Max) — required.
- [ ] **iPad 13"** — required because the app supports iPad.
- [ ] (Apple Vision Pro / Mac have their own shots if you list those stores.)
Stage them from the Simulator with real-looking data (a month with a few
transactions, the buckets, an insight). 3–5 per size is plenty.

## 5. App metadata  ✅ drafted (`appstore/app-store-metadata.md`)  👤 to paste
- [ ] Subtitle, promo text, keywords, description, what's new.
- [ ] Category: Finance. Age rating: 4+. Support + privacy URLs.
- [ ] **App Privacy** questionnaire → **Data Not Collected**.

## 6. Pricing  👤
- [ ] Price tier **$0.99**, availability = all territories (or pick).

## 7. Build + submit  👤
- [ ] Archive in Xcode (Release) and upload the build (or reuse the TestFlight
      build if it's the version you want to ship).
- [ ] Attach the build to the App Store version, fill "App Review Information"
      (contact + notes; note there's **no login** required).
- [ ] **Encryption / export compliance:** same answer as TestFlight ("None of
      the algorithms…" → exempt).
- [ ] **Submit for Review.** Full App Review is stricter than the beta review;
      first review is typically 1–3 days.

---

## Tax info (US individual — what you'll need)
This is the standard App Store Connect process, not professional tax advice; at
$0.99 hobby scale it's trivial, but the forms must be on file to sell paid apps.

In **App Store Connect → Business → Tax Forms**, a US person completes a **W-9**,
which needs:
- Your **legal name** and **address**.
- A **Taxpayer Identification Number (TIN)** — either your **SSN** (fine for an
  individual / sole proprietor) **or** a free **EIN** from the IRS if you'd
  rather not hand over your SSN (irs.gov, ~10 minutes online).
- You do **not** need an LLC or business entity — an individual developer can
  sign as a sole proprietor.

Notes:
- Apple may also surface tax questionnaires for other regions; selling only on
  the US store, the **W-9 is the main one**. Apple's wizard walks you through it.
- Apple issues a **1099-K** only if you cross IRS thresholds (you won't at $0.99
  hobby volume), but you'd still report any income at tax time.
- **Banking** (separate from tax): a checking account Apple deposits payouts to.

If revenue ever becomes non-trivial, talk to an accountant — but for "ship it to
say I did it," this is just filling out the W-9 + adding a bank account once.
