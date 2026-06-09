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

            let property = Property(
                name: "Maple Ave Duplex",
                address: "128 Maple Ave",
                keywords: ["maple", "duplex", "128 maple"]
            )
            let tenant = Tenant(
                name: "Sarah Chen",
                unit: "Unit A",
                aliases: ["Sarah Chen"],
                expectedMonthlyRent: 2400,
                property: property
            )

            modelContext.insert(property)
            modelContext.insert(tenant)

            let rows: [(Int, Int, String, Decimal, String)] = [
                (1, 3, "Zelle payment from Sarah Chen rent payment", 2400, "Rent Income"),
                (1, 5, "State Farm insurance policy", -142.50, "Insurance"),
                (1, 9, "PG&E utility bill", -186.42, "Utilities"),
                (1, 15, "Home Depot supplies", -74.28, "Supplies"),
                (2, 3, "Zelle payment from Sarah Chen rent payment", 2400, "Rent Income"),
                (2, 11, "Plumbing repair invoice", -365, "Repairs"),
                (2, 19, "County property tax collector", -1225, "Taxes"),
                (3, 3, "Zelle payment from Sarah Chen rent payment", 2400, "Rent Income"),
                (3, 7, "Waste Management garbage service", -96.10, "Utilities"),
                (3, 21, "Landscaping monthly service", -180, "Cleaning and Maintenance"),
                (4, 3, "Zelle payment from Sarah Chen rent payment", 2400, "Rent Income"),
                (4, 12, "Roofing repair deposit", -640, "Repairs"),
                (4, 25, "CPA bookkeeping rental property", -250, "Legal and Professional Fees"),
                (5, 3, "Zelle payment from Sarah Chen rent payment", 2400, "Rent Income"),
                (5, 10, "Lowes supplies", -128.76, "Supplies"),
                (5, 22, "Xfinity internet utility", -89.99, "Utilities"),
                (6, 3, "Zelle payment from Sarah Chen rent payment", 2400, "Rent Income"),
                (6, 8, "Locksmith repair", -155, "Repairs"),
                (6, 16, "Property management fee", -192, "Management Fees"),
                (6, 25, "Parking rental property visit", -18, "Auto and Travel")
            ]

            for row in rows {
                let transaction = Transaction(
                    date: date(month: row.0, day: row.1),
                    descriptionText: row.2,
                    amount: row.3,
                    category: row.4,
                    confidence: 0.96,
                    approved: true,
                    source: "screenshot_seed",
                    property: property,
                    tenant: row.4 == "Rent Income" ? tenant : nil
                )
                modelContext.insert(transaction)
            }

            try modelContext.save()
            resetStatus = "Screenshot data generated: 1 property, 1 tenant, 20 transactions."
        } catch {
            resetStatus = "Seed failed: \(error.localizedDescription)"
        }
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
