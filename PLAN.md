# LandlordLedger — Design & Implementation Plan

A Stessa-like iOS app for landlords to track rental property income and expenses, auto-categorize bank transactions using local rules, and generate IRS Schedule E tax reports.

---

## Problem

Landlords managing multiple rental properties spend hours at tax time manually sorting bank statements into Schedule E categories (repairs, utilities, insurance, etc.). Stessa solves this but is web-only and not optimized for mobile-first users. LandlordLedger brings this workflow to iOS with private on-device categorization.

---

## Core Workflow

```
Import bank CSV or paste CSV text → local rules categorize → match rent to tenants/properties → Review low-confidence items → Export Schedule E PDF
```

1. **Import** — User taps Import, picks a CSV from their bank/Mint/other source, or pastes copied CSV text
2. **Categorize** — Local merchant/service-word rules assign each transaction to a Schedule E category with a confidence score
3. **Rent matching** — Zelle/QuickPay/ACH rent credits are matched to tenants, leases, and properties when sender names or expected rent amounts line up
4. **Auto-approve** — Transactions with ≥70% confidence are approved automatically
5. **Inbox review** — Transactions below 70% confidence, or ambiguous tenant/property matches, land in the Inbox for manual review
6. **Learn corrections** — When the landlord fixes a tenant, property, or category, the app remembers the mapping for future imports
7. **Export** — User selects a tax year and generates a multi-property Schedule E PDF

---

## Architecture

- **SwiftUI + SwiftData** — declarative UI, automatic persistence
- **LocalCategorizationService** — on-device transaction categorization with confidence scores
- **No API key / no network required** — transaction data stays on device
- **UIGraphicsPDFRenderer** — native PDF generation
- **UIActivityViewController** — iOS share sheet for PDF export

---

## Data Models

### Property
- `name` (required)
- `address` (optional, shown in UI)
- `keywords` (comma-separated, helps local rules match transactions to properties)
- Relationship: one-to-many with Transaction (cascade delete)
- Computed: `totalIncome`, `totalExpenses`, `netIncome` from approved transactions

### Tenant (planned)
- `name` (required)
- `aliases` (comma-separated sender names from Zelle/ACH descriptions, e.g. "DIANA MENDOZA MEDINA")
- `expectedMonthlyRent`
- `unit` (optional)
- `propertyID` — current property/unit this tenant belongs to
- Relationship: one-to-many with RentPayment / Transaction matches

### Transaction
- `dateTime`, `description`, `amount`
- `category` — one of 16 Schedule E categories (see below)
- `propertyID` — matched to a Property
- `tenantID` — optional, matched for rent income payments
- `confidence` — float 0.0–1.0 from local rules
- `isApproved` — bool, auto-set when confidence ≥ 0.7
- `source` — `"rules_auto"`, `"user_confirmed"`, `"user_corrected"` (audit trail)

### MatchingRule (planned)
- `normalizedPattern` — reusable sender/merchant/property text learned from a correction
- `category`
- `propertyID`
- `tenantID` (optional)
- `source` — `"user_correction"` or `"system_suggestion"`
- Used so corrections work like LandMiles property fixes: link once, remember next time

### Schedule E Categories (16)
Rent Income, Advertising, Auto & Travel, Cleaning & Maintenance, Commissions, Insurance, Legal & Professional, Management Fees, Mortgage Interest, Other Interest, Repairs, Supplies, Taxes, Utilities, Depreciation, Other

---

## Navigation — 4-Tab Structure

| Tab | Icon | Purpose |
|-----|------|---------|
| Import | `square.and.arrow.down` | CSV file selection and local categorization |
| Inbox | `tray` | Manual review of low-confidence transactions |
| Properties | `building.2` | Add/edit/delete rental properties |
| Export | `doc.text` | Generate Schedule E PDF by year |

---

## Screen Designs

### Import Tab (`ImportView`)
- Import mode selector: Choose CSV File or Paste CSV Text
- File picker button opens document browser for CSV selection
- Paste CSV Text sheet includes large text editor, Paste from Clipboard button, parse preview, and Import button
- Import blocked (button disabled) if no properties exist
- Progress states: idle → parsing → categorizing (shows progress) → saving → done
- Summary on completion: X auto-approved, Y sent to inbox
- `ImportViewModel` (@Observable) manages state machine via `ImportState` enum
- File import and paste import both call the same `CSVParser.parse(csvText:)` path

**ImportState enum** (no Equatable — associated values prevent it):
`idle | parsing | categorizing(progress: Double) | saving | done(ImportSummary) | error(String)`

### Inbox Tab (`InboxView`)
- Lists transactions with `isApproved = false`
- Each row is an `InboxCardView` (expandable card)
- Empty state: "All caught up!" when no pending items

