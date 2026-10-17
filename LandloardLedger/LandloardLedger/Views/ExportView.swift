import SwiftUI
import SwiftData
import StoreKit

struct ExportView: View {

    private enum ReportPeriod: String, CaseIterable, Identifiable {
        case month = "Month"
        case last = "Last"
        case quarter = "Quarter"
        case year = "Year"
        case custom = "Custom"

        var id: String { rawValue }
    }

    private enum ExportScope: String, CaseIterable, Identifiable {
        case all = "All"
        case owner = "Owner"
        case property = "Property"

        var id: String { rawValue }
    }

    private struct ReportBreakdown: Identifiable {
        let title: String
        let count: Int
        let amount: Decimal

        var id: String { title }
    }

    private enum ProductID {
        static let proYearly = "landledger.pro.annual"
        static let taxExportPass = "landledger.tax_export_pass"
        static let all = [proYearly, taxExportPass]
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Property.name) private var properties: [Property]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var selectedPeriod: ReportPeriod = .month
    @State private var customStartDate = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 1, day: 1)) ?? Date()
    @State private var customEndDate = Date()
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedScope: ExportScope = .all
    @State private var selectedOwnerName = ""
    @State private var selectedPropertyName = ""
    @State private var pdfData: Data?
    @State private var showShare = false
    @State private var isGenerating = false
    @State private var showPaywall = false
    @State private var products: [Product] = []
    @State private var purchasedProductIDs: Set<String> = []
    @State private var isLoadingProducts = false
    @State private var isPurchasing = false
    @State private var purchaseMessage: String?

    private var availableYears: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 4)...current).reversed()
    }

    private var hasExportAccess: Bool {
        purchasedProductIDs.contains(ProductID.proYearly) || purchasedProductIDs.contains(ProductID.taxExportPass)
    }

    private var sortedProducts: [Product] {
        products.sorted { lhs, rhs in
            productSortOrder(lhs.id) < productSortOrder(rhs.id)
        }
    }

    private var ownerNames: [String] {
        Array(Set(properties.map { $0.ownerName.trimmingCharacters(in: .whitespacesAndNewlines) }))
            .filter { !$0.isEmpty }
            .sorted()
    }

    private var propertyNames: [String] {
        properties.map(\.name).filter { !$0.isEmpty }.sorted()
    }

    private var exportProperties: [Property] {
        switch selectedScope {
        case .all:
            return properties
        case .owner:
            guard !selectedOwnerName.isEmpty else { return properties }
            return properties.filter { $0.ownerName == selectedOwnerName }
        case .property:
            guard !selectedPropertyName.isEmpty else { return properties }
            return properties.filter { $0.name == selectedPropertyName }
        }
    }

    private var exportScopeFilenamePart: String {
        switch selectedScope {
        case .all:
            return "All_Properties"
        case .owner:
            return selectedOwnerName.isEmpty ? "All_Owners" : filenameSafe(selectedOwnerName)
        case .property:
            return selectedPropertyName.isEmpty ? "Property" : filenameSafe(selectedPropertyName)
        }
    }

    private var reportTransactions: [Transaction] {
        let interval = reportDateInterval
        return transactions.filter { transaction in
            guard transaction.property != nil else { return false }
            guard interval.contains(transaction.date) else { return false }
            return matchesExportScope(transaction)
        }
    }

    private var reportIncome: Decimal {
        reportTransactions
            .filter { $0.amount > 0 }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    private var reportExpenses: Decimal {
        reportTransactions
            .filter { $0.amount < 0 }
            .reduce(Decimal(0)) { $0 + abs($1.amount) }
    }

    private var reportNet: Decimal {
        reportIncome - reportExpenses
    }

    private var categoryBreakdowns: [ReportBreakdown] {
        let grouped = Dictionary(grouping: reportTransactions) { transaction in
            let category = transaction.category.trimmingCharacters(in: .whitespacesAndNewlines)
            return category.isEmpty ? "Uncategorized" : category
        }

        return grouped.map { category, transactions in
            ReportBreakdown(
                title: category,
                count: transactions.count,
                amount: transactions.reduce(Decimal(0)) { $0 + $1.amount }
            )
        }
        .sorted { abs($0.amount) > abs($1.amount) }
    }

    private var propertyBreakdowns: [ReportBreakdown] {
        let grouped = Dictionary(grouping: reportTransactions) { transaction in
            transaction.property?.name ?? "No property"
        }

        return grouped.map { propertyName, transactions in
            ReportBreakdown(
                title: propertyName,
                count: transactions.count,
                amount: transactions.reduce(Decimal(0)) { $0 + $1.amount }
            )
        }
        .sorted { $0.amount > $1.amount }
    }

    private var reportDateInterval: DateInterval {
        let calendar = Calendar.current
        let now = Date()

        switch selectedPeriod {
        case .month:
            return calendar.dateInterval(of: .month, for: now) ?? DateInterval(start: now, duration: 0)
        case .last:
            let previousMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return calendar.dateInterval(of: .month, for: previousMonth) ?? DateInterval(start: previousMonth, duration: 0)
        case .quarter:
            let components = calendar.dateComponents([.year, .month], from: now)
            let month = components.month ?? 1
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            let start = calendar.date(from: DateComponents(year: components.year, month: quarterStartMonth, day: 1)) ?? now
            let end = calendar.date(byAdding: .month, value: 3, to: start) ?? now
            return DateInterval(start: start, end: end)
        case .year:
            let start = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1)) ?? now
            let end = calendar.date(byAdding: .year, value: 1, to: start) ?? now
            return DateInterval(start: start, end: end)
        case .custom:
            let start = calendar.startOfDay(for: min(customStartDate, customEndDate))
            let endBase = calendar.startOfDay(for: max(customStartDate, customEndDate))
            let end = calendar.date(byAdding: .day, value: 1, to: endBase) ?? endBase
            return DateInterval(start: start, end: end)
        }
    }

    private var reportPeriodTitle: String {
        let interval = reportDateInterval
        let start = interval.start.formatted(.dateTime.month(.abbreviated).day().year())
        let endDate = Calendar.current.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        let end = endDate.formatted(.dateTime.month(.abbreviated).day().year())
        return start == end ? start : "\(start) - \(end)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    reportPeriodSection
                    reportScopeSection
                    reportSummaryGrid

                    if reportTransactions.isEmpty {
                        ContentUnavailableView(
                            "No report data",
                            systemImage: "chart.bar.doc.horizontal",
                            description: Text("Assign properties to transactions for this period to see rental income, expenses, and net results.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        breakdownSection(title: "By Category", rows: categoryBreakdowns)
                        breakdownSection(title: "By Property", rows: propertyBreakdowns)
                    }

                    exportSection
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await refreshPurchases()
                await loadProductsIfNeeded()
            }
            .sheet(isPresented: $showPaywall) {
                paywallView
            }
            .sheet(isPresented: $showShare) {
                if let data = pdfData {
                    ShareSheetView(data: data, filename: exportFilename)
                }
            }
        }
    }

    private var reportPeriodSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Report Period")
                .font(.headline)

            Picker("Report Period", selection: $selectedPeriod) {
                ForEach(ReportPeriod.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)

            if selectedPeriod == .year {
                Picker("Year", selection: $selectedYear) {
                    ForEach(availableYears, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .pickerStyle(.menu)
            }

            if selectedPeriod == .custom {
                HStack {
                    DatePicker("From", selection: $customStartDate, displayedComponents: .date)
                    DatePicker("To", selection: $customEndDate, displayedComponents: .date)
                }
                .font(.caption)
            }

            Text(reportPeriodTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var reportScopeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Report Scope")
                .font(.headline)

            Picker("Report Scope", selection: $selectedScope) {
                ForEach(ExportScope.allCases) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            if selectedScope == .owner && !ownerNames.isEmpty {
                Picker("Owner / Portfolio", selection: $selectedOwnerName) {
                    Text("All Owners").tag("")
                    ForEach(ownerNames, id: \.self) { ownerName in
                        Text(ownerName).tag(ownerName)
                    }
                }
                .pickerStyle(.menu)
            }

            if selectedScope == .property && !propertyNames.isEmpty {
                Picker("Property", selection: $selectedPropertyName) {
                    Text("All Properties").tag("")
                    ForEach(propertyNames, id: \.self) { propertyName in
                        Text(propertyName).tag(propertyName)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var reportSummaryGrid: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                reportMetricCard(title: "Income", value: currencyString(reportIncome), systemImage: "dollarsign.circle", tint: .green)
                reportMetricCard(title: "Expenses", value: currencyString(reportExpenses), systemImage: "wrench.and.screwdriver", tint: .orange)
            }
            HStack(spacing: 14) {
                reportMetricCard(title: "Net", value: currencyString(reportNet), systemImage: "chart.bar.fill", tint: reportNet >= 0 ? .green : .red)
                reportMetricCard(title: "Records", value: "\(reportTransactions.count)", systemImage: "list.bullet.rectangle", tint: .blue)
            }
        }
    }

    private func reportMetricCard(title: String, value: String, systemImage: String, tint: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.bold())
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 102)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private func breakdownSection(title: String, rows: [ReportBreakdown]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            VStack(spacing: 10) {
                ForEach(rows.prefix(8)) { row in
                    HStack(spacing: 12) {
                        Image(systemName: iconName(for: row.title))
                            .foregroundStyle(row.amount >= 0 ? .green : .orange)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text("\(row.count) transaction\(row.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(currencyString(row.amount))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(row.amount >= 0 ? .green : .primary)
                    }
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                beginExport()
            } label: {
                if isGenerating {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.8)
                        Text("Generating...")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Label(exportButtonTitle, systemImage: hasExportAccess ? "square.and.arrow.up" : "lock.open")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isGenerating || exportProperties.isEmpty)

            if properties.isEmpty {
                Text("Add at least one property in Settings first.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if !hasExportAccess {
                Text("PDF export is included with LandLedger Pro or a one-time Tax Export Pass.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func matchesExportScope(_ transaction: Transaction) -> Bool {
        switch selectedScope {
        case .all:
            return true
        case .owner:
            guard !selectedOwnerName.isEmpty else { return true }
            return transaction.property?.ownerName == selectedOwnerName
        case .property:
            guard !selectedPropertyName.isEmpty else { return true }
            return transaction.property?.name == selectedPropertyName
        }
    }

    private var exportButtonTitle: String {
        hasExportAccess ? "Export Tax PDF" : "Unlock PDF Export"
    }

    private var paywallView: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "building.columns")
                            .font(.system(size: 42))
                            .foregroundStyle(.tint)
                        Text("Unlock tax exports")
                            .font(.largeTitle.bold())
                        Text("Turn your reviewed rental transactions into a tax-year PDF when it is time to file.")
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        featureRow("Export Schedule E-style PDF summaries", systemImage: "doc.text")
                        featureRow("Include every property in one report", systemImage: "building.2")
                        featureRow("Keep bank data local, with no bank login", systemImage: "lock.shield")
                    }

                    if isLoadingProducts {
                        ProgressView("Loading purchase options...")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 24)
                    } else if sortedProducts.isEmpty {
                        unavailableProductsView
                    } else {
                        VStack(spacing: 12) {
                            ForEach(sortedProducts) { product in
                                Button {
                                    Task { await purchase(product) }
                                } label: {
                                    productRow(product)
                                }
                                .buttonStyle(.plain)
                                .disabled(isPurchasing)
                            }
                        }
                    }

                    if let purchaseMessage {
                        Text(purchaseMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button("Restore Purchases") {
                        Task { await restorePurchases() }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(isPurchasing)

                    Text("LandLedger is an organizational tool and does not provide tax, legal, or accounting advice.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("LandLedger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showPaywall = false }
                }
            }
        }
    }

    private var unavailableProductsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Purchase options are not available yet.")
                .font(.headline)
            Text("Please check your connection and try again. If this continues, contact support.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func productRow(_ product: Product) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: product.id == ProductID.proYearly ? "crown" : "doc.badge.plus")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(product.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(product.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(product.displayPrice)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.quaternary, lineWidth: 1)
        )
    }

    private func featureRow(_ text: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
                .frame(width: 22)
            Text(text)
        }
        .font(.subheadline)
    }

    private func beginExport() {
        if hasExportAccess {
            generatePDF()
        } else {
            showPaywall = true
        }
    }

    private func loadProductsIfNeeded() async {
        guard products.isEmpty else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            products = try await Product.products(for: ProductID.all)
        } catch {
            purchaseMessage = "Could not load purchase options. Please try again later."
        }
    }

    private func purchase(_ product: Product) async {
        isPurchasing = true
        purchaseMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                purchasedProductIDs.insert(transaction.productID)
                await transaction.finish()
                showPaywall = false
                generatePDF()
            case .userCancelled:
                break
            case .pending:
                purchaseMessage = "Purchase is pending approval."
            @unknown default:
                purchaseMessage = "Purchase could not be completed."
            }
        } catch {
            purchaseMessage = "Purchase failed. Please try again."
        }
    }

    private func restorePurchases() async {
        isPurchasing = true
        purchaseMessage = nil
        defer { isPurchasing = false }

        do {
            try await AppStore.sync()
            await refreshPurchases()
            purchaseMessage = hasExportAccess ? "Purchases restored." : "No export purchase was found."
        } catch {
            purchaseMessage = "Could not restore purchases. Please try again."
        }
    }

    private func refreshPurchases() async {
        var activeProductIDs = Set<String>()

        for await result in StoreKit.Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if ProductID.all.contains(transaction.productID) {
                activeProductIDs.insert(transaction.productID)
            }
        }

        purchasedProductIDs = activeProductIDs
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private func productSortOrder(_ productID: String) -> Int {
        switch productID {
        case ProductID.proYearly: return 0
        case ProductID.taxExportPass: return 1
        default: return 2
        }
    }

    private func iconName(for title: String) -> String {
        switch title {
        case "Rent Income": return "dollarsign.circle"
        case "Utilities": return "bolt"
        case "Repairs", "Cleaning and Maintenance": return "wrench.and.screwdriver"
        case "Taxes": return "building.columns"
        case "Insurance": return "shield"
        case "Mortgage", "Other Interest": return "house"
        case "Supplies": return "shippingbox"
        case "Management Fees", "Legal and Professional Fees": return "briefcase"
        default: return "tag"
        }
    }

    private func currencyString(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }

    private var exportFilename: String {
        "LandLedger_\(exportScopeFilenamePart)_\(selectedYear).pdf"
    }

    private func generatePDF() {
        isGenerating = true
        let propertiesToExport = exportProperties
        DispatchQueue.global(qos: .userInitiated).async {
            let data = PDFExporter.buildPDF(properties: propertiesToExport, year: selectedYear)
            DispatchQueue.main.async {
                pdfData = data
                isGenerating = false
                showShare = true
            }
        }
    }

    private func filenameSafe(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"[^A-Za-z0-9]+"#, with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }

    private func transactionCount(for property: Property, year: Int) -> Int {
        property.approvedTransactions.filter {
            Calendar.current.component(.year, from: $0.date) == year
        }.count
    }
}

private enum StoreError: Error {
    case failedVerification
}

struct ShareSheetView: UIViewControllerRepresentable {

    let data: Data
    let filename: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)

        let controller = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
