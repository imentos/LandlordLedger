import SwiftUI

struct OnboardingPainPointsView: View {

    @Environment(OnboardingCoordinator.self) private var coordinator

    private let pains: [(emoji: String, label: String)] = [
        ("😤", "I can't tell which Zelle is from which tenant"),
        ("🗂", "My expenses are scattered across statements"),
        ("📅", "Tax time is a scramble every year"),
        ("📋", "I'm stuck copy-pasting into a spreadsheet"),
        ("🏚", "I mix up costs between properties"),
        ("🔒", "I don't trust financial apps with my bank login"),
        ("🤷", "I'm never sure what counts as a deduction"),
    ]

    var body: some View {
        OnboardingQuestionShell(
            headline: "What makes it a\nheadache right now?",
            sub: "Pick everything that applies."
        ) {
            VStack(spacing: 10) {
                ForEach(pains, id: \.label) { pain in
                    painRow(pain)
                }
            }
            .padding(.horizontal, 24)
        } footer: {
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
        }
    }

    private func painRow(_ pain: (emoji: String, label: String)) -> some View {
        let isSelected = coordinator.selectedPains.contains(pain.label)

        return Button {
            if isSelected {
                coordinator.selectedPains.remove(pain.label)
            } else {
                coordinator.selectedPains.insert(pain.label)
            }
        } label: {
            HStack(spacing: 14) {
                Text(pain.emoji)
                    .font(.title3)
                Text(pain.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? .white : Color(.tertiaryLabel))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? Color.brand : Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
