import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            TransactionsView()
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet.rectangle")
                }

            PropertiesView()
                .tabItem {
                    Label("Properties", systemImage: "building.2")
                }

            ExportView()
                .tabItem {
                    Label("Reports", systemImage: "chart.bar")
                }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Property.self, Tenant.self, Transaction.self, MatchingRule.self], inMemory: true)
}
