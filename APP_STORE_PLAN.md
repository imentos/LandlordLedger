# LandlordLedger App Store Submission Plan

## Positioning

**Working app name:** Landlord Ledger

**One-line promise:** Simple rental income and expense tracking for small landlords.

**Primary audience:** Small rental-property owners who currently use spreadsheets, Stessa, bank CSV exports, or manual notes to prepare Schedule E tax reports.

**Core differentiator:** Private, on-device categorization from bank CSV imports. No bank login required.

## App Store Metadata

### Title Options

1. Landlord Ledger
2. Rental Ledger
3. Landlord Ledger: Rent Tracker

Recommended: **Landlord Ledger**

### Subtitle Options

Apple subtitle limit is 30 characters.

1. `Rental Income & Expenses` (26)
2. `Rent & Expense Tracker` (22)
3. `Property Tax Organizer` (22)

Recommended: **Rental Income & Expenses**

### Keyword Field

App Store Connect keyword field is limited, so avoid words already in the title/subtitle when possible.

Recommended keyword string:

```text
property,tax,schedule e,expense,receipt,tenant,zelle,csv,bookkeeping,real estate
```

Shorter no-space variant if App Store Connect rejects spaces:

```text
property,tax,schedulee,expense,receipt,tenant,zelle,csv,bookkeeping,realestate
```

### Promotional Text

Track rental income and expenses from Chase CSV imports, review uncertain matches, and export property-ready tax summaries without connecting your bank account.

### Short Description

Landlord Ledger helps small landlords organize rental property income and expenses from bank CSV files. Import transactions, review uncertain matches, link rent payments to tenants and properties, and export tax-ready summaries for your records.

### Full Description Draft

Landlord Ledger is a simple rental bookkeeping app for small property owners.

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

Landlord Ledger is designed for owners who want a practical alternative to spreadsheets or expensive rental bookkeeping tools.

Important: Landlord Ledger is an organizational tool and does not provide tax, legal, or accounting advice. Please consult a qualified professional for tax filing decisions.

## Screenshot Plan

Apple allows 1-10 screenshots per device class. Start with 6 portrait screenshots for the highest required iPhone size and let App Store Connect scale where acceptable.

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
Landlord Ledger is a local rental bookkeeping app. It does not require login or a bank connection. To test, add a sample property, use the Import tab to add a manual transaction, or import a CSV with columns similar to: Details, Posting Date, Description, Amount, Type, Balance.
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
10. Test export/share flow.
11. Archive in Xcode.
12. Upload to App Store Connect.
13. Add internal TestFlight testers.
14. Fix any crash logs or review feedback.

## Monetization Options

Start simple:

- Free app while validating with your wife and a small user group.
- Later: one-time purchase or yearly subscription for export/reporting.

Recommended first App Store release: free, no paywall, focus on trust and workflow.

## Pre-Submission Engineering Tasks

- Replace any real sample data with demo data.
- Add final app icon.
- Add launch screen polish if needed.
- Add privacy policy link.
- Confirm minimum iOS version.
- Confirm app name spelling: current project uses `LandloardLedger`; app-facing name should be `Landlord Ledger`.
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

