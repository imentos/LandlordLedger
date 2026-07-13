import SwiftUI

struct OnboardingContainerView: View {

    @State private var coordinator = OnboardingCoordinator()

    var body: some View {
        ZStack(alignment: .top) {
            // Screen content
            Group {
                switch coordinator.step {
                case .welcome:       OnboardingWelcomeView()
                case .goal:          OnboardingGoalView()
                case .painPoints:    OnboardingPainPointsView()
                case .socialProof:   OnboardingSocialProofView()
                case .tinderCards:   OnboardingTinderView()
                case .solution:      OnboardingSolutionView()
                case .propertyCount: OnboardingPropertyCountView()
                case .processing:    OnboardingProcessingView()
                case .demo:          OnboardingDemoView()
                case .valueDelivery: OnboardingValueDeliveryView()
                case .paywall:       OnboardingPaywallView()
                }
            }
            .environment(coordinator)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .id(coordinator.step)

            // Progress bar (hidden on welcome)
            if coordinator.step != .welcome {
                ProgressView(value: coordinator.progress)
                    .tint(Color(hex: "#1B3A5C"))
                    .animation(.easeInOut, value: coordinator.progress)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: coordinator.step)
    }
}

// MARK: - Shared helpers

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

extension Color {
    static let brand = Color(hex: "#1B3A5C")
}
