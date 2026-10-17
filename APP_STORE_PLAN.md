# LandlordLedger App Store Submission Plan

## Positioning

**Working app name:** LandLedger

**Naming status:** Use `LandLedger` as the App Store listing name. Confirm availability in App Store Connect before the next upload; only App Store Connect can verify final name availability.

**One-line promise:** Know what each rental earned—without connecting your bank.

**Primary audience:** Small rental-property owners using iPhone who currently use spreadsheets, Stessa, bank CSV exports, or manual notes to prepare Schedule E tax reports.

**Core differentiator:** Private, on-device categorization from bank CSV imports. No bank login required.

## App Store Metadata

### App Name

**LandLedger** (10 characters). Use this exact name for the listing and installed app to align the brand with LandMiles. Confirm availability in App Store Connect before submission.

### Subtitle

**Landlord Rent & Expense Tracker** (30 characters).

### Keyword Field

```text
property,tax,schedule e,receipt,tenant,zelle,csv,bookkeeping,real estate,income,rental
```

This field is 86 ASCII bytes. It complements the name and subtitle without repeating their words. Keywords describe existing features; search-volume performance has not been measured.

### Name Implementation

Use LandLedger for the listing, installed display name, onboarding, paywall, exports, and support pages. Preserve existing bundle IDs, StoreKit product IDs, project names, and hosted support URLs.

### Companion App

LandMiles tracks property-related mileage. Link to https://apps.apple.com/app/id6760436282 from Settings and the landing page. These are separate apps; this link does not sync records or share purchases.

Apple metadata references: https://developer.apple.com/app-store/product-page/ and https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information

### Promotional Text

Track rent. Organize expenses. Export property reports for your accountant. Import Chase CSV files without connecting your bank account.

### Short Description

Know what each rental earned. LandLedger helps small landlords organize rental income, expenses, and property reports without connecting a bank account.

### Full Description Draft

Know what each rental earned—without connecting your bank.

LandLedger helps small landlords turn rental transactions into organized property records. Import a Chase CSV or add transactions manually, review suggested matches, and prepare summaries for your accountant.

TRACK RENT AND EXPENSES
Keep rental income and expenses organized by property. Match rent payments to tenants and see income, expenses, and net income together.

ORGANIZE TRANSACTIONS FASTER
Import Chase CSV files or paste CSV text. Review uncertain matches in Inbox and save corrections for repeated payees and tenant payment names.

KEEP RECEIPTS WITH YOUR RECORDS
Attach receipts, invoices, and other supporting files to the matching transaction.

EXPORT PROPERTY REPORTS
Review tax-year summaries and export PDF reports with LandLedger Pro or a one-time Tax Export Pass. Core bookkeeping is free; PDF export requires an in-app purchase.

NO BANK LOGIN
Work with records on your device. LandLedger does not require your bank username or password.

ALSO FROM US
Track property-related mileage with our companion app, LandMiles. The apps are available separately.

LandLedger is an organizational tool and does not provide tax, legal, or accounting advice. Review records with a qualified professional before filing.

Terms of Use: https://imentos.github.io/LandlordLedger/terms.html
Privacy Policy: https://imentos.github.io/LandlordLedger/privacy.html

## Screenshot Plan — LandMiles Family Style

Reference: RealEstateMileageTracker/screenshots/final/03-export-irs-reports.png and scripts/generate_app_store_screenshots.py.

