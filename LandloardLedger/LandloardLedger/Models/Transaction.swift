import Foundation
import SwiftData

@Model
final class Transaction {

    // MARK: - Core fields (from CSV)

    var date:        Date
    var descriptionText: String   // named descriptionText to avoid conflict with NSObject.description
    var amount:      Decimal      // positive = income, negative = expense (Chase checking convention)
                                  // Credit card imports: amounts are normalised to this convention on parse

    // MARK: - Categorization fields

    var category:   String        // Schedule E category
    var confidence: Double        // 0.0 – 1.0 from local rules

    // MARK: - Approval fields

    var approved:   Bool          // true = auto-approved (confidence ≥ 0.7) or user-confirmed
    var source:     String        // "rules_auto" | "user_confirmed" | "user_corrected"

    // MARK: - Deduplication fingerprint

    /// Computed from date + description + amount at import time.
    /// Safe to re-import an overlapping date range — duplicates are silently skipped.
    var fingerprint: String

    // MARK: - Relationship

    var property: Property?
    var tenant: Tenant?

    // MARK: - Metadata

    var importedAt: Date

    // MARK: - Init

    init(
        date:            Date,
        descriptionText: String,
        amount:          Decimal,
        category:        String  = "",
        confidence:      Double  = 0,
        approved:        Bool    = false,
        source:          String  = "pending",
        property:        Property? = nil,
        tenant:          Tenant? = nil
    ) {
        self.date            = date
        self.descriptionText = descriptionText
        self.amount          = amount
        self.category        = category
        self.confidence      = confidence
        self.approved        = approved
        self.source          = source
        self.property        = property
        self.tenant          = tenant
        self.importedAt      = Date()

        // Fingerprint: normalise amount to 2 dp to avoid floating-point variance
        let amountStr = NSDecimalNumber(decimal: amount)
            .rounding(accordingToBehavior: NSDecimalNumberHandler(
                roundingMode: .plain,
                scale: 2,
                raiseOnExactness: false,
                raiseOnOverflow: false,
                raiseOnUnderflow: false,
                raiseOnDivideByZero: false
            ))
            .stringValue

        let dateStr = ISO8601DateFormatter().string(from: date)
        self.fingerprint = "\(dateStr)|\(descriptionText)|\(amountStr)"
    }

    // MARK: - Helpers

    var isIncome: Bool { category == "Rent Income" }
}
