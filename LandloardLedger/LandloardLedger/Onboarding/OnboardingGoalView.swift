import SwiftUI

struct OnboardingGoalView: View {

    @Environment(OnboardingCoordinator.self) private var coordinator

    private let goals: [(emoji: String, label: String)] = [
        ("🏠", "Knowing which tenant paid rent"),
        ("📊", "Tracking expenses by property"),
        ("🧾", "Getting ready for tax time"),
        ("💸", "Seeing where my money is going"),
        ("📁", "Keeping records in one place"),
        ("⏱", "Spending less time on bookkeeping"),
    ]

    var body: some View {
        OnboardingQuestionShell(
            headline: "What are you trying to\nstay on top of?",
            sub: "Pick the one that matters most right now."
        ) {
            VStack(spacing: 10) {
                ForEach(goals, id: \.label) { goal in
                    goalRow(goal)
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
            .disabled(coordinator.selectedGoal.isEmpty)
        }
    }

    private func goalRow(_ goal: (emoji: String, label: String)) -> some View {
        let isSelected = coordinator.selectedGoal == goal.label

        return Button {
            coordinator.selectedGoal = goal.label
        } label: {
            HStack(spacing: 14) {
                Text(goal.emoji)
                    .font(.title3)
                Text(goal.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isSelected ? .white : .primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
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