Use the same teal (#0D5C63), large bold white action headlines, two short supporting lines, and a prominent phone frame. Preserve real LandLedger UI and its bookkeeping-specific content. Existing docs/assets images are previously composed marketing screenshots; obtain raw captures before rebuilding them to avoid nesting captions or phone frames.

| Order | Headline | Supporting lines | Actual app screen |
|---|---|---|---|
| 1 | TRACK | RENT AND / EXPENSES | Transactions with fictional rent and expense entries |
| 2 | ORGANIZE | RECORDS BY / PROPERTY | Property ledger and income/expense summary |
| 3 | EXPORT | REPORTS FOR / YOUR ACCOUNTANT | Reports with PDF export control |
| 4 | REVIEW | SUGGESTED / MATCHES | Inbox showing uncertain categorization |

First three screenshots communicate the core workflow, following LandMiles' action-led presentation. Use no guaranteed savings, automatic bank syncing, or tax-filing claims. Verify screenshot sizes against the current App Store upload requirements before submission.

## Brand Family

LandMiles: property trips and mileage records.
LandLedger: rental income, expenses, and property reports.

Shared presentation: short Land-prefixed names, property context, bold action headlines, teal marketing backgrounds, and clear report value. Keep each app's icon recognizable; the existing LandLedger icon is retained in this pass. Do not copy LandMiles' car symbol into bookkeeping assets.

## App Icon Direction

Concept: a clean ledger page and building mark, with a subtle checkmark or dollar line to communicate bookkeeping, property ownership, and completed tracking.

Style:

- Professional, calm, financial
- Readable at small sizes
- Avoid tiny text
- Avoid realistic house photos
- Avoid gradients that look like a generic fintech app

Palette:

- Teal marketing background (#0D5C63), matching LandMiles screenshot presentation
- White or off-white ledger/building shape
- Green accent for income/checkmark

## Privacy Checklist

Support URL:

```text
https://imentos.github.io/LandlordLedger/support.html
```

Privacy Policy URL:

```text
https://imentos.github.io/LandlordLedger/privacy.html
```

Terms of Use URL:

```text
https://imentos.github.io/LandlordLedger/terms.html
```

Likely privacy stance:

- No account creation
- No bank login
- No analytics unless added later
- No third-party tracking
- Financial data stored locally with SwiftData
- CSV files selected by user are imported into local app storage

Before submission:

- Add a privacy policy URL.
- Confirm whether iCloud backup/sync is used. If not, state local-only storage.
- Fill App Privacy details in App Store Connect based on actual data collection.
- If no data leaves the device, say so plainly in the privacy policy.

## App Review Notes

Suggested review note:

```text
LandLedger is a local rental bookkeeping app. It does not require login or a bank connection. To test, add a sample property, use the Import tab to add a manual transaction, or import a CSV with columns similar to: Details, Posting Date, Description, Amount, Type, Balance.
```

## TestFlight Checklist

1. Set bundle identifier and version/build number.
2. Confirm app icon is present in the asset catalog.
3. Create a clean sample dataset for screenshots and review.
4. Test first-run with no properties.
5. Test manual transaction add.
6. Test CSV import with the Chase sample file.
7. Test duplicate import skip.
8. Test Inbox review and learned matching.
9. Test property transaction move back to Inbox.
10. Test export paywall, purchase restore, and unlocked export/share flow.
11. Archive in Xcode.
12. Upload to App Store Connect.
13. Add internal TestFlight testers.
14. Fix any crash logs or review feedback.

## Monetization Options

Start simple:

- Free to add properties, import/paste CSV text, review Inbox, and organize transactions.
- Gate PDF tax export behind StoreKit at the moment the user taps export.
- Offer `LandLedger Pro` as a yearly subscription using product ID `landledger.pro.annual`.
- Offer `Tax Export Pass` as a one-time non-consumable using product ID `landledger.tax_export_pass`.

Recommended first App Store release: free workflow with paid tax export. Start with **$29.99/year** for Pro and **$9.99 one-time** for Tax Export Pass.

Subscription disclosure checklist for paywall and review:

- Clearly show what LandLedger Pro unlocks before asking for purchase.
- Show price and billing period, for example `$29.99/year`.
- State that the annual subscription auto-renews unless canceled.
- Include Restore Purchases.
- Provide Terms of Use and Privacy Policy URLs in App Store Connect.

## Pre-Submission Engineering Tasks

- Replace any real sample data with demo data.
- Add final app icon.
- Add launch screen polish if needed.
- Add privacy policy link.
- Confirm minimum iOS version.
- Confirm app name spelling: current project uses `LandloardLedger`; App Store listing name should be `LandLedger`; installed display name is set to `LandLedger` for Debug and Release.
- Confirm App Store device support is iPhone only.
- Add crash-safe handling for malformed CSV files.
- Add a short onboarding empty state: add property, import CSV, review Inbox, export.
- Run one full clean install test on a device.

## Submission Order

1. Finalize icon and display name.
2. Prepare fake screenshot data.
3. Capture screenshots.
4. Write privacy policy.
5. Archive and upload TestFlight build.
6. Internal TestFlight QA.
7. Create App Store listing metadata.
8. Submit for review.

## Campaign Links

Landing page App Store campaign URL:

```
https://apps.apple.com/app/apple-store/id6769927934?pt=117813104&ct=landledger_landing_page&mt=8
```
