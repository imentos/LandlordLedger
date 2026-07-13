import SwiftUI

struct OnboardingPropertyCountView: View {

    @Environment(OnboardingCoordinator.self) private var coordinator

    private let options: [(emoji: String, label: String)] = [
        ("🏠", "Just 1"),
        ("🏘", "2–4"),
        ("🏢", "5–10"),
        ("🗂", "More than 10"),
    ]

    var body: some View {
        OnboardingQuestionShell(
            headline: "How many properties\ndo you manage?",
            sub: "We'll set up a demo that matches your situation."
        ) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(options, id: \.label) { option in
                    optionCard(option)
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
            .disabled(coordinator.propertyCountLabel.isEmpty)
        }
    }

    private func optionCard(_ option: (emoji: String, label: String)) -> some View {
        let isSelected = coordinator.propertyCountLabel == option.label

        return Button {
            coordinator.propertyCountLabel = option.label
        } label: {
            VStack(spacing: 10) {
                Text(option.emoji)
                    .font(.largeTitle)
                Text(option.label)
                    .font(.subheadline.bold())
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(isSelected ? Color.brand : Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
