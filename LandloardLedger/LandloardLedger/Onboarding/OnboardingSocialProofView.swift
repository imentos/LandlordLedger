import SwiftUI

struct OnboardingSocialProofView: View {

    @Environment(OnboardingCoordinator.self) private var coordinator

    private struct Testimonial {
        let quote: String
        let name: String
        let persona: String
        let headline: String
    }

    private let testimonials = [
        Testimonial(
            quote: "I used to spend 20 minutes every month matching Zelle payments. Now I import the CSV and it's already done.",
            name: "Maria T.",
            persona: "2-unit duplex owner",
            headline: "Finally know who paid"
        ),
        Testimonial(
            quote: "I handed my accountant a clean PDF this year. He actually complimented me. That's never happened before.",
            name: "James K.",
            persona: "3 rentals",
            headline: "Tax time used to ruin my January"
        ),
        Testimonial(
            quote: "I tried every finance app. They all wanted my bank login. RentalKeeper doesn't. That's why I stayed.",
            name: "Sandra L.",
            persona: "Single rental",
            headline: "My bank data stays on my phone"
        ),
    ]

    var body: some View {
        OnboardingQuestionShell(
            headline: "Small landlords are using\nit every month",
            sub: "No accountant required."
        ) {
            VStack(spacing: 14) {
                ForEach(testimonials, id: \.name) { t in
                    testimonialCard(t)
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

    private func testimonialCard(_ t: Testimonial) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
            }
            Text("\u{201C}\(t.headline)\u{201D}")
                .font(.subheadline.bold())
            Text(t.quote)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.brand.opacity(0.15))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(String(t.name.prefix(1)))
                            .font(.caption.bold())
                            .foregroundStyle(Color.brand)
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text(t.name)
                        .font(.caption.bold())
                    Text(t.persona)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
