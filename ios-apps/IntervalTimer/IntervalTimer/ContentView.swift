import SwiftUI
import SwiftData

/// Root view — shows built-in and saved presets.
/// Tap a preset to start a workout, or create a custom one.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TimerPreset.createdAt) private var savedPresets: [TimerPreset]

    @State private var showingNewPreset = false
    @State private var editingPreset: TimerPreset?
    @State private var activeWorkoutPreset: TimerPreset?

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Built-in Presets
                Section("Built-in") {
                    ForEach(TimerPreset.builtInPresets, id: \.name) { preset in
                        PresetRow(preset: preset) {
                            activeWorkoutPreset = preset
                        }
                    }
                }

                // MARK: - Custom Presets
                Section("My Presets") {
                    if savedPresets.isEmpty {
                        Text("No custom presets yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(savedPresets) { preset in
                            PresetRow(preset: preset) {
                                activeWorkoutPreset = preset
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    modelContext.delete(preset)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    editingPreset = preset
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Interval Timer")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewPreset = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewPreset) {
                PresetEditView(mode: .create)
            }
            .sheet(item: $editingPreset) { preset in
                PresetEditView(mode: .edit(preset))
            }
            .fullScreenCover(item: $activeWorkoutPreset) { preset in
                TimerView(
                    workDuration: preset.workDuration,
                    restDuration: preset.restDuration,
                    rounds: preset.rounds
                )
            }
        }
    }
}

// MARK: - Preset Row

/// A single row displaying a preset's name and configuration summary.
private struct PresetRow: View {
    let preset: TimerPreset
    let onStart: () -> Void

    var body: some View {
        Button(action: onStart) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.name)
                        .font(.headline)
                    Text(preset.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TimerPreset.self, inMemory: true)
}