**InboxCardView**:
- Header: confidence badge (orange ≥50%, red <50%), description, date, amount (green = income)
- Expanded: rules suggestion with sparkles icon, horizontal property chips, optional tenant picker, category dropdown
- For likely rent income, show suggested tenant/property match from Zelle/QuickPay/ACH sender text and expected rent amount
- Confirm disabled until property and category are selected; tenant is required for rent-ledger entries when the landlord wants tenant tracking
- Sets `source = "user_confirmed"` if category/property/tenant match the suggestion, `"user_corrected"` if changed
- Saves user corrections as reusable matching rules so future imports auto-map the same sender to the same tenant/property
- 0.6s animated auto-collapse after confirm
- Card border thickens and turns accent color when expanded

### Properties Tab (`PropertiesView`)
- Alphabetically sorted list via `@Query`
- Row shows: name, address, Income chip (green), Expenses chip (red), Net chip (conditional color)
- Swipe-to-delete cascades to all associated transactions
- `PropertyFormView` sheet: name (required), address (optional), keywords field
- Keywords footer: "help match this property to your transactions"
- `NavigationLink` → `PropertyDetailView`

**PropertyDetailView**:
- Three-card financial summary at top (Income / Expenses / Net)
- Transactions grouped by month ("Jan 2025"), sorted newest first
- Only approved transactions shown
- Edit button in toolbar reopens `PropertyFormView`

### Export Tab (`ExportView`)
- Year picker: current year down to current-4
- Preview card: each property with count of approved transactions for selected year
- Generate button disabled when no properties or generation in progress
- PDF generated on background queue (`.userInitiated` QoS)
- Share sheet auto-presents when generation completes
- Output filename: `LandlordLedger_[year].pdf`

### Settings (`SettingsView`)
- Shows categorization engine: Local Rules
- Shows confidence threshold (70%)
- Shows network requirement: No
- Footer: "Transactions are categorized on device using built-in merchant and service-word rules. Uncertain matches go to Inbox for review."

---

## PDF Output Format

- **Paper size**: US Letter (612×792pt), 48pt margins
- **Cover page**: Portfolio summary table — Property | Income | Expenses | Net — with grand totals row (bold)
- **Per-property pages**: INCOME section (Rent Income) + EXPENSES section (Schedule E categories), net income row colored green/red
- **Auto page breaks** when y > pageHeight - 80
- **Footer** on every page: "Generated by LandlordLedger on [timestamp]"

---

## Local Categorization (`LocalCategorizationService`)

Rules use:
- Transaction description, amount, date
- Built-in merchant keywords (State Farm, PG&E, Home Depot, etc.)
- Service-word patterns (plumbing, roofing, HVAC, landscaping, tax collector, etc.)
- Property names, addresses, and user-provided property keywords
- Zelle/QuickPay/ACH sender names for rent-income detection
- Tenant aliases and expected monthly rent amounts for tenant/property matching
- User-corrected matching rules from prior imports

Result schema:
```json
{
  "category": "Repairs",
  "property_id": "uuid-string",
  "tenant_id": null,
  "confidence": 0.85,
  "reasoning": "Plumber keyword matched repairs pattern"
}
```

Confidence threshold: **0.70** — above auto-approves, below goes to Inbox.

### Zelle / Rent Matching (planned)
- Detect incoming rent candidates from positive transactions with descriptions/types such as `Zelle payment from`, `QUICKPAY_CREDIT`, `PARTNERFI_TO_CHASE`, and ACH rent-payment text.
- Extract sender/payor names from descriptions when possible.
- Match to a tenant by normalized sender alias first, then by amount near `expectedMonthlyRent`, then by property keywords.
- Automatically map matched rent to both `tenantID` and `propertyID` so tax exports and rent ledgers stay aligned.
- Send ambiguous matches to Inbox with a clear suggested action: "Link this Zelle payment to [tenant] at [property]?"
- When the landlord fixes a match, save it as a reusable rule for future imports.

---

## App Entry Point

`LandloardLedgerApp.swift`:
```swift
.modelContainer(for: [Property.self, Transaction.self])
```
Cascade delete: deleting a Property auto-deletes all its Transactions.

---

## Known Issues / Fixes Applied

- `ImportState` enum **must not** conform to `Equatable` — associated values (String, ImportSummary) caused compiler error when Equatable was explicitly declared. SwiftUI @Observable doesn't require it.

---

## Status (as of Apr 15, 2026)

All core screens implemented and compiling. App entry point configured with SwiftData. Basic end-to-end flow functional: import CSV → local rules categorize → inbox review → PDF export.

**Not yet done:**
- App Store submission materials (screenshots, description, privacy policy)
- Paywall / monetization (subscription or one-time purchase)
- Onboarding flow for first-time users
- Error handling polish (network failures, malformed CSVs)
- App icon
- TestFlight build
