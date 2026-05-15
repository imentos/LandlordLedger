import Foundation
import SwiftData

@main
struct ImportLogicTests {
    static func main() async throws {
        let csvPath = CommandLine.arguments.dropFirst().first
            ?? "/Users/I818292/Downloads/Chase9817_Activity_20260513.CSV"
        let csvText = try String(contentsOfFile: csvPath, encoding: .utf8)

        let parsed = try CSVParser.parse(csvText: csvText)
        try expect(parsed.count == 45, "Expected 45 parsed Chase rows, got \(parsed.count)")
        try expect(dateString(from: parsed.first?.date ?? Date()) == "04/13/2026", "Expected oldest parsed row to be 04/13/2026")
        try expect(parsed.contains { $0.type == "CHASE_TO_PARTNERFI" }, "Expected Type column to include CHASE_TO_PARTNERFI values")

        let schema = Schema([
            Property.self,
            Tenant.self,
            Transaction.self,
            MatchingRule.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let propertyA = Property(name: "Sample Property A", address: "100 A St")
        let propertyB = Property(name: "Sample Property B", address: "200 B St")
        let propertyC = Property(name: "Sample Property C", address: "300 C St")
        let propertyD = Property(name: "Sample Property D", address: "400 D St")
        let propertyE = Property(name: "Sample Property E", address: "500 E St")
        let propertyF = Property(name: "Sample Property F", address: "600 F St")
        let properties = [propertyA, propertyB, propertyC, propertyD, propertyE, propertyF]
        properties.forEach(context.insert)

        let tenants = [
            Tenant(name: "Yeisi Aguilar", aliases: ["YEISI MARILU AGUILAR HENRIQUEZ"], expectedMonthlyRent: 2870, property: propertyA),
            Tenant(name: "Jose Alfaro", aliases: ["JOSE ALFARO"], expectedMonthlyRent: 2900, property: propertyB),
            Tenant(name: "Lovella Salvador", aliases: ["LOVELLA SALVADOR"], expectedMonthlyRent: 2680, property: propertyC),
            Tenant(name: "Duglas Giron", aliases: ["DUGLAS GIRON"], expectedMonthlyRent: 2870, property: propertyA),
            Tenant(name: "Carlos Carranza", aliases: ["CARLOS CARRANZA"], expectedMonthlyRent: 2600, property: propertyD),
            Tenant(name: "Felipe Soria", aliases: ["FELIPE SORIA"], expectedMonthlyRent: 2850, property: propertyE),
            Tenant(name: "Mayra Torres", aliases: ["MAYRA TORRES HERNANDEZ", "MAYRA TORRES-HERNANDEZ"], expectedMonthlyRent: 5000.50, property: propertyF)
        ]
        tenants.forEach(context.insert)
        try context.save()

        let inputs = parsed.enumerated().map { index, row in
            TransactionInput(
                index: index,
                date: dateString(from: row.date),
                description: row.description,
                amount: row.amount,
                type: row.type
            )
        }
        let results = LocalCategorizationService.categorize(
            transactions: inputs,
            properties: properties,
            tenants: tenants,
            matchingRules: []
        )

        let incomingElectronicCredits = parsed.filter { row in
            row.amount > 0
                && LocalCategorizationService.isIncomingRentPayment(text: row.description, type: row.type)
        }
        try expect(incomingElectronicCredits.count == 20, "Expected 20 incoming electronic credits, got \(incomingElectronicCredits.count)")

        let rentIncomeResults = zip(parsed, results).filter { row, result in
            row.amount > 0 && result.category == "Rent Income"
        }
        try expect(rentIncomeResults.count == 18, "Expected 18 imported rent income rows, got \(rentIncomeResults.count)")

        let outgoingZelleRentMatches = zip(parsed, results).filter { row, result in
            row.amount < 0
                && LocalCategorizationService.normalize(row.description).contains("zelle payment to")
                && result.category == "Rent Income"
        }
        try expect(outgoingZelleRentMatches.isEmpty, "Outgoing Zelle payments should not be categorized as rent")

        let pgandeUtilities = zip(parsed, results).filter { row, result in
            LocalCategorizationService.normalize(row.description).contains("pgande")
                && result.category == "Utilities"
        }
        try expect(pgandeUtilities.count == 4, "Expected 4 PGANDE utility rows, got \(pgandeUtilities.count)")

        let hsbcMortgage = try expectValue(
            parsed.first { $0.description.contains("HSBC MORTGAGE") },
            "Expected sample CSV to include an HSBC mortgage payment"
        )
        let hsbcPattern = LocalCategorizationService.learnedPattern(from: hsbcMortgage.description)
        try expect(hsbcPattern == "hsbc mortgage", "Expected HSBC learned pattern to be stable, got \(hsbcPattern)")

        let hsbcRule = MatchingRule(
            normalizedPattern: hsbcPattern,
            category: "Mortgage Interest",
            property: propertyB
        )
        let hsbcRuleResult = try expectValue(
            LocalCategorizationService.categorize(
                transactions: [
                    TransactionInput(
                        index: 0,
                        date: dateString(from: hsbcMortgage.date),
                        description: hsbcMortgage.description,
                        amount: hsbcMortgage.amount,
                        type: hsbcMortgage.type
                    )
                ],
                properties: properties,
                tenants: tenants,
                matchingRules: [hsbcRule]
            ).first,
            "Expected HSBC learned rule categorization result"
        )
        try expect(hsbcRuleResult.category == "Mortgage Interest", "Expected HSBC rule to remember Mortgage Interest")
        try expect(hsbcRuleResult.property == propertyB.name, "Expected HSBC rule to remember assigned property")

        let matchedTenants = results.filter { $0.tenant != nil }
        try expect(matchedTenants.count >= 7, "Expected at least 7 seeded tenant matches, got \(matchedTenants.count)")

        try await runImportPipeline(
            csvText: csvText,
            properties: properties,
            tenants: tenants,
            context: context
        )

        print("Import logic tests passed for \(csvPath)")
    }

    private static func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }

    private static func expectValue<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else { throw TestFailure(message) }
        return value
    }

