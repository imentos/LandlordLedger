import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showImportedResetConfirmation = false
    @State private var showFullResetConfirmation = false
    @State private var resetStatus: String?

    var body: some View {
        Form {
            Section {
                LabeledContent("Engine", value: "Local Rules")
                LabeledContent("Confidence Threshold", value: "70%")
                LabeledContent("Network Required", value: "No")
            } header: {
                Text("Categorization")
            } footer: {
                Text("Transactions are categorized on device using built-in merchant and service-word rules. Uncertain matches go to Inbox for review.")
                    .font(.caption)
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Privacy", value: "No transaction data leaves device")
            }

            #if DEBUG
            Section {
                Button {
                    generateScreenshotData()
                } label: {
                    Label("Generate Screenshot Data", systemImage: "sparkles")
                }

                Button(role: .destructive) {
                    showImportedResetConfirmation = true
                } label: {
                    Label("Reset Imported Data", systemImage: "trash")
                }

                Button(role: .destructive) {
                    showFullResetConfirmation = true
                } label: {
                    Label("Reset All Test Data", systemImage: "trash.slash")
                }

                if let resetStatus {
                    Text(resetStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Debug")
            } footer: {
                Text("Generate screenshot data creates a clean demo account. Use reset actions to rerun CSV tests or clear local setup.")
                    .font(.caption)
            }
            #endif
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Reset imported data?",
            isPresented: $showImportedResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Imported Data", role: .destructive) {
                resetImportedData()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This deletes imported transactions only. Your properties and tenants will be kept.")
        }
        .confirmationDialog(
            "Reset all test data?",
            isPresented: $showFullResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset All Test Data", role: .destructive) {
                resetAllTestData()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This deletes properties, tenants, imported transactions, and learned matching rules. Use only when you want a clean test setup.")
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private func resetImportedData() {
        do {
            try deleteAll(Transaction.self)
            try modelContext.save()
            resetStatus = "Imported transactions were reset."
        } catch {
            resetStatus = "Reset failed: \(error.localizedDescription)"
        }
    }

    private func resetAllTestData() {
        do {
            try deleteAll(Transaction.self)
            try deleteAll(MatchingRule.self)
            try deleteAll(Tenant.self)
            try deleteAll(Property.self)
            try modelContext.save()
            resetStatus = "All local test data was reset."
        } catch {
            resetStatus = "Reset failed: \(error.localizedDescription)"
        }
    }

    #if DEBUG
    private func generateScreenshotData() {
        do {
            try deleteAll(Transaction.self)
            try deleteAll(MatchingRule.self)
            try deleteAll(Tenant.self)
            try deleteAll(Property.self)

            let maple = Property(
                name: "Maple Ave Duplex",
                address: "128 Maple Ave",
                ownerName: "Ray Family Portfolio",
                keywords: ["maple", "duplex", "128 maple", "ray family", "ray portfolio"]
            )
            let pine = Property(
                name: "Pine Street Cottage",
                address: "44 Pine Street",
                ownerName: "Johnson Family Trust",
                keywords: ["pine", "cottage", "44 pine", "johnson", "johnson trust"]
            )
            let sunset = Property(
                name: "Sunset Fourplex",
                address: "810 Sunset Blvd",
                ownerName: "Wong Properties",
                keywords: ["sunset", "fourplex", "810 sunset", "wong", "wong properties"]
            )

            let sarah = Tenant(name: "Sarah Chen", unit: "Unit A", aliases: ["Sarah Chen"], expectedMonthlyRent: 2400, property: maple)
            let david = Tenant(name: "David Park", unit: "Main House", aliases: ["David Park"], expectedMonthlyRent: 1850, property: pine)
            let emily = Tenant(name: "Emily Rivera", unit: "Unit 2", aliases: ["Emily Rivera"], expectedMonthlyRent: 1650, property: sunset)
            let marcus = Tenant(name: "Marcus Lee", unit: "Unit 4", aliases: ["Marcus Lee"], expectedMonthlyRent: 1725, property: sunset)

            [maple, pine, sunset].forEach { modelContext.insert($0) }
            [sarah, david, emily, marcus].forEach { modelContext.insert($0) }

            let approvedRows: [(Int, Int, String, Decimal, String, Property, Tenant?)] = [
                (1, 3, "Zelle payment from Sarah Chen rent payment", 2400, "Rent Income", maple, sarah),
                (1, 4, "ACH credit David Park rent pay", 1850, "Rent Income", pine, david),
                (1, 5, "Zelle payment from Emily Rivera rent", 1650, "Rent Income", sunset, emily),
                (1, 6, "Zelle payment from Marcus Lee rent", 1725, "Rent Income", sunset, marcus),
                (1, 9, "PG&E utility bill Maple Ave", -186.42, "Utilities", maple, nil),
                (1, 15, "Home Depot supplies", -74.28, "Supplies", maple, nil),
                (1, 22, "State Farm insurance policy", -142.50, "Insurance", pine, nil),
                (2, 3, "Zelle payment from Sarah Chen rent payment", 2400, "Rent Income", maple, sarah),
                (2, 4, "ACH credit David Park rent pay", 1850, "Rent Income", pine, david),
                (2, 5, "Zelle payment from Emily Rivera rent", 1650, "Rent Income", sunset, emily),
                (2, 6, "Zelle payment from Marcus Lee rent", 1725, "Rent Income", sunset, marcus),
                (2, 11, "Plumbing repair invoice Maple Ave", -365, "Repairs", maple, nil),
                (2, 19, "County property tax collector", -1225, "Taxes", sunset, nil),
                (2, 24, "Waste Management garbage service", -96.10, "Utilities", pine, nil),
                (3, 3, "Zelle payment from Sarah Chen rent payment", 2400, "Rent Income", maple, sarah),
                (3, 4, "ACH credit David Park rent pay", 1850, "Rent Income", pine, david),
                (3, 5, "Zelle payment from Emily Rivera rent", 1650, "Rent Income", sunset, emily),
                (3, 6, "Zelle payment from Marcus Lee rent", 1725, "Rent Income", sunset, marcus),
                (3, 12, "Landscaping monthly service", -180, "Cleaning and Maintenance", sunset, nil),
                (3, 21, "Rocket Mortgage loan interest", -910.33, "Mortgage Interest", maple, nil),
                (4, 3, "Zelle payment from Sarah Chen rent payment", 2400, "Rent Income", maple, sarah),
                (4, 4, "ACH credit David Park rent pay", 1850, "Rent Income", pine, david),
                (4, 5, "Zelle payment from Emily Rivera rent", 1650, "Rent Income", sunset, emily),
                (4, 6, "Zelle payment from Marcus Lee rent", 1725, "Rent Income", sunset, marcus),
                (4, 12, "Roofing repair deposit", -640, "Repairs", pine, nil),
                (4, 25, "CPA bookkeeping rental property", -250, "Legal and Professional Fees", sunset, nil),
                (5, 3, "Zelle payment from Sarah Chen rent payment", 2400, "Rent Income", maple, sarah),
                (5, 4, "ACH credit David Park rent pay", 1850, "Rent Income", pine, david),
                (5, 5, "Zelle payment from Emily Rivera rent", 1650, "Rent Income", sunset, emily),
                (5, 6, "Zelle payment from Marcus Lee rent", 1725, "Rent Income", sunset, marcus),
                (5, 10, "Lowes supplies", -128.76, "Supplies", maple, nil),
                (5, 22, "Xfinity internet utility", -89.99, "Utilities", pine, nil),
                (6, 3, "Zelle payment from Sarah Chen rent payment", 2400, "Rent Income", maple, sarah),
                (6, 4, "ACH credit David Park rent pay", 1850, "Rent Income", pine, david),
                (6, 5, "Zelle payment from Emily Rivera rent", 1650, "Rent Income", sunset, emily),
                (6, 6, "Zelle payment from Marcus Lee rent", 1725, "Rent Income", sunset, marcus),
                (6, 8, "Locksmith repair", -155, "Repairs", sunset, nil),
                (6, 16, "Property management fee", -192, "Management Fees", sunset, nil),
                (6, 25, "Parking rental property visit", -18, "Auto and Travel", maple, nil)
            ]

            for row in approvedRows {
                insertTransaction(month: row.0, day: row.1, description: row.2, amount: row.3, category: row.4, property: row.5, tenant: row.6, approved: true, confidence: 0.96)
            }

            let inboxRows: [(Int, Int, String, Decimal, String, Property?, Tenant?)] = [
                (6, 27, "Online payment to Bay Area Handyman invoice 4812", -428.90, "Repairs", maple, nil),
                (6, 28, "ACH credit unknown tenant transfer", 1725, "Rent Income", nil, nil),
                (6, 29, "City water services billing", -132.44, "Utilities", sunset, nil),
                (6, 30, "Zelle payment from Jennifer rent", 1600, "Rent Income", nil, nil),
                (7, 1, "Ace Hardware property supplies", -67.31, "Supplies", pine, nil),
                (7, 2, "Insurance renewal rental dwelling", -318.20, "Insurance", nil, nil)
            ]

            for row in inboxRows {
                insertTransaction(month: row.0, day: row.1, description: row.2, amount: row.3, category: row.4, property: row.5, tenant: row.6, approved: false, confidence: 0.46)
            }

            try modelContext.save()
            resetStatus = "Screenshot data generated: 3 owner portfolios, 3 properties, 4 tenants, 39 approved transactions, 6 inbox reviews."
        } catch {
            resetStatus = "Seed failed: \(error.localizedDescription)"
        }
    }

    private func insertTransaction(
        month: Int,
        day: Int,
        description: String,
        amount: Decimal,
        category: String,
        property: Property?,
        tenant: Tenant?,
        approved: Bool,
        confidence: Double
    ) {
        let transaction = Transaction(
            date: date(month: month, day: day),
            descriptionText: description,
            amount: amount,
            category: category,
            confidence: confidence,
            approved: approved,
            source: approved ? "screenshot_seed" : "screenshot_seed_review",
            property: property,
            tenant: tenant
        )
        modelContext.insert(transaction)
    }

    private func date(month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day)) ?? Date()
    }
    #endif

    private func deleteAll<T: PersistentModel>(_ modelType: T.Type) throws {
        let items = try modelContext.fetch(FetchDescriptor<T>())
        for item in items {
            modelContext.delete(item)
        }
    }
}
