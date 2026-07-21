import SwiftUI

struct OnboardingDemoView: View {

    @Environment(OnboardingCoordinator.self) private var coordinator

    private struct DemoTransaction {
        let description: String
        let amount: String
        let isIncome: Bool
        let hint: String
        let property: String
        let category: String
    }

    private let transactions = [
        DemoTransaction(
            description: "Zelle payment Sarah Chen",
            amount: "+$1,850",
            isIncome: true,
            hint: "Looks like rent — which property is Sarah in?",
            property: "Maple Ave Duplex",
            category: "Rent Income"
        ),
        DemoTransaction(
            description: "PG&E utility bill",
            amount: "-$134.22",
            isIncome: false,
            hint: "Utility expense — assign it to a property.",
            property: "Maple Ave Duplex",
            category: "Utilities"
        ),
        DemoTransaction(
            description: "ACH credit David Park rent",
            amount: "+$1,600",
            isIncome: true,
            hint: "Another rent payment — which property?",
            property: "Pine Street Cottage",
            category: "Rent Income"
        ),
    ]

    @State private var currentIndex = 0
    @State private var matchedTransactions: [(DemoTransaction, String, String)] = []
    @State private var showingOptions = false
    @State private var slideOffset: CGFloat = 0

    private var isDone: Bool { currentIndex >= transactions.count }
    private var remaining: Int { transactions.count - currentIndex }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("You just imported a\nbank statement")
                    .font(.title2.bold())
                Text(isDone ? "All matched! Tap below to see your ledger." : "These \(transactions.count) transactions need a home. Tap each one to match it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .animation(.easeInOut, value: isDone)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 36)
            .padding(.bottom, 24)

            // Progress pill
            if !isDone {
                Text(remaining == transactions.count ? "Match \(remaining) transactions" : remaining == 1 ? "Match 1 more" : "Match \(remaining) more")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.brand, in: Capsule())
                    .padding(.bottom, 20)
            }

            Spacer()

            if isDone {
                doneCard
            } else {
                transactionCard
            }

            Spacer()

            if isDone {
                Button {
                    coordinator.advance()
                } label: {
                    Label("See your ledger", systemImage: "arrow.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brand)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var transactionCard: some View {
        let tx = transactions[currentIndex]

        return VStack(spacing: 16) {
            // Transaction row
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tx.description)
                            .font(.headline)
                        Text("June 3, 2026")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(tx.amount)
                        .font(.title3.bold())
                        .foregroundStyle(tx.isIncome ? .green : .red)
                }

                Divider()

                Text(tx.hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Assign button
                Button {
                    assignTransaction(tx)
                } label: {
                    HStack {
                        Image(systemName: "building.2")
                        Text("Assign to \(tx.property)")
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.brand, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .shadow(color: Color.brand.opacity(0.24), radius: 8, y: 3)
            }
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
            .offset(x: slideOffset)
        }
        .padding(.horizontal, 24)
        .id(currentIndex)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    private var doneCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("3 transactions matched")
                .font(.title3.bold())
            Text("That's what RentalKeeper does for every import — automatically.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private func assignTransaction(_ tx: DemoTransaction) {
        withAnimation(.easeInOut(duration: 0.3)) {
            matchedTransactions.append((tx, tx.property, tx.category))
            coordinator.demoMatchedCount += 1
            currentIndex += 1
        }
    }
}