    @MainActor
    private static func runImportPipeline(
        csvText: String,
        properties: [Property],
        tenants: [Tenant],
        context: ModelContext
    ) async throws {
        let importer = ImportViewModel()
        try await importer.importCSVText(
            csvText,
            properties: properties,
            tenants: tenants,
            matchingRules: [],
            modelContext: context
        )

        guard case let .done(summary) = importer.state else {
            throw TestFailure("Expected first import to finish successfully")
        }

        try expect(summary.totalParsed == 45, "Expected first import totalParsed 45, got \(summary.totalParsed)")
        try expect(summary.duplicatesSkipped == 0, "Expected no duplicates on first import")

        let imported = try context.fetch(FetchDescriptor<Transaction>())
        try expect(imported.count == 45, "Expected 45 inserted transactions, got \(imported.count)")

        let yeisi = imported.first {
            $0.descriptionText.contains("YEISI MARILU AGUILAR HENRIQUEZ")
        }
        try expect(yeisi?.category == "Rent Income", "Expected Yeisi payment to be Rent Income")
        try expect(yeisi?.tenant?.name == "Yeisi Aguilar", "Expected Yeisi payment tenant match")
        try expect(yeisi?.property?.name == "Sample Property A", "Expected Yeisi payment property match")

        try await importer.importCSVText(
            csvText,
            properties: properties,
            tenants: tenants,
            matchingRules: [],
            modelContext: context
        )

        guard case let .done(secondSummary) = importer.state else {
            throw TestFailure("Expected second import to finish successfully")
        }
        try expect(secondSummary.duplicatesSkipped == 45, "Expected second import to skip all 45 duplicates")

        let afterDuplicateImport = try context.fetch(FetchDescriptor<Transaction>())
        try expect(afterDuplicateImport.count == 45, "Expected duplicate import to keep 45 transactions")
    }
}

struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
