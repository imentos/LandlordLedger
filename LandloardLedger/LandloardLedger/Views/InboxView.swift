import SwiftUI
import SwiftData

struct InboxView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Transaction> { !$0.approved },
           sort: \Transaction.date, order: .forward)
    private var pendingTransactions: [Transaction]

    @Query private var properties: [Property]
    @Query private var tenants: [Tenant]
    @Query private var matchingRules: [MatchingRule]

    @State private var viewModel = ImportViewModel()
    @State private var refreshMessage: String?
    @State private var isRefreshingMatches = false
    @State private var searchText = ""

    private var visibleTransactions: [Transaction] {
        let query = normalizedSearchText
        guard !query.isEmpty else { return pendingTransactions }

        return pendingTransactions.filter { transaction in
            searchableText(for: transaction).contains(query)
        }
    }

    private var normalizedSearchText: String {
        normalize(searchText)
    }

    var body: some View {
        NavigationStack {
            Group {
                if pendingTransactions.isEmpty {
                    emptyState
                } else {
                    transactionList
                }
            }
            .navigationTitle("Inbox")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Search transactions"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !pendingTransactions.isEmpty {
                        Text(searchText.isEmpty ? "\(pendingTransactions.count)" : "\(visibleTransactions.count)/\(pendingTransactions.count)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.orange, in: Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                Text("All caught up")
                    .font(.title2.bold())
                Text("No transactions need your review.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .padding(.top, 120)
        }
        .refreshable {
            await refreshMatches()
        }
    }

    // MARK: - Transaction list

    private var transactionList: some View {
        List {
            Section {
                if let refreshMessage {
                    Text(refreshMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowInsets(.init(top: 4, leading: 16, bottom: 2, trailing: 16))
                }

                Text("These transactions need your review. Tap each one to assign a property and category.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init(top: 4, leading: 16, bottom: 8, trailing: 16))
            }

            if visibleTransactions.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("No matches")
                            .font(.headline)
                        Text("Try searching a tenant, property, amount, date, or bank description.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .listRowBackground(Color.clear)
                }
            } else {
                ForEach(visibleTransactions) { tx in
                    InboxCardView(transaction: tx, properties: properties, tenants: tenants)
                        .listRowInsets(.init(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await refreshMatches()
        }
    }

    private func refreshMatches() async {
        guard !isRefreshingMatches else { return }
        isRefreshingMatches = true
        refreshMessage = nil

        do {
            let summary = try await viewModel.rerunMatching(
                properties: properties,
                tenants: tenants,
                matchingRules: matchingRules,
                modelContext: modelContext
            )
            refreshMessage = "Checked \(summary.totalChecked), updated \(summary.updated), auto-approved \(summary.autoApproved)."
        } catch {
            refreshMessage = "Refresh failed: \(error.localizedDescription)"
        }
        isRefreshingMatches = false
    }

    private func searchableText(for transaction: Transaction) -> String {
        let values = [
            transaction.descriptionText,
            transaction.category,
            transaction.property?.name,
            transaction.property?.address,
            transaction.tenant?.name,
            transaction.tenant?.unit.isEmpty == false ? "unit \(transaction.tenant?.unit ?? "")" : nil,
            decimalString(transaction.amount),
            currencyString(transaction.amount),
            transaction.date.formatted(date: .abbreviated, time: .omitted),
            transaction.date.formatted(.dateTime.month(.twoDigits).day(.twoDigits).year(.defaultDigits))
        ]
        return normalize(values.compactMap { $0 }.joined(separator: " "))
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9. ]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private func currencyString(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? decimalString(value)
    }
}
