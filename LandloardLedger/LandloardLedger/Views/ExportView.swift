import SwiftUI
import SwiftData
import StoreKit

struct ExportView: View {

    private enum ProductID {
        static let proYearly = "landledger.pro.annual"
        static let taxExportPass = "landledger.tax_export_pass"
        static let all = [proYearly, taxExportPass]
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Property.name) private var properties: [Property]

    @State private var selectedYear = Calendar.current.component(.year, from: Date())
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {

                Spacer()

                Image(systemName: "doc.richtext")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                VStack(spacing: 20) {
                    Text("Generate Tax Report")
                        .font(.title2.bold())

                    Text("Creates a Schedule E summary PDF for all properties, ready to hand to your accountant.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tax Year")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Picker("Tax Year", selection: $selectedYear) {
                            ForEach(availableYears, id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if !properties.isEmpty {
                        reportPreview
                    }

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
                            Label(exportButtonTitle, systemImage: hasExportAccess ? "doc.badge.plus" : "lock.open")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isGenerating || properties.isEmpty)

                    if properties.isEmpty {
                        Text("Add at least one property in Settings first.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if !hasExportAccess {
                        Text("Export is included with LandLedger Pro or a one-time Tax Export Pass.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle("Export")
            .task {
                await refreshPurchases()
                await loadProductsIfNeeded()
            }
            .sheet(isPresented: $showPaywall) {
                paywallView
            }
            .sheet(isPresented: $showShare) {
                if let data = pdfData {
                    ShareSheetView(data: data, filename: "LandLedger_\(selectedYear).pdf")
                }
            }
        }
    }

    private var exportButtonTitle: String {
        hasExportAccess ? "Generate \(selectedYear) Report" : "Unlock Tax Export"
    }

    private var reportPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What's included")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            ForEach(properties) { property in
                let count = transactionCount(for: property, year: selectedYear)
                HStack {
                    Text(property.name)
                        .font(.caption)
                    Spacer()
                    Text("\(count) transaction\(count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
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
            Text("Create the LandLedger Pro yearly subscription and Tax Export Pass products in App Store Connect, then try again.")
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

    private func generatePDF() {
        isGenerating = true
        DispatchQueue.global(qos: .userInitiated).async {
            let data = PDFExporter.buildPDF(properties: properties, year: selectedYear)
            DispatchQueue.main.async {
                pdfData = data
                isGenerating = false
                showShare = true
            }
        }
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
