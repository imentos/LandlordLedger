import SwiftUI

struct OnboardingWelcomeView: View {

    @Environment(OnboardingCoordinator.self) private var coordinator

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // App icon / hero
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.brand.gradient)
                    .frame(width: 100, height: 100)
                    .shadow(color: Color.brand.opacity(0.4), radius: 20, y: 8)

                Image(systemName: "building.2.crop.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 36)

            // Headline
            Text("Your rental books,\nfinally sorted")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .padding(.bottom, 16)

            // Sub
            Text("Import a bank CSV. Match rent to tenants.\nExport your Schedule E. Everything stays on your phone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // CTA
            Button {
                coordinator.advance()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brand)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
