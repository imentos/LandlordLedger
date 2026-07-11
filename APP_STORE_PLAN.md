# LandlordLedger App Store Submission Plan

## Positioning

**Working app name:** RentalKeeper

**Naming status:** Use `RentalKeeper` as the next App Store listing name candidate. Confirm availability in App Store Connect before the next upload; only App Store Connect can verify final name availability.

**One-line promise:** Simple rental income and expense tracking for small landlords.

**Primary audience:** Small rental-property owners using iPhone who currently use spreadsheets, Stessa, bank CSV exports, or manual notes to prepare Schedule E tax reports.

**Core differentiator:** Private, on-device categorization from bank CSV imports. No bank login required.

## App Store Metadata

### Title Options

Use `RentalKeeper` as the primary title candidate. Keep fallback options ready in case App Store Connect reports that the name is unavailable.

1. RentalKeeper (10)
2. RentalKeeper Rent (15)
3. RentalKeeper CSV (14)
4. Property Rent Ledger (20)
5. Rental Tax Ledger (17)
6. Small RentalKeeper (21)
7. Rent Ledger Organizer (21)
8. Rental Property Books (21)
9. Landlord CSV Tracker (20)
10. Property Income Ledger (22)
11. Rent Expense Ledger (19)
12. Schedule E Ledger (17)

Recommended: **RentalKeeper**

Rationale: `RentalKeeper` is short, brandable, and more directly tied to rentals than the previous name. The subtitle and keywords should carry the functional search terms: landlord, rent, property, tax, CSV, and expense.

Fallback if unavailable: **RentalKeeper Rent**, then **RentalKeeper CSV**, then **Property Rent Ledger**.

### Subtitle Options

Apple subtitle limit is 30 characters. Because the recommended title no longer contains `Landlord`, keep that search term in the subtitle.

1. `Landlord Rent Tracker` (21)
2. `Property Tax Organizer` (22)
3. `Income & Expense Tracker` (24)
4. `Schedule E Organizer` (20)

Recommended: **Landlord Rent Tracker**

### Keyword Field

App Store Connect keyword field is limited, so avoid words already in the title/subtitle when possible. With `RentalKeeper` + `Landlord Rent Tracker`, avoid repeating `rental`, `keeper`, `landlord`, `rent`, and `tracker`. Keep `csv` because the title no longer includes it.

Recommended keyword string:

```text
property,tax,schedule e,expense,receipt,tenant,zelle,csv,bookkeeping,real estate
```

Shorter no-space variant if App Store Connect rejects spaces:

```text
property,tax,schedulee,expense,receipt,tenant,zelle,csv,bookkeeping,realestate
```

### Name Implementation

Recommended path:

1. Try `RentalKeeper` as the App Store name.
2. If accepted, keep the installed app display name as `RentalKeeper` so the installed app and listing match.
3. If unavailable, try `RentalKeeper Rent`, then `RentalKeeper CSV`, then `Property Rent Ledger`.
4. Keep the bundle identifier as-is for now unless App Store Connect requires a new app record. Bundle ID uniqueness is separate from App Store listing-name uniqueness.
5. Do not rename the Xcode project/target yet; that internal cleanup can wait until after the listing is accepted.

### Promotional Text

Track rental income and expenses from Chase CSV imports, review uncertain matches, and export property-ready tax summaries without connecting your bank account.

### Short Description

RentalKeeper helps small landlords organize rental property income and expenses from bank CSV files. Import transactions, review uncertain matches, link rent payments to tenants and properties, and export tax-ready summaries for your records.

### Full Description Draft

RentalKeeper is a simple rental bookkeeping app for small property owners.

Import bank CSV transactions, categorize income and expenses, review uncertain items in an inbox, and keep each property’s ledger organized for tax season.

Features:

- Import Chase CSV files or paste CSV text
- Add manual transactions for cash payments or off-bank expenses
- Auto-categorize common Schedule E categories
- Match rent payments to tenants and properties
- Review uncertain transactions in Inbox
- Learn repeated payees and tenant payment names
- Track property income, expenses, and net income
- Export tax-year summaries for your records
- Works on device without connecting your bank account

RentalKeeper is designed for owners who want a practical alternative to spreadsheets or expensive rental bookkeeping tools.

Important: RentalKeeper is an organizational tool and does not provide tax, legal, or accounting advice. Please consult a qualified professional for tax filing decisions.

## Screenshot Plan

This is an iPhone-only app. Apple allows 1-10 screenshots per device class. Start with 6 portrait screenshots for the highest required iPhone size and let App Store Connect scale where acceptable.

Recommended screenshots:

1. **Import CSV Fast**
   - Show Import screen with Choose Chase CSV and Paste CSV Text.
   - Caption: `Import bank CSV files`

2. **Review Inbox**
   - Show Inbox with a few pending transactions and search.
   - Caption: `Review uncertain matches`

3. **Fix and Learn**
   - Show expanded transaction card with property/category chips.
   - Caption: `Correct once, remember next time`

4. **Tenants and Units**
   - Show property detail with unit groups and tenants.
   - Caption: `Track tenants by unit`

5. **Property Ledger**
   - Show property income/expenses/net summary and monthly transactions.
   - Caption: `See each property clearly`

6. **Tax Export**
   - Show export screen or generated PDF preview.
   - Caption: `Export year-end summaries`

Use sample/fake property and tenant data. Do not use real bank account names, real addresses, or real tenant names in screenshots.

## App Icon Direction

Concept: a clean ledger page and building mark, with a subtle checkmark or dollar line to communicate bookkeeping, property ownership, and completed tracking.

Style:

- Professional, calm, financial
- Readable at small sizes
- Avoid tiny text
- Avoid realistic house photos
- Avoid gradients that look like a generic fintech app

Palette:

- Deep blue background
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
RentalKeeper is a local rental bookkeeping app. It does not require login or a bank connection. To test, add a sample property, use the Import tab to add a manual transaction, or import a CSV with columns similar to: Details, Posting Date, Description, Amount, Type, Balance.
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
- Offer `RentalKeeper Pro` as a yearly subscription using product ID `landledger.pro.annual`.
- Offer `Tax Export Pass` as a one-time non-consumable using product ID `landledger.tax_export_pass`.

Recommended first App Store release: free workflow with paid tax export. Start with **$29.99/year** for Pro and **$9.99 one-time** for Tax Export Pass.

Subscription disclosure checklist for paywall and review:

- Clearly show what RentalKeeper Pro unlocks before asking for purchase.
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
- Confirm app name spelling: current project uses `LandloardLedger`; App Store listing name should be `RentalKeeper`; installed display name is set to `RentalKeeper` for Debug and Release.
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
