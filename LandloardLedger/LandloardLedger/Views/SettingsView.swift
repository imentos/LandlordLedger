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
                Text("Use imported reset to rerun CSV tests while keeping setup. Use all test data reset to delete properties, tenants, transactions, and learned matching rules.")
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

    private func deleteAll<T: PersistentModel>(_ modelType: T.Type) throws {
        let items = try modelContext.fetch(FetchDescriptor<T>())
        for item in items {
            modelContext.delete(item)
        }
    }
}
