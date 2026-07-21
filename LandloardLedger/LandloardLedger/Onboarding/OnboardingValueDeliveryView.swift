import SwiftUI

struct OnboardingValueDeliveryView: View {

    @Environment(OnboardingCoordinator.self) private var coordinator

    private struct LedgerRow {
        let name: String
        let property: String
        let amount: String
        let category: String
        let isIncome: Bool
    }

    private let rows: [LedgerRow] = [
        LedgerRow(name: "Sarah Chen", property: "Maple Ave Duplex", amount: "+$1,850", category: "Rent Income", isIncome: true),
        LedgerRow(name: "David Park", property: "Pine Street Cottage", amount: "+$1,600", category: "Rent Income", isIncome: true),
        LedgerRow(name: "PG&E", property: "Maple Ave Duplex", amount: "-$134.22", category: "Utilities", isIncome: false),
    ]

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your rent roll\nfor June")
                            .font(.title2.bold())
                        Text("3 transactions matched. Here's what your ledger looks like.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 36)

                    // Ledger card
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                            ledgerRow(row)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 16)
                                .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.12), value: appeared)

                            if index < rows.count - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }

                        Divider()

                        // Net income
                        HStack {
                            Text("Net income")
                                .font(.subheadline.bold())
                            Spacer()
                            Text("$3,315.78")
                                .font(.subheadline.bold())
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.45), value: appeared)
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)

                    // Share button
                    Button {
                        // Share sheet — just a demo hint
                    } label: {
                        Label("Share my rent roll", systemImage: "square.and.arrow.up")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.brand, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
                    .shadow(color: Color.brand.opacity(0.22), radius: 8, y: 3)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            }

            Divider()

            Button {
                coordinator.advance()
            } label: {
                Text("Unlock the full app")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brand)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appeared = true
            }
        }
    }

    private func ledgerRow(_ row: LedgerRow) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(row.isIncome ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: row.isIncome ? "arrow.down" : "arrow.up")
                        .font(.caption.bold())
                        .foregroundStyle(row.isIncome ? .green : .orange)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                    .font(.subheadline.bold())
                Text(row.property)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(row.amount)
                    .font(.subheadline.bold())
                    .foregroundStyle(row.isIncome ? .green : .red)
                Text(row.category)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
