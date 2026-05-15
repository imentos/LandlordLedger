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

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Property.self, Tenant.self, Transaction.self, MatchingRule.self])
    }
}
