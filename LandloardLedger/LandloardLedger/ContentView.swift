import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            ImportView()
                .tabItem {
                    Label("Import", systemImage: "square.and.arrow.down")
                }

            InboxView()
                .tabItem {
                    Label("Inbox", systemImage: "tray")
                }

            PropertiesView()
                .tabItem {
                    Label("Properties", systemImage: "building.2")
                }

            ExportView()
                .tabItem {
                    Label("Export", systemImage: "doc.text")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Property.self, Tenant.self, Transaction.self, MatchingRule.self], inMemory: true)
}
