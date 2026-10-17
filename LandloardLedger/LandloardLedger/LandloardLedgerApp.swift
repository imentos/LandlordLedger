//
//  LandloardLedgerApp.swift
//  LandloardLedger
//
//  Created by Kuo, Ray on 4/14/26.
//

import SwiftUI
import SwiftData

@main
struct LandloardLedgerApp: App {

    @AppStorage("onboardingComplete") private var onboardingComplete = false

    var body: some Scene {
        WindowGroup {
            if onboardingComplete {
                ContentView()
            } else {
                OnboardingContainerView()
            }
        }
        .modelContainer(for: [Property.self, Tenant.self, Transaction.self, TransactionAttachment.self, MatchingRule.self])
    }
}
