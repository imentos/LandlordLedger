import SwiftUI

struct OnboardingSolutionView: View {

    @Environment(OnboardingCoordinator.self) private var coordinator

    private struct SolutionItem {
        let pain: String
        let fix: String
        let icon: String
    }

    private let items: [SolutionItem] = [
        SolutionItem(
            pain: "Can't match Zelle to tenant",
            fix: "Match rent to tenant automatically — every month, in seconds",
            icon: "person.crop.circle.badge.checkmark"
        ),
        SolutionItem(
            pain: "Mixing up costs between properties",
            fix: "Every expense tagged to the right property, no manual sorting",
            icon: "building.2.crop.circle"
        ),
        SolutionItem(
            pain: "Tax time is a scramble",
            fix: "Export a Schedule E-ready PDF in one tap — hand it straight to your accountant",
            icon: "doc.text.fill"
        ),
        SolutionItem(
            pain: "Don't trust apps with my bank login",
            fix: "No bank login, ever. Import a CSV. Everything stays on your phone.",
            icon: "lock.shield.fill"
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Here's exactly how\nLandLedger fixes that")
                            .font(.title2.bold())
                        Text("Everything you flagged, solved.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 36)

                    VStack(spacing: 14) {
                        ForEach(items, id: \.pain) { item in
                            solutionRow(item)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }

            Divider()

            Button {
                coordinator.advance()
            } label: {
                Text("Continue")
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
    }

    private func solutionRow(_ item: SolutionItem) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.brand.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: item.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.brand)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.pain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.fix)
                    .font(.subheadline.bold())
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
