import SwiftUI
import SwiftData

struct PropertiesView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Property.name) private var properties: [Property]

    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if properties.isEmpty {
                    emptyState
                } else {
                    propertyList
                }
            }
            .navigationTitle("Properties")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                PropertyFormView(mode: .add)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "building.2")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("No properties yet")
                .font(.title2.bold())
            Text("Add your rental properties to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Add Property") {
                showAddSheet = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }

    // MARK: - Property list

    private var propertyList: some View {
        List {
            ForEach(propertyOwnerGroups, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.properties) { property in
                        NavigationLink {
                            PropertyDetailView(property: property)
                        } label: {
                            propertyRow(property)
                        }
                    }
                    .onDelete { offsets in
                        deleteProperties(offsets, in: group.properties)
                    }
                }
            }
        }
    }

    private var propertyOwnerGroups: [(title: String, properties: [Property])] {
        let grouped = Dictionary(grouping: properties) { property in
            let owner = property.ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
            return owner.isEmpty ? "Unassigned Owner" : owner
        }

        return grouped
            .map { title, properties in
                (title: title, properties: properties.sorted { $0.name < $1.name })
            }
            .sorted { lhs, rhs in
                if lhs.title == "Unassigned Owner" { return false }
                if rhs.title == "Unassigned Owner" { return true }
                return lhs.title < rhs.title
            }
    }

    private func propertyRow(_ property: Property) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(property.name)
                .font(.headline)

            if !property.address.isEmpty {
                iconText(property.address, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                staticChip(tenantCountText(for: property), systemImage: "person.2")
                if !property.mortgageAliasList.isEmpty {
                    staticChip("Mortgage", systemImage: "banknote")
                }
            }
        }
        .padding(.vertical, 5)
    }

    private func staticChip(_ title: String, systemImage: String) -> some View {
        iconText(title, systemImage: systemImage)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.10), in: Capsule())
    }

    private func iconText(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .imageScale(.small)
            Text(title)
        }
    }

    private func tenantCountText(for property: Property) -> String {
        let count = property.tenants.count
        return "\(count) tenant\(count == 1 ? "" : "s")"
    }

    private func deleteProperties(_ offsets: IndexSet, in visibleProperties: [Property]) {
        for index in offsets {
            modelContext.delete(visibleProperties[index])
        }
        try? modelContext.save()
    }
}

// MARK: - Property form (add / edit)

enum PropertyFormMode {
    case add
    case edit(Property)
}

struct PropertyFormView: View {

    let mode: PropertyFormMode

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name       = ""
    @State private var address    = ""
    @State private var ownerName  = ""
    @State private var keywords   = ""
    @State private var mortgageAliases = ""

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Property Details") {
                    TextField("Name (e.g. 123 Elm St)", text: $name)
                    TextField("Address (optional)", text: $address)
                    TextField("Owner / Portfolio (optional)", text: $ownerName)
                }

                Section {
                    TextField("Keywords (comma-separated)", text: $keywords)
                        .autocorrectionDisabled()
                } header: {
                    Text("Keywords")
                } footer: {
                    Text("Words in transaction descriptions that help match this property. Example: Elmwood, Apt 2, rental.")
                        .font(.caption)
                }

                Section {
                    TextField("Mortgage / lender aliases", text: $mortgageAliases)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                } footer: {
                    Text("Use bank or lender names from your transaction descriptions. Example: Rocket Mortgage, Chase Home Lending.")
                        .font(.caption)
                }
            }
            .navigationTitle(isEditing ? "Edit Property" : "Add Property")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if case .edit(let property) = mode {
                    name = property.name
                    address = property.address
                    ownerName = property.ownerName
                    keywords = property.keywords.joined(separator: ", ")
                    mortgageAliases = property.mortgageAliasList.joined(separator: ", ")
                }
            }
        }
    }

    private func save() {
        let parsedKeywords = keywords
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let parsedMortgageAliases = mortgageAliases
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        switch mode {
        case .add:
            let property = Property(name: name.trimmingCharacters(in: .whitespaces),
                                    address: address.trimmingCharacters(in: .whitespaces),
                                    ownerName: ownerName.trimmingCharacters(in: .whitespaces),
                                    keywords: parsedKeywords,
                                    mortgageAliases: parsedMortgageAliases)
            modelContext.insert(property)
        case .edit(let property):
            property.name            = name.trimmingCharacters(in: .whitespaces)
            property.address         = address.trimmingCharacters(in: .whitespaces)
            property.ownerName       = ownerName.trimmingCharacters(in: .whitespaces)
            property.keywords        = parsedKeywords
            property.mortgageAliases = parsedMortgageAliases
        }

        try? modelContext.save()
        dismiss()
    }
}
