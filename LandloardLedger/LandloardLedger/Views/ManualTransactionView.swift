import SwiftUI
import SwiftData

struct ManualTransactionView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Property.name) private var properties: [Property]
    @Query(sort: \Tenant.name) private var tenants: [Tenant]

    @State private var name = ""
    @State private var date = Date()
    @State private var amountText = ""
    @State private var isMoneyIn = false
    @State private var category = "Other Expense"
    @State private var selectedPropertyID: PersistentIdentifier?
    @State private var selectedTenantID: PersistentIdentifier?
    @State private var flagForReview = false
    @State private var notes = ""

    private let categories = LocalCategorizationService.scheduleECategories
        .filter { $0 != "Personal/Unknown" }

    private var selectedProperty: Property? {
        properties.first { $0.persistentModelID == selectedPropertyID }
    }

    private var selectedTenant: Tenant? {
        tenants.first { $0.persistentModelID == selectedTenantID }
    }

    private var tenantsForSelectedProperty: [Tenant] {
        tenants
            .filter { tenant in
                guard let selectedPropertyID else { return false }
                return tenant.property?.persistentModelID == selectedPropertyID
            }
            .sorted { lhs, rhs in
                unitSortKey(lhs.unit) == unitSortKey(rhs.unit)
                    ? lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                    : unitSortKey(lhs.unit) < unitSortKey(rhs.unit)
            }
    }

    private var parsedAmount: Decimal? {
        let cleaned = amountText
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return Decimal(string: cleaned)
    }

    private var signedAmount: Decimal? {
        guard let parsedAmount else { return nil }
        let magnitude = abs(parsedAmount)
        return isMoneyIn ? magnitude : -magnitude
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && signedAmount != nil
            && !category.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $flagForReview) {
                        Label("Flag for Inbox review", systemImage: "flag")
                    }

                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)

                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)

                    Picker("Direction", selection: $isMoneyIn) {
                        Text("Money out").tag(false)
                        Text("Money in").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: isMoneyIn) { _, newValue in
                        if newValue && category == "Other Expense" {
                            category = "Rent Income"
                        } else if !newValue && category == "Rent Income" {
                            category = "Other Expense"
                        }
                    }
                } header: {
                    Text("Transaction")
                }

                Section {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }

                    Picker("Property", selection: $selectedPropertyID) {
                        Text("No property").tag(PersistentIdentifier?.none)
                        ForEach(properties) { property in
                            Text(property.name).tag(Optional(property.persistentModelID))
                        }
                    }
                    .onChange(of: selectedPropertyID) {
                        selectedTenantID = nil
                    }

                    if isMoneyIn || category == "Rent Income" {
                        Picker("Tenant", selection: $selectedTenantID) {
                            Text("No tenant").tag(PersistentIdentifier?.none)
                            ForEach(tenantsForSelectedProperty) { tenant in
                                Text(tenantDisplayName(tenant)).tag(Optional(tenant.persistentModelID))
                            }
                        }
                        .disabled(selectedPropertyID == nil)
                    }
                } header: {
                    Text("Assignment")
                } footer: {
                    if selectedPropertyID == nil && !flagForReview {
                        Text("Transactions without a property will be saved to Inbox for review.")
                    }
                }

                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 90)
                } header: {
                    Text("Notes")
                }
            }
            .navigationTitle("Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if selectedPropertyID == nil {
                    selectedPropertyID = properties.first?.persistentModelID
                }
            }
        }
    }

    private func save() {
        guard let signedAmount else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = trimmedNotes.isEmpty ? trimmedName : "\(trimmedName) - \(trimmedNotes)"
        let shouldApprove = !flagForReview && selectedProperty != nil

        let transaction = Transaction(
            date: date,
            descriptionText: description,
            amount: signedAmount,
            category: category,
            confidence: shouldApprove ? 1.0 : 0.25,
            approved: shouldApprove,
            source: shouldApprove ? "manual" : "manual_needs_review",
            property: selectedProperty,
            tenant: selectedTenant
        )

        modelContext.insert(transaction)
        try? modelContext.save()
        dismiss()
    }

    private func tenantDisplayName(_ tenant: Tenant) -> String {
        tenant.unit.isEmpty ? tenant.name : "\(tenant.name) - Unit \(tenant.unit)"
    }

    private func unitSortKey(_ unit: String) -> String {
        let trimmed = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "zzzz" }
        let numberText = trimmed
            .replacingOccurrences(of: #"^\D*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\D.*$"#, with: "", options: .regularExpression)
        let numberPrefix = String(format: "%06d", Int(numberText) ?? Int.max)
        return "\(numberPrefix)-\(trimmed.lowercased())"
    }
}

#Preview {
    ManualTransactionView()
        .modelContainer(for: [Property.self, Tenant.self, Transaction.self, MatchingRule.self], inMemory: true)
}
