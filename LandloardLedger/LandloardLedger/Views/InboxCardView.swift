import SwiftUI
import SwiftData

struct InboxCardView: View {

    @Bindable var transaction: Transaction
    let properties: [Property]
    let tenants: [Tenant]

    @Environment(\.modelContext) private var modelContext

    @State private var expanded = false
    @State private var selectedPropertyName: String = ""
    @State private var selectedTenantID: PersistentIdentifier?
    @State private var selectedCategory: String = ""
    @State private var justConfirmed = false

    // MARK: - Schedule E categories

    private static let categories: [String] = [
        "Rent Income",
        "Advertising",
        "Auto and Travel",
        "Cleaning and Maintenance",
        "Commissions",
        "Insurance",
        "Legal and Professional Fees",
        "Management Fees",
        "Mortgage",
        "Other Interest",
        "Repairs",
        "Supplies",
        "Taxes",
        "Utilities",
        "Depreciation",
        "Other Expense"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header row — always visible
            headerRow
                .padding()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        expanded.toggle()
                    }
                }

            // Expanded edit panel
            if expanded {
                Divider()
                editPanel
                    .padding()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(expanded ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: expanded ? 1.5 : 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        .onAppear {
            selectedPropertyName = transaction.property?.name ?? ""
            selectedTenantID     = transaction.tenant?.persistentModelID
            selectedCategory     = transaction.category
        }
    }

    // MARK: - Header row

    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                confidenceBadge

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(amountFormatted)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(transaction.amount >= 0 ? .green : .primary)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !secondaryDescription.isEmpty {
                Text(secondaryDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    // MARK: - Edit panel

    private var editPanel: some View {
        VStack(spacing: 16) {
            detailBlock

            Divider()

            // Rules suggestion (if any)
            if !transaction.category.isEmpty {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text("Suggested: \(transaction.category)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }

            // Property picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Property")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                if properties.isEmpty {
                    Text("Add properties in Settings first.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(properties) { prop in
                                chipButton(
                                    title: prop.name,
                                    selected: selectedPropertyName == prop.name
                                ) {
                                    selectedPropertyName = prop.name
                                }
                            }
                        }
                    }
                }
            }

            // Category picker
            if selectedCategory == "Rent Income" || transaction.amount > 0 {
                tenantPicker
            }

            // Category picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Category")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Menu {
                    ForEach(Self.categories, id: \.self) { cat in
                        Button(cat) { selectedCategory = cat }
                    }
                } label: {
                    HStack {
                        Text(selectedCategory.isEmpty ? "Choose category…" : selectedCategory)
                            .font(.subheadline)
                            .foregroundStyle(selectedCategory.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }
            }

            // Confirm button
            Button {
                confirm()
            } label: {
                Text(justConfirmed ? "Confirmed!" : "Confirm")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedPropertyName.isEmpty || selectedCategory.isEmpty)
        }
    }

    // MARK: - Confirm action

    private func confirm() {
        // Find property by name
        let matched = properties.first { $0.name == selectedPropertyName }
        let matchedTenant = tenants.first { $0.persistentModelID == selectedTenantID }
        let acceptedSuggestion = transaction.category == selectedCategory
            && transaction.property?.name == selectedPropertyName
            && transaction.tenant?.persistentModelID == selectedTenantID

        transaction.property   = matched
        transaction.tenant     = matchedTenant
        transaction.category   = selectedCategory
        transaction.approved   = true
        transaction.source     = acceptedSuggestion ? "user_confirmed" : "user_corrected"

        saveMatchingRuleIfNeeded(property: matched, tenant: matchedTenant)

        withAnimation {
            justConfirmed = true
        }

        // Collapse after brief delay so user sees the confirmation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                expanded = false
            }
        }

        try? modelContext.save()
    }

    // MARK: - Helpers

    private var amountFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: transaction.amount)) ?? "\(transaction.amount)"
    }

    private var confidenceBadge: some View {
        let pct = Int((transaction.confidence * 100).rounded())
        let color: Color = transaction.confidence >= 0.5 ? .orange : .red
        return Text("\(pct)%")
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
    }

    private var tenantPicker: some View {
        let availableTenants = tenantsForSelectedProperty

        return VStack(alignment: .leading, spacing: 6) {
            Text("Tenant")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            if availableTenants.isEmpty {
                Text("Add tenants on the property detail screen to enable rent matching.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chipButton(
                            title: "No tenant",
                            selected: selectedTenantID == nil
                        ) {
                            selectedTenantID = nil
                        }

                        ForEach(availableTenants) { tenant in
                            chipButton(
                                title: tenantChipTitle(tenant, in: availableTenants),
                                selected: selectedTenantID == tenant.persistentModelID
                            ) {
                                selectedTenantID = tenant.persistentModelID
                                if let propertyName = tenant.property?.name {
                                    selectedPropertyName = propertyName
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var detailBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Bank description")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(readableDescription)
                .font(.footnote)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var tenantsForSelectedProperty: [Tenant] {
        let filtered = tenants.filter { tenant in
            guard !selectedPropertyName.isEmpty else { return true }
            return tenant.property?.name == selectedPropertyName
        }
        return filtered.sorted { $0.name < $1.name }
    }

    private func tenantChipTitle(_ tenant: Tenant, in tenants: [Tenant]) -> String {
        let hasDuplicateName = tenants.contains { other in
            other.persistentModelID != tenant.persistentModelID
                && other.name.compare(tenant.name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        guard hasDuplicateName, !tenant.unit.isEmpty else { return tenant.name }
        return "\(tenant.name) · Unit \(tenant.unit)"
    }

    private func saveMatchingRuleIfNeeded(property: Property?, tenant: Tenant?) {
        guard transaction.category != "Personal/Unknown" else { return }
        guard property != nil || tenant != nil else { return }

        let pattern = LocalCategorizationService.learnedPattern(from: transaction.descriptionText)
        guard !pattern.isEmpty else { return }

        let descriptor = FetchDescriptor<MatchingRule>(
            predicate: #Predicate<MatchingRule> { rule in
                rule.normalizedPattern == pattern
            }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.category = transaction.category
            existing.property = property
            existing.tenant = tenant
            existing.source = transaction.source
        } else {
            let rule = MatchingRule(
                normalizedPattern: pattern,
                category: transaction.category,
                property: property,
                tenant: tenant,
                source: transaction.source
            )
            modelContext.insert(rule)
        }
    }

    private var displayName: String {
        extractedDisplayName(from: transaction.descriptionText)
    }

    private var readableDescription: String {
        transaction.descriptionText
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var secondaryDescription: String {
        let readable = readableDescription
        guard readable != displayName else { return "" }

        if readable.lowercased().hasPrefix(displayName.lowercased()) {
            return ""
        }

        return readable
    }

    private func extractedDisplayName(from description: String) -> String {
        let readable = description
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let extractionPatterns = [
            #"(?i)Zelle payment from\s+(.+?)(?:\s+(?:JPM|BAC|WFCT|2DZ|[0-9])[A-Z0-9]*$)"#,
            #"(?i)Zelle payment to\s+(.+?)(?:\s+(?:JPM|BAC|WFCT|2DZ|[0-9])[A-Z0-9]*$)"#,
            #"(?i)ORIG CO NAME:\s*(.+?)\s+ORIG ID:"#,
            #"(?i)IND NAME:\s*(.+?)\s+TRN:"#,
            #"(?i)Online Payment\s+\d+\s+To\s+(.+?)(?:\s+\d{2}/\d{2})?$"#,
            #"(?i)Online Transfer to\s+(.+?)\s+transaction#:"#,
            #"(?i)DEPOSIT\s+ID NUMBER\s+(.+)$"#
        ]

        for pattern in extractionPatterns {
            if let match = readable.range(of: pattern, options: .regularExpression) {
                let matched = String(readable[match])
                if let captured = firstCapture(in: matched, pattern: pattern) {
                    return captured
                }
            }
        }

        return readable
    }

    private func firstCapture(in value: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: value) else {
            return nil
        }

        let captured = String(value[captureRange])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return captured.isEmpty ? nil : captured
    }

    private func chipButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? Color.accentColor : Color.secondary.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
