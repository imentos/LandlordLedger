import Foundation
import SwiftData

// MARK: - Summary returned after a successful import

struct ImportSummary {
    let totalParsed:    Int
    let duplicatesSkipped: Int
    let autoApproved:   Int
    let needsReview:    Int
}

struct MatchingRefreshSummary {
    let totalChecked: Int
    let updated: Int
    let autoApproved: Int
    let needsReview: Int
}

// MARK: - View-visible state

enum ImportState {
    case idle
    case parsing
    case categorizing(progress: String)
    case saving
    case done(ImportSummary)
    case error(String)
}

// MARK: - View model

@MainActor
@Observable
final class ImportViewModel {

    var state: ImportState = .idle

    // MARK: - Public entry point

    /// Full pipeline: parse CSV → deduplicate → categorize locally → save atomically.
    /// On any error the modelContext is not modified.
    func importCSV(
        url: URL,
        properties: [Property],
        tenants: [Tenant],
        matchingRules: [MatchingRule],
        modelContext: ModelContext
    ) async {
        state = .parsing

        do {
            // 1. Read file
            guard url.startAccessingSecurityScopedResource() else {
                state = .error("Could not access the selected file.")
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let csvText = try String(contentsOf: url, encoding: .utf8)
            try await importCSVText(
                csvText,
                properties: properties,
                tenants: tenants,
                matchingRules: matchingRules,
                modelContext: modelContext
            )

        } catch let parseError as CSVParseError {
            state = .error(parseError.localizedDescription)
        } catch {
            state = .error("Unexpected error: \(error.localizedDescription)")
        }
    }

    func importCSVText(
        _ csvText: String,
        properties: [Property],
        tenants: [Tenant],
        matchingRules: [MatchingRule],
        modelContext: ModelContext
    ) async throws {
        state = .parsing

        do {
            // 1. Parse CSV
            let parsed = try CSVParser.parse(csvText: csvText)

            // 2. Deduplicate against existing transactions in SwiftData
            let existingFingerprints: Set<String> = {
            let all = (try? modelContext.fetch(FetchDescriptor<Transaction>())) ?? []
            return Set(all.map(\.fingerprint))
        }()

        let newRows = parsed.filter { row in
            let fp = makeFingerprint(date: row.date,
                                     description: row.description,
                                     amount: row.amount)
            return !existingFingerprints.contains(fp)
        }

        let duplicatesSkipped = parsed.count - newRows.count

        guard !newRows.isEmpty else {
            state = .done(ImportSummary(
                totalParsed:      parsed.count,
                duplicatesSkipped: duplicatesSkipped,
                autoApproved:     0,
                needsReview:      0
            ))
            return
        }

        // 3. Build TransactionInput for local categorization (re-index from 0)
        let inputs: [TransactionInput] = newRows.enumerated().map { idx, row in
            TransactionInput(
                index:       idx,
                date:        Self.csvDateString(from: row.date),
                description: row.description,
                amount:      row.amount,
                type:        row.type
            )
        }

        // 4. Categorize locally using built-in merchant/service rules.
        state = .categorizing(progress: "Categorizing \(inputs.count) transactions locally…")
        let results = LocalCategorizationService.categorize(
            transactions: inputs,
            properties: properties,
            tenants: tenants,
            matchingRules: matchingRules
        )

        // 6. Create Transaction objects — not yet inserted
        state = .saving
        var autoApproved = 0
        var needsReview  = 0

        var newTransactions: [Transaction] = []
        for (result, row) in zip(results.sorted(by: { $0.index < $1.index }), newRows) {
            let approved = result.confidence >= LocalCategorizationService.confidenceThreshold
            let source   = approved ? "rules_auto" : "pending_review"

            let tx = Transaction(
                date:            row.date,
                descriptionText: row.description,
                amount:          row.amount,
                category:        result.category,
                confidence:      result.confidence,
                approved:        approved,
                source:          source,
                property:        firstProperty(named: result.property, in: properties),
                tenant:          result.tenant.flatMap { firstTenant(named: $0, in: tenants) }
            )
            newTransactions.append(tx)

            if approved { autoApproved += 1 } else { needsReview += 1 }
        }

        // 7. Atomic insert: insert all or none
        for tx in newTransactions {
            modelContext.insert(tx)
        }
        try modelContext.save()

        state = .done(ImportSummary(
            totalParsed:       parsed.count,
            duplicatesSkipped: duplicatesSkipped,
            autoApproved:      autoApproved,
            needsReview:       needsReview
        ))
        } catch let parseError as CSVParseError {
            state = .error(parseError.localizedDescription)
        } catch {
            state = .error("Unexpected error: \(error.localizedDescription)")
        }
    }

    func rerunMatching(
        properties: [Property],
        tenants: [Tenant],
        matchingRules: [MatchingRule],
        modelContext: ModelContext
    ) async throws -> MatchingRefreshSummary {
        let allTransactions = try modelContext.fetch(FetchDescriptor<Transaction>())
        let refreshableTransactions = allTransactions.filter {
            $0.source != "user_confirmed" && $0.source != "user_corrected"
                && $0.source != "needs_manual_review"
        }

        guard !refreshableTransactions.isEmpty else {
            return MatchingRefreshSummary(totalChecked: 0, updated: 0, autoApproved: 0, needsReview: 0)
        }

        let inputs = refreshableTransactions.enumerated().map { index, tx in
            TransactionInput(
                index: index,
                date: Self.csvDateString(from: tx.date),
                description: tx.descriptionText,
                amount: tx.amount,
                type: ""
            )
        }

        let results = LocalCategorizationService.categorize(
            transactions: inputs,
            properties: properties,
            tenants: tenants,
            matchingRules: matchingRules
        )
        var updated = 0
        var autoApproved = 0
        var needsReview = 0

        for (result, tx) in zip(results.sorted(by: { $0.index < $1.index }), refreshableTransactions) {
            let newProperty = firstProperty(named: result.property, in: properties)
            let newTenant = result.tenant.flatMap { firstTenant(named: $0, in: tenants) }
            let newApproved = result.confidence >= LocalCategorizationService.confidenceThreshold
            let newSource = newApproved ? "rules_auto" : "pending_review"

            if tx.category != result.category
                || tx.confidence != result.confidence
                || tx.approved != newApproved
                || tx.source != newSource
                || tx.property?.persistentModelID != newProperty?.persistentModelID
                || tx.tenant?.persistentModelID != newTenant?.persistentModelID {
                updated += 1
            }

            tx.category = result.category
            tx.confidence = result.confidence
            tx.approved = newApproved
            tx.source = newSource
            tx.property = newProperty
            tx.tenant = newTenant

            if newApproved {
                autoApproved += 1
            } else {
                needsReview += 1
            }
        }

        try modelContext.save()

        return MatchingRefreshSummary(
            totalChecked: refreshableTransactions.count,
            updated: updated,
            autoApproved: autoApproved,
            needsReview: needsReview
        )
    }

    // MARK: - Helpers

    private func makeFingerprint(date: Date, description: String, amount: Decimal) -> String {
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
        return "\(dateStr)|\(description)|\(amountStr)"
    }

    private static func csvDateString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd/yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    private func firstProperty(named name: String, in properties: [Property]) -> Property? {
        properties.first {
            $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    private func firstTenant(named name: String, in tenants: [Tenant]) -> Tenant? {
        tenants.first {
            $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }
}
