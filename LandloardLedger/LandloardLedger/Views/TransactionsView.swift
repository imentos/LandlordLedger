import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

private struct TransactionMonthOption: Identifiable {
    let startDate: Date
    let title: String
    let count: Int
    let net: Decimal

    var id: Date { startDate }
}

private struct TransactionDayGroup: Identifiable {
    let date: Date
    let transactions: [Transaction]

    var id: Date { date }
}

struct TransactionsView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Property.name) private var properties: [Property]
    @Query private var tenants: [Tenant]
    @Query private var matchingRules: [MatchingRule]

    @State private var selectedPropertyName = ""
    @State private var selectedMonthStart: Date?
    @State private var searchText = ""
    @State private var showPropertyFilter = false
    @State private var showFileImporter = false
    @State private var showManualTransactionSheet = false
    @State private var importViewModel = ImportViewModel()
    @State private var showImportAlert = false
    @State private var importAlertTitle = ""
    @State private var importAlertMessage = ""
    @State private var selectedTransaction: Transaction?
    @State private var showMonthPicker = false
    @State private var monthPickerYear = Calendar.current.component(.year, from: Date())

    private var filterProperties: [Property] {
        properties
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.name < $1.name }
    }

    private var currentMonthStart: Date? {
        if let selectedMonthStart, monthOptions.contains(where: { Calendar.current.isDate($0.startDate, inSameDayAs: selectedMonthStart) }) {
            return selectedMonthStart
        }
        return monthOptions.first?.startDate
    }

    private var monthOptions: [TransactionMonthOption] {
        let base = transactions.filter { transaction in
            matchesProperty(transaction) && matchesSearch(transaction)
        }
        let grouped = Dictionary(grouping: base) { monthStart(for: $0.date) }

        return grouped.map { start, monthTransactions in
            TransactionMonthOption(
                startDate: start,
                title: start.formatted(.dateTime.month(.wide).year()),
                count: monthTransactions.count,
                net: monthTransactions.reduce(Decimal(0)) { $0 + $1.amount }
            )
        }
        .sorted { $0.startDate > $1.startDate }
    }

    private var visibleTransactions: [Transaction] {
        transactions.filter { transaction in
            matchesProperty(transaction)
                && matchesSearch(transaction)
                && matchesMonth(transaction)
        }
    }

    private var dayGroups: [TransactionDayGroup] {
        let grouped = Dictionary(grouping: visibleTransactions) { dayStart(for: $0.date) }
        return grouped
            .map { TransactionDayGroup(date: $0.key, transactions: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }

    private var selectedMonthOption: TransactionMonthOption? {
        guard let currentMonthStart else { return nil }
        return monthOptions.first { Calendar.current.isDate($0.startDate, inSameDayAs: currentMonthStart) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if transactions.isEmpty {
                    emptyState
                } else {
                    transactionList
                }
            }
            .navigationTitle("Transactions")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Search transactions"
            )
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showManualTransactionSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(properties.isEmpty)

                    Menu {
                        Button {
                            showFileImporter = true
                        } label: {
                            Label("Import CSV File", systemImage: "doc")
                        }

                        Button {
                            importFromClipboard()
                        } label: {
                            Label("Import from Clipboard", systemImage: "clipboard")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .disabled(properties.isEmpty)

                    Button {
                        showPropertyFilter = true
                    } label: {
                        Label("Filter", systemImage: selectedPropertyName.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                    .disabled(filterProperties.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !monthOptions.isEmpty {
                    monthSwitcher
                }
            }
            .sheet(isPresented: $showPropertyFilter) {
                propertyFilterSheet
            }
            .sheet(isPresented: $showManualTransactionSheet) {
                ManualTransactionView()
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                handleImportFilePick(result)
            }
            .alert(importAlertTitle, isPresented: $showImportAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importAlertMessage)
            }
            .navigationDestination(item: $selectedTransaction) { transaction in
                TransactionDetailView(transaction: transaction)
            }
            .sheet(isPresented: $showMonthPicker) {
                monthPickerSheet
            }
            .onChange(of: showMonthPicker) { _, isPresented in
                if isPresented {
                    monthPickerYear = selectedMonthYear
                }
            }
        }
    }

    private func importFromClipboard() {
        guard let csvText = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines), !csvText.isEmpty else {
            showImportFeedback(title: "Nothing to Import", message: "Copy CSV text first, then try importing from Clipboard again.")
            return
        }

        Task {
            try? await importViewModel.importCSVText(
                csvText,
                properties: properties,
                tenants: tenants,
                matchingRules: matchingRules,
                modelContext: modelContext
            )
            finishImportFlow()
        }
    }

    private func handleImportFilePick(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await importViewModel.importCSV(
                    url: url,
                    properties: properties,
                    tenants: tenants,
                    matchingRules: matchingRules,
                    modelContext: modelContext
                )
                finishImportFlow()
            }
        case .failure(let error):
            showImportFeedback(title: "Import Cancelled", message: error.localizedDescription)
        }
    }

    private func finishImportFlow() {
        switch importViewModel.state {
        case .done(let summary):
            selectedPropertyName = ""
            selectedMonthStart = nil
            searchText = ""
            showImportFeedback(
                title: "Import Complete",
                message: "Added \(summary.totalParsed - summary.duplicatesSkipped) new transaction\((summary.totalParsed - summary.duplicatesSkipped) == 1 ? "" : "s")."
            )
        case .error(let message):
            showImportFeedback(title: "Import Failed", message: message)
        default:
            break
        }
    }

    private func showImportFeedback(title: String, message: String) {
        importAlertTitle = title
        importAlertMessage = message
        showImportAlert = true
    }

    private func deleteTransaction(_ transaction: Transaction) {
        if selectedTransaction?.persistentModelID == transaction.persistentModelID {
            selectedTransaction = nil
        }
        modelContext.delete(transaction)
        try? modelContext.save()
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No transactions yet",
            systemImage: "list.bullet.rectangle",
            description: Text("Import a CSV or add a manual transaction to start tracking rent income and expenses.")
        )
    }

    private var transactionList: some View {
        List {
            Section {
                headerSummary
                    .listRowInsets(.init(top: 8, leading: 16, bottom: 10, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            if visibleTransactions.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No matches",
                        systemImage: "magnifyingglass",
                        description: Text("Try another month, property, or search term.")
                    )
                    .listRowBackground(Color.clear)
                }
            } else {
                ForEach(dayGroups) { group in
                    Section(dayTitle(group.date)) {
                        ForEach(group.transactions) { transaction in
                            Button {
                                selectedTransaction = transaction
                            } label: {
                                TransactionListCard(transaction: transaction)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteTransaction(transaction)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .listRowInsets(.init(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var headerSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedMonthOption?.title ?? "All Months")
                        .font(.title3.bold())
                    Text(propertyFilterLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(currencyString(summaryNet))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(summaryNet >= 0 ? .green : .red)
                    Text("Net")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                metricPill(title: "Transactions", value: "\(visibleTransactions.count)", systemImage: "list.bullet")
                metricPill(title: "Needs Review", value: "\(needsReviewCount)", systemImage: "tray")
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var monthSwitcher: some View {
        Button {
            showMonthPicker = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.subheadline.weight(.semibold))

                VStack(alignment: .leading, spacing: 1) {
                    Text(selectedMonthOption.map { shortMonthTitle($0.startDate) } ?? "Select Month")
                        .font(.subheadline.weight(.semibold))
                    Text(selectedMonthOption.map { "\($0.count) txns · \(currencyString($0.net))" } ?? "Choose a month")
                        .font(.caption2)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.up")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Color.accentColor, in: Capsule())
            .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
        .background(Color.clear)
    }

    private var propertyFilterSheet: some View {
        NavigationStack {
            List {
                Section("Property") {
                    propertyFilterRow(title: "All Properties", propertyName: "", ownerName: "")
                    ForEach(filterProperties) { property in
                        propertyFilterRow(
                            title: property.name,
                            propertyName: property.name,
                            ownerName: property.ownerName
                        )
                    }
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showPropertyFilter = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var monthPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 22) {
                HStack {
                    Button {
                        monthPickerYear -= 1
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.semibold))
                    }
                    .disabled(!hasAnyMonth(in: monthPickerYear - 1))

                    Spacer()

                    Text(String(monthPickerYear))
                        .font(.title.bold())

                    Spacer()

                    Button {
                        monthPickerYear += 1
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title3.weight(.semibold))
                    }
                    .disabled(!hasAnyMonth(in: monthPickerYear + 1))
                }
                .padding(.horizontal, 4)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 14) {
                    ForEach(1...12, id: \.self) { monthNumber in
                        monthGridButton(monthNumber)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .navigationTitle("Select Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showMonthPicker = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Today") {
                        selectClosestMonth(to: Date())
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func monthGridButton(_ monthNumber: Int) -> some View {
        let option = monthOption(year: monthPickerYear, month: monthNumber)
        let selected = option.map { selectedMonthOption?.id == $0.id } ?? false
        let title = DateFormatter().shortMonthSymbols[monthNumber - 1]

        return Button {
            guard let option else { return }
            selectedMonthStart = option.startDate
            showMonthPicker = false
        } label: {
            VStack(spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let option {
                    Text("\(option.count) txns")
                        .font(.caption2)
                        .opacity(selected ? 0.85 : 0.55)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .foregroundStyle(option == nil ? Color.secondary.opacity(0.45) : (selected ? .white : .primary))
            .background(selected ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 9))
            .opacity(option == nil ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(option == nil)
    }

    private func propertyFilterRow(title: String, propertyName: String, ownerName: String) -> some View {
        Button {
            selectedPropertyName = propertyName
            selectedMonthStart = nil
            showPropertyFilter = false
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    if !ownerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(ownerName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if selectedPropertyName == propertyName {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
        .foregroundStyle(.primary)
    }

    private var selectedMonthYear: Int {
        let date = selectedMonthOption?.startDate ?? monthOptions.first?.startDate ?? Date()
        return Calendar.current.component(.year, from: date)
    }

    private func monthOption(year: Int, month: Int) -> TransactionMonthOption? {
        monthOptions.first { option in
            let components = Calendar.current.dateComponents([.year, .month], from: option.startDate)
            return components.year == year && components.month == month
        }
    }

    private func hasAnyMonth(in year: Int) -> Bool {
        monthOptions.contains { Calendar.current.component(.year, from: $0.startDate) == year }
    }

    private func selectClosestMonth(to date: Date) {
        let target = monthStart(for: date)
        let exact = monthOptions.first { Calendar.current.isDate($0.startDate, inSameDayAs: target) }
        let option = exact ?? monthOptions.first
        selectedMonthStart = option?.startDate
        showMonthPicker = false
    }

    private func metricPill(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private var summaryNet: Decimal {
        visibleTransactions.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var needsReviewCount: Int {
        visibleTransactions.filter { $0.property == nil }.count
    }

    private var propertyFilterLabel: String {
        selectedPropertyName.isEmpty ? "All properties" : selectedPropertyName
    }

    private func matchesProperty(_ transaction: Transaction) -> Bool {
        guard !selectedPropertyName.isEmpty else { return true }
        return transaction.property?.name == selectedPropertyName
    }

    private func matchesMonth(_ transaction: Transaction) -> Bool {
        guard let currentMonthStart else { return true }
        return Calendar.current.isDate(monthStart(for: transaction.date), inSameDayAs: currentMonthStart)
    }

    private func matchesSearch(_ transaction: Transaction) -> Bool {
        let query = normalized(searchText)
        guard !query.isEmpty else { return true }

        let values = [
            transaction.descriptionText,
            transaction.category,
            transaction.property?.name,
            transaction.property?.address,
            transaction.property?.ownerName,
            transaction.tenant?.name,
            transaction.tenant?.unit,
            currencyString(transaction.amount),
            transaction.date.formatted(date: .abbreviated, time: .omitted)
        ]
        return normalized(values.compactMap { $0 }.joined(separator: " ")).contains(query)
    }

    private func monthStart(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private func dayStart(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private func isSelected(_ month: TransactionMonthOption) -> Bool {
        guard let currentMonthStart else { return false }
        return Calendar.current.isDate(month.startDate, inSameDayAs: currentMonthStart)
    }

    private func dayTitle(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private func shortMonthTitle(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).year())
    }

    private func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9. ]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func currencyString(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }
}

private struct TransactionListCard: View {

    let transaction: Transaction

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                statusIcon

                VStack(alignment: .leading, spacing: 3) {
                    Text(transaction.descriptionText)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)

                    Text(metadataLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text(currencyString(transaction.amount))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(transaction.amount >= 0 ? .green : .primary)
            }

            HStack(spacing: 8) {
                if let owner = transaction.property?.ownerName, !owner.isEmpty {
                    chip(owner, systemImage: "person.2")
                }

                if !transaction.category.isEmpty {
                    chip(transaction.category, systemImage: "tag")
                }

                if needsReview {
                    chip("Needs Review", systemImage: "exclamationmark.circle", tint: .orange)
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(needsReview ? Color.orange.opacity(0.55) : Color.secondary.opacity(0.22), lineWidth: 1)
        )
    }

    private var statusIcon: some View {
        Image(systemName: needsReview ? "questionmark.circle.fill" : "checkmark.circle.fill")
            .font(.title3)
            .foregroundStyle(needsReview ? .orange : .green)
    }

    private var needsReview: Bool {
        transaction.property == nil
    }

    private var metadataLine: String {
        let propertyName = transaction.property?.name ?? "No property"
        if let tenant = transaction.tenant {
            return "\(propertyName) · \(tenant.name)"
        }
        return propertyName
    }

    private func chip(_ title: String, systemImage: String, tint: Color = .secondary) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .imageScale(.small)
            Text(title)
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(tint)
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(tint.opacity(0.10), in: Capsule())
    }

    private func currencyString(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }
}


private struct TransactionDetailView: View {

    @Bindable var transaction: Transaction

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Property.name) private var properties: [Property]
    @Query(sort: \Tenant.name) private var tenants: [Tenant]

    @State private var selectedPropertyName = ""
    @State private var selectedTenantID: PersistentIdentifier?
    @State private var selectedCategory = ""

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
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayName)
                                .font(.title3.bold())
                                .fixedSize(horizontal: false, vertical: true)
                            Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 12)

                        Text(currencyString(transaction.amount))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(transaction.amount >= 0 ? .green : .primary)
                    }

                    Label(needsReview ? "Needs Review" : "Confirmed", systemImage: needsReview ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(needsReview ? .orange : .green)
                }
                .padding(.vertical, 6)
            }

            Section("Bank Description") {
                Text(readableDescription)
                    .font(.body)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Property") {
                if properties.isEmpty {
                    Text("Add properties first.")
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(properties) { property in
                                chipButton(
                                    title: property.name,
                                    selected: selectedPropertyName == property.name
                                ) {
                                    selectedPropertyName = property.name
                                    if selectedTenantID != nil && !tenantsForSelectedProperty.contains(where: { $0.persistentModelID == selectedTenantID }) {
                                        selectedTenantID = nil
                                    }
                                    saveSelection()
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if selectedCategory == "Rent Income" || transaction.amount > 0 {
                Section("Tenant") {
                    if tenantsForSelectedProperty.isEmpty {
                        Text("No tenants for this property yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                chipButton(title: "No tenant", selected: selectedTenantID == nil) {
                                    selectedTenantID = nil
                                    saveSelection()
                                }

                                ForEach(tenantsForSelectedProperty) { tenant in
                                    chipButton(
                                        title: tenantChipTitle(tenant),
                                        selected: selectedTenantID == tenant.persistentModelID
                                    ) {
                                        selectedTenantID = tenant.persistentModelID
                                        if let propertyName = tenant.property?.name {
                                            selectedPropertyName = propertyName
                                        }
                                        saveSelection()
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }

            Section("Category") {
                Menu {
                    ForEach(Self.categories, id: \.self) { category in
                        Button(category) {
                            selectedCategory = category
                            saveSelection()
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedCategory.isEmpty ? "Choose category" : selectedCategory)
                            .foregroundStyle(selectedCategory.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

        }
        .navigationTitle("Transaction")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedPropertyName = transaction.property?.name ?? ""
            selectedTenantID = transaction.tenant?.persistentModelID
            selectedCategory = transaction.category
        }
    }

    private var needsReview: Bool {
        transaction.property == nil
    }

    private var tenantsForSelectedProperty: [Tenant] {
        tenants
            .filter { tenant in
                guard !selectedPropertyName.isEmpty else { return true }
                return tenant.property?.name == selectedPropertyName
            }
            .sorted { $0.name < $1.name }
    }

    private func saveSelection() {
        guard let matchedProperty = properties.first(where: { $0.name == selectedPropertyName }) else { return }

        let matchedTenant = tenants.first { $0.persistentModelID == selectedTenantID }
        let acceptedSuggestion = transaction.category == selectedCategory
            && transaction.property?.name == selectedPropertyName
            && transaction.tenant?.persistentModelID == selectedTenantID

        transaction.property = matchedProperty
        transaction.tenant = matchedTenant
        transaction.category = selectedCategory
        transaction.approved = true
        transaction.source = acceptedSuggestion ? "user_confirmed" : "user_corrected"

        saveMatchingRuleIfNeeded(property: matchedProperty, tenant: matchedTenant)
        try? modelContext.save()
    }

    private func saveMatchingRuleIfNeeded(property: Property?, tenant: Tenant?) {
        guard property != nil || tenant != nil else { return }
        guard !transaction.category.isEmpty else { return }

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
            modelContext.insert(MatchingRule(
                normalizedPattern: pattern,
                category: transaction.category,
                property: property,
                tenant: tenant,
                source: transaction.source
            ))
        }
    }

    private func chipButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(selected ? Color.accentColor : Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private func tenantChipTitle(_ tenant: Tenant) -> String {
        guard !tenant.unit.isEmpty else { return tenant.name }
        return "\(tenant.name) · Unit \(tenant.unit)"
    }

    private var displayName: String {
        extractedDisplayName(from: transaction.descriptionText)
    }

    private var readableDescription: String {
        transaction.descriptionText
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func currencyString(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }
}
