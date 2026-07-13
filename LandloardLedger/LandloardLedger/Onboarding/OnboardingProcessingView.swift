import SwiftUI

struct OnboardingProcessingView: View {

    @Environment(OnboardingCoordinator.self) private var coordinator

    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.brand.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.brand)
                    .rotationEffect(.degrees(rotation))
                    .scaleEffect(scale)
            }

            VStack(spacing: 10) {
                Text("Setting up your rental ledger…")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)

                if !coordinator.propertyCountLabel.isEmpty {
                    Text("Configuring for \(coordinator.propertyCountLabel) \(coordinator.propertyCountLabel == "Just 1" ? "property" : "properties")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) {
                opacity = 1
                scale = 1
            }
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                coordinator.advance()
            }
        }
    }
}
