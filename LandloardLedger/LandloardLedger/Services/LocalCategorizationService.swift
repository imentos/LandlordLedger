import Foundation

// MARK: - Shared categorization types

struct TransactionInput {
    let index: Int
    let date: String
    let description: String
    let amount: Decimal
    let type: String
}

struct CategorizationResult {
    let index: Int
    let property: String
    let tenant: String?
    let category: String
    let confidence: Double
}

struct PropertyMatchingSnapshot {
    let name: String
    let address: String
    let ownerName: String
    let keywords: [String]
    let mortgageAliases: [String]

    init(property: Property) {
        self.name = property.name
        self.address = property.address
        self.ownerName = property.ownerName
        self.keywords = property.keywords
        self.mortgageAliases = property.mortgageAliasList
    }
}

// MARK: - Local rules engine

struct LocalCategorizationService {

    static let confidenceThreshold = 0.7

    static let scheduleECategories: [String] = [
        "Advertising", "Auto and Travel", "Cleaning and Maintenance",
        "Commissions", "Insurance", "Legal and Professional Fees",
        "Management Fees", "Mortgage", "Other Interest",
        "Repairs", "Supplies", "Taxes", "Utilities",
        "Rent Income", "Other Expense", "Personal/Unknown"
    ]

    private struct Rule {
        let patterns: [String]
        let category: String
        let confidence: Double
        let requiresExpense: Bool
        let requiresIncome: Bool

        init(
            _ patterns: [String],
            category: String,
            confidence: Double,
            requiresExpense: Bool = false,
            requiresIncome: Bool = false
        ) {
            self.patterns = patterns
            self.category = category
            self.confidence = confidence
            self.requiresExpense = requiresExpense
            self.requiresIncome = requiresIncome
        }
    }

    private static let rules: [Rule] = [
        Rule(["rent payment", "zillow rent", "rentredi", "tenantcloud", "apartments.com", "avail"], category: "Rent Income", confidence: 0.92, requiresIncome: true),
        Rule(["state farm", "allstate", "farmers insurance", "liberty mutual", "progressive", "geico"], category: "Insurance", confidence: 0.95, requiresExpense: true),
        Rule(["pg&e", "pge", "pgande", "edison", "con edison", "water bill", "sewer", "garbage", "trash", "waste management", "xfinity", "comcast"], category: "Utilities", confidence: 0.9, requiresExpense: true),
        Rule(["property tax", "tax collector", "county treasurer", "assessor"], category: "Taxes", confidence: 0.93, requiresExpense: true),
        Rule(["mortgage", "rocket mortgage", "home loan", "loan interest"], category: "Mortgage", confidence: 0.75, requiresExpense: true),
        Rule(["plumbing", "plumber", "hvac", "heating", "air conditioning", "roofing", "roofer", "electrician", "electrical", "locksmith", "appliance repair"], category: "Repairs", confidence: 0.9, requiresExpense: true),
        Rule(["home depot", "lowe's", "lowes", "ace hardware", "harbor freight"], category: "Supplies", confidence: 0.62, requiresExpense: true),
        Rule(["cleaning", "maid", "janitorial", "pest control", "landscaping", "lawn", "tree service"], category: "Cleaning and Maintenance", confidence: 0.86, requiresExpense: true),
        Rule(["property management", "management fee", "manager fee"], category: "Management Fees", confidence: 0.9, requiresExpense: true),
        Rule(["legal", "attorney", "law office", "bookkeeping", "accountant", "cpa"], category: "Legal and Professional Fees", confidence: 0.86, requiresExpense: true),
        Rule(["advertising", "facebook ads", "google ads", "craigslist", "zillow listing"], category: "Advertising", confidence: 0.85, requiresExpense: true),
        Rule(["mileage", "parking", "toll", "uber", "lyft"], category: "Auto and Travel", confidence: 0.82, requiresExpense: true),
        Rule(["commission"], category: "Commissions", confidence: 0.85, requiresExpense: true)
    ]

