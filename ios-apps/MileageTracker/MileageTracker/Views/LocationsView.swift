import SwiftUI
import SwiftData

/// Manage saved locations — add, edit, delete frequent places.
/// These power the quick-pick buttons in the voice flow and voice name matching.
struct LocationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedLocation.usageCount, order: .reverse) private var locations: [SavedLocation]

    @State private var showingAddLocation = false
    @State private var editingLocation: SavedLocation?

    var body: some View {
        NavigationStack {
            List {
                if locations.isEmpty {
                    ContentUnavailableView(
                        "No Saved Locations",
                        systemImage: "mappin.slash",
                        description: Text("Add your frequent destinations for faster trip logging.")
                    )
                } else {
                    ForEach(locations) { location in
                        LocationRow(location: location)
                            .onTapGesture {
                                editingLocation = location
                            }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            modelContext.delete(locations[index])
                        }
                    }
                }
            }
            .navigationTitle("Locations")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddLocation = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddLocation) {
                AddLocationView()
            }
            .sheet(item: $editingLocation) { location in
                EditLocationView(location: location)
            }
        }
    }
}

// MARK: - Location Row

private struct LocationRow: View {
    let location: SavedLocation

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.headline)
                if !location.address.isEmpty {
                    Text(location.address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    if location.isFrequent {
                        Label("Frequent", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Text("Voice: \"\(location.voiceName)\"")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("\(location.usageCount) trips")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Add Location

private struct AddLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var shortName = ""
    @State private var address = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    TextField("Name (e.g., Joey's House)", text: $name)
                    TextField("Voice shortcut (e.g., Joey's)", text: $shortName)
                    TextField("Address (optional)", text: $address)
                }

                Section {
                    Text("The voice shortcut is what you say to select this location during trip logging.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let location = SavedLocation(
                            name: name,
                            shortName: shortName,
                            address: address
                        )
                        modelContext.insert(location)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Location

private struct EditLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var location: SavedLocation

    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    TextField("Name", text: $location.name)
                    TextField("Voice shortcut", text: $location.shortName)
                    TextField("Address", text: $location.address)
                }

                Section("Stats") {
                    HStack {
                        Text("Times used")
                        Spacer()
                        Text("\(location.usageCount)")
                            .foregroundStyle(.secondary)
                    }
                    Toggle("Frequent", isOn: $location.isFrequent)
                }
            }
            .navigationTitle("Edit Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
