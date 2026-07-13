import SwiftUI

/// Central state for the onboarding flow. Passed as an EnvironmentObject.
@Observable
final class OnboardingCoordinator {

    enum Step: Int, CaseIterable {
        case welcome
        case goal
        case painPoints
        case socialProof
        case tinderCards
        case solution
        case propertyCount
        case processing
        case demo
        case valueDelivery
        case paywall
    }

    var step: Step = .welcome
    var isComplete = false

    // User responses
    var selectedGoal: String = ""
    var selectedPains: Set<String> = []
    var tinderAgreements: [Bool] = []
    var propertyCountLabel: String = ""

    // Demo state
    var demoMatchedCount = 0

    func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else {
            finish()
            return
        }
        withAnimation(.easeInOut(duration: 0.35)) {
            step = next
        }
    }

    func finish() {
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
        withAnimation {
            isComplete = true
        }
    }

    var progress: Double {
        Double(step.rawValue + 1) / Double(Step.allCases.count)
    }
}