    @MainActor
    static func categorize(
        transactions: [TransactionInput],
        properties: [Property],
        tenants: [Tenant] = [],
        matchingRules: [MatchingRule] = []
    ) -> [CategorizationResult] {
        let propertySnapshots = properties.map(PropertyMatchingSnapshot.init)

        return transactions.map { input in
            let normalized = normalize(input.description)
            let normalizedType = normalize(input.type)

            if let learned = matchLearnedRule(text: normalized, rules: matchingRules) {
                return CategorizationResult(
                    index: input.index,
                    property: learned.property?.name ?? "Personal/Unknown",
                    tenant: learned.tenant?.name,
                    category: learned.category,
                    confidence: 0.96
                )
            }

            let categoryMatch = matchCategory(text: normalized, amount: input.amount)
            let tenantMatch = matchTenant(
                text: normalized,
                amount: input.amount,
                type: normalizedType,
                tenants: tenants
            )
            let mortgageMatch = matchMortgageProperty(text: normalized, amount: input.amount, properties: propertySnapshots)
            let propertyMatch = matchProperty(text: normalized, properties: propertySnapshots)
            let matchedPropertyName = tenantMatch?.tenant.property?.name
                ?? mortgageMatch?.property.name
                ?? propertyMatch?.property.name
            let category = mortgageMatch == nil ? categoryMatch.category : "Mortgage"
            let confidence: Double

            if let tenantMatch {
                confidence = min(max(categoryMatch.confidence, 0.9), tenantMatch.confidence)
            } else if let mortgageMatch {
                confidence = mortgageMatch.confidence
            } else {
                confidence = min(categoryMatch.confidence, propertyMatch?.confidence ?? categoryMatch.propertyPenalty)
            }

            return CategorizationResult(
                index: input.index,
                property: matchedPropertyName ?? "Personal/Unknown",
                tenant: tenantMatch?.tenant.name,
                category: category,
                confidence: confidence
            )
        }
    }

    private static func matchCategory(text: String, amount: Decimal) -> (category: String, confidence: Double, propertyPenalty: Double) {
        for rule in rules {
            if rule.requiresExpense && amount >= 0 { continue }
            if rule.requiresIncome && amount <= 0 { continue }
            if rule.patterns.contains(where: { text.contains($0) }) {
                return (rule.category, rule.confidence, amount > 0 ? 0.8 : 0.65)
            }
        }

        if amount > 0 && text.contains("rent") {
            return ("Rent Income", 0.78, 0.7)
        }

        if amount > 0 && isIncomingRentPayment(text: text, type: "") {
            return ("Rent Income", 0.72, 0.55)
        }

        return ("Personal/Unknown", 0.25, 0.25)
    }

    private static func matchLearnedRule(text: String, rules: [MatchingRule]) -> MatchingRule? {
        rules
            .filter { !$0.normalizedPattern.isEmpty && text.contains($0.normalizedPattern) }
            .sorted { $0.normalizedPattern.count > $1.normalizedPattern.count }
            .first
    }

    private static func matchTenant(
        text: String,
        amount: Decimal,
        type: String,
        tenants: [Tenant]
    ) -> (tenant: Tenant, confidence: Double)? {
        guard amount > 0, isIncomingRentPayment(text: text, type: type) else { return nil }

        for tenant in tenants {
            let candidates = ([tenant.name] + tenant.aliases)
                .map(normalize)
                .filter { !$0.isEmpty }

            if candidates.contains(where: { text.contains($0) }) {
                let rentConfidence = amountMatchesExpectedRent(amount, tenant.expectedMonthlyRent) ? 0.97 : 0.9
                return (tenant, rentConfidence)
            }
        }

        let amountMatches = tenants.filter { amountMatchesExpectedRent(amount, $0.expectedMonthlyRent) }
        if amountMatches.count == 1, let tenant = amountMatches.first {
            return (tenant, 0.76)
        }

        return nil
    }

