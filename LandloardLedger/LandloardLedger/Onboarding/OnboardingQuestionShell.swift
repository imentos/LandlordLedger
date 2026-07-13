import SwiftUI

/// Reusable wrapper used by questionnaire-style screens.
struct OnboardingQuestionShell<Content: View, Footer: View>: View {

    let headline: String
    let sub: String
    @ViewBuilder let content: () -> Content
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(headline)
                            .font(.title2.bold())
                            .multilineTextAlignment(.leading)
                        Text(sub)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 36)

                    content()
                        .padding(.bottom, 24)
                }
            }

            Divider()

            footer()
                .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground))
    }
}
