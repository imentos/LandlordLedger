import Foundation
import SwiftData

@Model
final class Property {

    var name: String        // "Oak Street"
    var address: String     // "123 Oak St"
    var ownerName: String = "" // owner, client, or portfolio name
    var keywords: [String]  // ["oak st", "acme plumbing"] — used for v2 accuracy improvement

    // MARK: - Relationships

    @Relationship(deleteRule: .cascade, inverse: \Transaction.property)
    var transactions: [Transaction] = []

    @Relationship(deleteRule: .cascade, inverse: \Tenant.property)
    var tenants: [Tenant] = []

    // MARK: - Init

    init(name: String, address: String, ownerName: String = "", keywords: [String] = []) {
        self.name      = name
        self.address   = address
        self.ownerName = ownerName
        self.keywords  = keywords
    }

    // MARK: - Computed helpers

    /// All approved transactions for this property, sorted newest first.
    var approvedTransactions: [Transaction] {
        transactions
            .filter { $0.approved }
            .sorted { $0.date > $1.date }
    }

    var totalIncome: Decimal {
        approvedTransactions
            .filter { $0.category == "Rent Income" }
            .reduce(0) { $0 + $1.amount }
    }

    var totalExpenses: Decimal {
        approvedTransactions
            .filter { $0.category != "Rent Income" }
            .reduce(0) { $0 + abs($1.amount) }
    }

    var netIncome: Decimal { totalIncome - totalExpenses }
}

@Model
final class Tenant {

    var name: String
    var unit: String
    var aliases: [String]
    var expectedMonthlyRent: Decimal

    var property: Property?

    @Relationship(deleteRule: .nullify, inverse: \Transaction.tenant)
    var transactions: [Transaction] = []

    init(
        name: String,
        unit: String = "",
        aliases: [String] = [],
        expectedMonthlyRent: Decimal = 0,
        property: Property? = nil
    ) {
        self.name = name
        self.unit = unit
        self.aliases = aliases
        self.expectedMonthlyRent = expectedMonthlyRent
        self.property = property
    }
}

@Model
final class MatchingRule {

    var normalizedPattern: String
    var category: String
    var source: String
    var createdAt: Date

    var property: Property?
    var tenant: Tenant?

    init(
        normalizedPattern: String,
        category: String,
        property: Property? = nil,
        tenant: Tenant? = nil,
        source: String = "user_correction"
    ) {
        self.normalizedPattern = normalizedPattern
        self.category = category
        self.property = property
        self.tenant = tenant
        self.source = source
        self.createdAt = Date()
    }
}