    static func learnedPattern(from description: String) -> String {
        let normalized = normalize(description)
        if let zelleCounterparty = extractZelleCounterparty(from: normalized) {
            return zelleCounterparty
        }

        if let onlinePaymentPayee = extractOnlinePaymentPayee(from: normalized) {
            return onlinePaymentPayee
        }

        if let achCompany = extractACHCompanyName(from: normalized) {
            return achCompany
        }

        if let achName = extractACHIndividualName(from: normalized) {
            return achName
        }

        return normalized
    }

    static func isIncomingRentPayment(text: String, type: String) -> Bool {
        let normalizedText = normalize(text)
        let normalizedType = normalize(type)
        return normalizedText.contains("zelle payment from")
            || normalizedText.contains("quickpay")
            || normalizedText.contains("rent pay")
            || normalizedType.contains("quickpay credit")
            || normalizedType.contains("partnerfi to chase")
            || normalizedType.contains("ach credit")
    }

    private static func matchMortgageProperty(text: String, amount: Decimal, properties: [PropertyMatchingSnapshot]) -> (property: PropertyMatchingSnapshot, confidence: Double)? {
        guard amount < 0 else { return nil }

        for property in properties {
            let aliases = property.mortgageAliases
                .map(normalize)
                .filter { $0.count >= 3 }

            if aliases.contains(where: { text.contains($0) || $0.contains(text) }) {
                return (property, 0.94)
            }
        }

        return nil
    }

    private static func matchProperty(text: String, properties: [PropertyMatchingSnapshot]) -> (property: PropertyMatchingSnapshot, confidence: Double)? {
        guard properties.count > 1 else {
            return properties.first.map { ($0, 0.82) }
        }

        for property in properties {
            let candidates = ([property.name, property.address, property.ownerName] + property.keywords)
                .map(normalize)
                .filter { !$0.isEmpty }

            if candidates.contains(where: { text.contains($0) }) {
                return (property, 0.9)
            }
        }

        return nil
    }

    private static func amountMatchesExpectedRent(_ amount: Decimal, _ expected: Decimal) -> Bool {
        guard expected > 0 else { return false }
        let diff = abs(NSDecimalNumber(decimal: amount - expected).doubleValue)
        return diff <= 2.0
    }

    private static func extractZelleCounterparty(from text: String) -> String? {
        let marker: String
        if text.contains("zelle payment from") {
            marker = "zelle payment from"
        } else if text.contains("zelle payment to") {
            marker = "zelle payment to"
        } else {
            return nil
        }

        let remainder = text.replacingOccurrences(of: marker, with: "")
        return stripTrailingTransferCode(from: remainder)
    }

    private static func extractOnlinePaymentPayee(from text: String) -> String? {
        guard text.contains("online payment"), let range = text.range(of: " to ") else { return nil }
        let payee = String(text[range.upperBound...])
            .replacingOccurrences(of: #" transaction.*$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #" \d{1,2} \d{1,2}$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return payee.isEmpty ? nil : payee
    }

    private static func extractACHCompanyName(from text: String) -> String? {
        guard let range = text.range(of: "orig co name") else { return nil }
        let remainder = String(text[range.upperBound...])
        let company = remainder
            .replacingOccurrences(of: #"^ +"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #" orig id.*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return company.isEmpty ? nil : company
    }

    private static func extractACHIndividualName(from text: String) -> String? {
        guard let range = text.range(of: "ind name") else { return nil }
        let remainder = String(text[range.upperBound...])
        let name = remainder
            .replacingOccurrences(of: #"trn.*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    private static func stripTrailingTransferCode(from value: String) -> String? {
        let stripped = value
            .replacingOccurrences(of: #"\b(jpm|bac|wfct|2dz|[0-9])[a-z0-9]*\b$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? nil : stripped
    }

    nonisolated static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9&'. ]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
