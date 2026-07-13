import SwiftUI

struct OnboardingTinderView: View {

    @Environment(OnboardingCoordinator.self) private var coordinator

    private let cards = [
        "I know roughly what I made last year, but I couldn't tell you the exact number without digging through statements.",
        "Every time I get a Zelle notification I have to check who it's from and remember what unit they're in.",
        "My tax folder is just a pile of bank PDFs I hand to my accountant and hope for the best.",
        "I have a spreadsheet but I'm at least two months behind on entering things.",
    ]

    @State private var currentIndex = 0
    @State private var dragOffset: CGSize = .zero
    @State private var dragRotation: Double = 0

    private var isDone: Bool { currentIndex >= cards.count }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Do any of these\nsound familiar?")
                    .font(.title2.bold())
                Text("Swipe right if yes, left if no.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 36)
            .padding(.bottom, 24)

            Spacer()

            if isDone {
                doneState
            } else {
                cardStack
            }

            Spacer()

            // Hint row
            if !isDone {
                HStack {
                    Label("No", systemImage: "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                    Spacer()
                    Label("Yes", systemImage: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 48)
                .padding(.bottom, 8)
            }

            // Footer
            if isDone {
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
                .padding(.bottom, 48)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var cardStack: some View {
        ZStack {
            // Background cards (peek effect)
            ForEach((currentIndex + 1)..<min(currentIndex + 3, cards.count), id: \.self) { i in
                cardView(text: cards[i])
                    .scaleEffect(1.0 - Double(i - currentIndex) * 0.04)
                    .offset(y: Double(i - currentIndex) * 8)
                    .zIndex(Double(-i))
            }

            // Top card
            cardView(text: cards[currentIndex])
                .offset(dragOffset)
                .rotationEffect(.degrees(dragRotation))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                            dragRotation = Double(value.translation.width / 20)
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 80
                            if abs(value.translation.width) > threshold {
                                let direction: CGFloat = value.translation.width > 0 ? 1 : -1
                                withAnimation(.easeOut(duration: 0.25)) {
                                    dragOffset = CGSize(width: direction * 500, height: value.translation.height)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    coordinator.tinderAgreements.append(value.translation.width > 0)
                                    currentIndex += 1
                                    dragOffset = .zero
                                    dragRotation = 0
                                }
                            } else {
                                withAnimation(.spring) {
                                    dragOffset = .zero
                                    dragRotation = 0
                                }
                            }
                        }
                )
                .zIndex(1)
                .animation(.spring, value: dragOffset)
        }
        .frame(height: 240)
        .padding(.horizontal, 24)
    }

    private func cardView(text: String) -> some View {
        VStack {
            Text("\u{201C}\(text)\u{201D}")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.07), radius: 12, y: 4)
    }

    private var doneState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("We get it.")
                .font(.title3.bold())
            Text("Let's show you how RentalKeeper\nfixes all of that.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
