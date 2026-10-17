import SwiftUI
import StoreKit

struct OnboardingPaywallView: View {

    @Environment(OnboardingCoordinator.self) private var coordinator

    private enum ProductID {
        static let proYearly = "landledger.pro.annual"
        static let taxExportPass = "landledger.tax_export_pass"
        static let all = [proYearly, taxExportPass]
    }

    @State private var products: [Product] = []
    @State private var isLoadingProducts = false
    @State private var isPurchasing = false
    @State private var purchasedProductIDs: Set<String> = []
    @State private var purchaseMessage: String?

    private var sortedProducts: [Product] {
        products.sorted { lhs, rhs in
            lhs.id == ProductID.proYearly ? true : false
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // Hero
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.brand.opacity(0.1))
                            .frame(width: 80, height: 80)
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.brand)
                    }
                    .padding(.top, 36)

                    Text("Your rental books, done")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text("LandLedger is free to use. Unlock tax export\nwhen you're ready to file.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                // Testimonial
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
                .padding(.bottom, 8)

                Text("\"Handed my accountant a clean PDF this year.\nHe actually complimented me.\"")
                    .font(.subheadline.italic())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("— James K., 3 rentals")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                    .padding(.bottom, 28)

                Divider().padding(.horizontal, 24)

                // Products
                VStack(spacing: 12) {
                    if isLoadingProducts {
                        ProgressView("Loading options…")
                            .padding(.vertical, 24)
                    } else if products.isEmpty {
                        fallbackProducts
                    } else {
                        ForEach(sortedProducts) { product in
                            productButton(product)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                if let purchaseMessage {
                    Text(purchaseMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }

                // Free continue
                Button {
                    coordinator.finish()
                } label: {
                    Text("Continue for free")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 16)

                Button("Restore Purchases") {
                    Task { await restorePurchases() }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
                .disabled(isPurchasing)

                Text("LandLedger is an organizational tool and does not provide tax, legal, or accounting advice.")
                    .font(.caption2)
                    .foregroundStyle(Color(.tertiaryLabel))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 20)
            }
        }
        .background(Color(.systemGroupedBackground))
        .task {
            await loadProducts()
            await refreshPurchases()
        }
    }

    // MARK: - Fallback (no StoreKit products loaded)

    private var fallbackProducts: some View {
        VStack(spacing: 12) {
            fallbackRow(
                icon: "crown.fill",
                title: "LandLedger Pro",
                detail: "Import, review, and export all year long",
                price: "$29.99/year",
                isPrimary: true
            ) {
                purchaseMessage = "Product loading — please try again."
            }
            fallbackRow(
                icon: "doc.badge.plus",
                title: "Tax Export Pass",
                detail: "Export this year's Schedule E PDF, once",
                price: "$9.99 one-time",
                isPrimary: false
            ) {
                purchaseMessage = "Product loading — please try again."
            }
        }
    }

    private func fallbackRow(icon: String, title: String, detail: String, price: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Color.brand)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(price).font(.headline).foregroundStyle(.primary)
            }
            .padding()
            .background(isPrimary ? Color.brand : Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isPrimary ? Color.clear : Color(.separator), lineWidth: 1)
            )
            .foregroundStyle(isPrimary ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Real StoreKit product button

    private func productButton(_ product: Product) -> some View {
        let isPrimary = product.id == ProductID.proYearly

        return Button {
            Task { await purchase(product) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isPrimary ? "crown.fill" : "doc.badge.plus")
                    .font(.title3)
                    .foregroundStyle(isPrimary ? .white : .brand)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(product.displayName)
                        .font(.headline)
                        .foregroundStyle(isPrimary ? .white : .primary)
                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(isPrimary ? .white.opacity(0.75) : .secondary)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.headline)
                    .foregroundStyle(isPrimary ? .white : .primary)
            }
            .padding()
            .background(isPrimary ? Color.brand : Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isPrimary ? Color.clear : Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
    }

    // MARK: - StoreKit helpers

    private func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        products = (try? await Product.products(for: ProductID.all)) ?? []
    }

    private func purchase(_ product: Product) async {
        isPurchasing = true
        purchaseMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let tx) = verification {
                    purchasedProductIDs.insert(tx.productID)
                    await tx.finish()
                    coordinator.finish()
                }
            case .userCancelled: break
            case .pending:
                purchaseMessage = "Purchase is pending approval."
            @unknown default: break
            }
        } catch {
            purchaseMessage = "Purchase failed. Please try again."
        }
    }

    private func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }
        try? await AppStore.sync()
        await refreshPurchases()
        if !purchasedProductIDs.isEmpty { coordinator.finish() }
        else { purchaseMessage = "No purchase found to restore." }
    }

    private func refreshPurchases() async {
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               ProductID.all.contains(tx.productID) {
                purchasedProductIDs.insert(tx.productID)
            }
        }
        if !purchasedProductIDs.isEmpty { coordinator.finish() }
    }
}
