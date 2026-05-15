import SwiftUI
import SwiftData

private struct TenantUnitGroup: Identifiable {
    let unit: String
    let title: String
    let tenants: [Tenant]

    var id: String { unit.isEmpty ? "__no_unit__" : unit }
    var isUnassigned: Bool { unit.isEmpty }
}

struct PropertyDetailView: View {

    let property: Property

    @Environment(\.modelContext) private var modelContext

    @State private var showEditSheet = false
    @State private var showAddTenantSheet = false
    @State private var tenantToEdit: Tenant?
    @State private var tenantToDelete: Tenant?
    @State private var transactionToReview: Transaction?

    private var groupedTransactions: [(String, [Transaction])] {
        let approved = property.approvedTransactions.sorted { $0.date > $1.date }
        let grouped  = Dictionary(grouping: approved) { tx in
            tx.date.formatted(.dateTime.year(.defaultDigits).month(.abbreviated))
        }
        // Sort months newest first
        let sorted = grouped.sorted { a, b in
            guard let da = approvedTransactions(for: a.key).first?.date,
                  let db = approvedTransactions(for: b.key).first?.date else { return false }
            return da > db
        }
        return sorted
    }

    var body: some View {
        List {
            // Summary header
            Section {
                summarySection
            }

            Section("Tenants") {
                if property.tenants.isEmpty {
                    Text("No tenants yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tenantUnitGroups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(group.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(group.tenants.count) tenant\(group.tenants.count == 1 ? "" : "s")")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }

                            ForEach(group.tenants) { tenant in
                                Button {
                                    tenantToEdit = tenant
                                } label: {
                                    tenantRow(tenant, showsUnit: group.isUnassigned)
                                }
                                .buttonStyle(.plain)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        tenantToDelete = tenant
                                    } label: {
                                        Label("Delete \(tenant.name)", systemImage: "trash")
                                    }
                                }

                                if tenant.id != group.tenants.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Button {
                    showAddTenantSheet = true
                } label: {
                    Label("Add Tenant", systemImage: "person.badge.plus")
                }
            }

            // Transactions by month
            ForEach(groupedTransactions, id: \.0) { month, txs in
                Section(month) {
                    ForEach(txs) { tx in
                        transactionRow(tx)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    transactionToReview = tx
                                } label: {
                                    Label("Review", systemImage: "tray.and.arrow.down")
                                }
                                .tint(.orange)
                            }
                    }
                }
            }

            if property.approvedTransactions.isEmpty {
                Section {
                    Text("No approved transactions yet.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle(property.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    showEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            PropertyFormView(mode: .edit(property))
        }
        .sheet(isPresented: $showAddTenantSheet) {
            TenantFormView(property: property)
        }
        .sheet(item: $tenantToEdit) { tenant in
            TenantFormView(property: property, mode: .edit(tenant))
        }
        .confirmationDialog(
            "Delete tenant?",
            isPresented: deleteConfirmationBinding,
            titleVisibility: .visible
        ) {
            Button("Delete \(tenantToDelete?.name ?? "Tenant")", role: .destructive) {
                if let tenantToDelete {
                    deleteTenant(tenantToDelete)
                }
                tenantToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                tenantToDelete = nil
            }
        } message: {
            Text(deleteConfirmationMessage)
        }
        .alert(
            "Move back to Inbox?",
            isPresented: reviewConfirmationBinding,
        ) {
            Button("Move to Inbox", role: .destructive) {
                if let transactionToReview {
                    moveTransactionBackToInbox(transactionToReview)
                }
                transactionToReview = nil
            }
            Button("Cancel", role: .cancel) {
                transactionToReview = nil
            }
        } message: {
            Text(reviewConfirmationMessage)
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(spacing: 12) {
            HStack {
                summaryCard("Income", value: property.totalIncome, color: .green)
                Divider()
                summaryCard("Expenses", value: property.totalExpenses, color: .red)
                Divider()
                summaryCard("Net", value: property.netIncome, color: property.netIncome >= 0 ? .green : .red)
            }
            .frame(height: 60)

            if !property.address.isEmpty {
                Text(property.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func summaryCard(_ label: String, value: Decimal, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(currencyString(value))
                .font(.subheadline.bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Transaction row

    private func transactionRow(_ tx: Transaction) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(tx.descriptionText)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(transactionSubtitle(tx))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(currencyString(tx.amount))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(tx.amount >= 0 ? .green : .primary)
                Text(tx.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func tenantRow(_ tenant: Tenant, showsUnit: Bool = false) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(tenant.name)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    if tenant.expectedMonthlyRent > 0 {
                        Text(currencyString(tenant.expectedMonthlyRent))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                }

                let details = [showsUnit && !tenant.unit.isEmpty ? "Unit \(tenant.unit)" : nil,
                               tenant.aliases.isEmpty ? nil : tenant.aliases.joined(separator: ", ")]
                    .compactMap { $0 }
                    .joined(separator: " • ")
                if !details.isEmpty {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private func deleteTenant(_ tenant: Tenant) {
        modelContext.delete(tenant)
        try? modelContext.save()
    }

    private func moveTransactionBackToInbox(_ transaction: Transaction) {
        transaction.approved = false
        transaction.source = "needs_manual_review"
        transaction.confidence = min(transaction.confidence, 0.25)
        try? modelContext.save()
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { tenantToDelete != nil },
            set: { isPresented in
                if !isPresented {
                    tenantToDelete = nil
                }
            }
        )
    }

    private var reviewConfirmationBinding: Binding<Bool> {
        Binding(
            get: { transactionToReview != nil },
            set: { isPresented in
                if !isPresented {
                    transactionToReview = nil
                }
            }
        )
    }

    // MARK: - Helpers

    private func currencyString(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }

    private func transactionSubtitle(_ tx: Transaction) -> String {
        if let tenant = tx.tenant {
            return "\(tx.category) • \(tenant.name)"
        }
        return tx.category
    }

    private var deleteConfirmationMessage: String {
        guard let tenant = tenantToDelete else {
            return "This tenant will be removed from the property."
        }

        if tenant.unit.isEmpty {
            return "Remove \(tenant.name) from \(property.name)?"
        }

        return "Remove \(tenant.name) from Unit \(tenant.unit) at \(property.name)?"
    }

    private var reviewConfirmationMessage: String {
        guard let transaction = transactionToReview else {
            return "This transaction will appear in Inbox again."
        }

        return "\(transaction.descriptionText) will move out of \(property.name) and appear in Inbox so you can assign it again."
    }

    private var sortedTenants: [Tenant] {
        property.tenants.sorted { lhs, rhs in
            switch compareUnits(lhs.unit, rhs.unit) {
            case .orderedAscending:
                return true
            case .orderedDescending:
                return false
            case .orderedSame:
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }

    private var tenantUnitGroups: [TenantUnitGroup] {
        let grouped = Dictionary(grouping: sortedTenants) { tenant in
            normalizedUnit(tenant.unit)
        }

        return grouped
            .map { unit, tenants in
                TenantUnitGroup(
                    unit: unit,
                    title: unit.isEmpty ? "No Unit" : "Unit \(unit)",
                    tenants: tenants.sorted {
                        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                )
            }
            .sorted { lhs, rhs in
                compareUnits(lhs.unit, rhs.unit) == .orderedAscending
            }
    }

    private func normalizedUnit(_ unit: String) -> String {
        unit.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func compareUnits(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = unitSortKey(lhs)
        let right = unitSortKey(rhs)

        switch (left.number, right.number) {
        case let (leftNumber?, rightNumber?) where leftNumber != rightNumber:
            return leftNumber < rightNumber ? .orderedAscending : .orderedDescending
        case (_?, nil):
            return .orderedAscending
        case (nil, _?):
            return .orderedDescending
        default:
            return left.text.localizedCaseInsensitiveCompare(right.text)
        }
    }

    private func unitSortKey(_ unit: String) -> (number: Int?, text: String) {
        let trimmed = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let numberText = trimmed
            .replacingOccurrences(of: #"^\D*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\D.*$"#, with: "", options: .regularExpression)
        return (Int(numberText), trimmed)
    }

    /// Helper used to find a date for sorting month buckets.
    private func approvedTransactions(for month: String) -> [Transaction] {
        property.approvedTransactions.filter { tx in
            tx.date.formatted(.dateTime.year(.defaultDigits).month(.abbreviated)) == month
        }
    }
}

struct TenantFormView: View {

    enum Mode {
        case add
        case edit(Tenant)
    }

    let property: Property
    let mode: Mode

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var unit = ""
    @State private var aliases = ""
    @State private var expectedMonthlyRent = ""

    init(property: Property, mode: Mode = .add) {
        self.property = property
        self.mode = mode

        if case let .edit(tenant) = mode {
            _name = State(initialValue: tenant.name)
            _unit = State(initialValue: tenant.unit)
            _aliases = State(initialValue: tenant.aliases.joined(separator: ", "))
            _expectedMonthlyRent = State(initialValue: tenant.expectedMonthlyRent > 0 ? NSDecimalNumber(decimal: tenant.expectedMonthlyRent).stringValue : "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tenant") {
                    TextField("Name", text: $name)
                    TextField("Unit (optional)", text: $unit)
                    TextField("Expected monthly rent", text: $expectedMonthlyRent)
                        .keyboardType(.decimalPad)
                }

                Section {
                    TextField("Aliases (comma-separated)", text: $aliases)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                } footer: {
                    Text("Use sender names from Zelle or ACH descriptions. Example: DIANA MENDOZA MEDINA, CARLOS CARRANZA.")
                        .font(.caption)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let parsedAliases = aliases
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let rent = Decimal(string: expectedMonthlyRent.replacingOccurrences(of: ",", with: "")) ?? 0
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)

        switch mode {
        case .add:
            let tenant = Tenant(
                name: trimmedName,
                unit: trimmedUnit,
                aliases: parsedAliases,
                expectedMonthlyRent: rent,
                property: property
            )
            modelContext.insert(tenant)
        case .edit(let tenant):
            tenant.name = trimmedName
            tenant.unit = trimmedUnit
            tenant.aliases = parsedAliases
            tenant.expectedMonthlyRent = rent
            tenant.property = property
        }

        try? modelContext.save()
        dismiss()
    }

    private var navigationTitle: String {
        switch mode {
        case .add: return "Add Tenant"
        case .edit: return "Edit Tenant"
        }
    }
}
