import SwiftUI
import SwiftData

/// Form for creating or editing a custom interval preset.
/// Provides steppers for work/rest durations and round count.
struct PresetEditView: View {
    enum Mode: Identifiable {
        case create
        case edit(TimerPreset)

        var id: String {
            switch self {
            case .create: "create"
            case .edit(let preset): preset.name
            }
        }
    }

    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var workDuration: Int = 30
    @State private var restDuration: Int = 15
    @State private var rounds: Int = 6

    /// Whether to immediately start a workout after saving
    @State private var startAfterSave = false
    @State private var activeWorkout = false

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Preset Name") {
                    TextField("e.g. My HIIT", text: $name)
                }

                Section("Work Phase") {
                    Stepper(
                        "\(formatDuration(workDuration))",
                        value: $workDuration,
                        in: 5...300,
                        step: 5
                    )
                    .font(.title3.monospacedDigit())
                }

                Section("Rest Phase") {
                    Stepper(
                        "\(formatDuration(restDuration))",
                        value: $restDuration,
                        in: 5...300,
                        step: 5
                    )
                    .font(.title3.monospacedDigit())
                }

                Section("Rounds") {
                    Stepper(
                        "\(rounds) rounds",
                        value: $rounds,
                        in: 1...50
                    )
                    .font(.title3.monospacedDigit())
                }

                // Summary of total workout time
                Section {
                    let totalSeconds = (workDuration + restDuration) * rounds - restDuration
                    HStack {
                        Text("Total workout time")
                        Spacer()
                        Text(formatDuration(totalSeconds))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Preset" : "New Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Save") {
                        savePreset()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                loadExistingValues()
            }
        }
    }

    private func loadExistingValues() {
        if case .edit(let preset) = mode {
            name = preset.name
            workDuration = preset.workDuration
            restDuration = preset.restDuration
            rounds = preset.rounds
        }
    }

    private func savePreset() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        if case .edit(let preset) = mode {
            // Update existing preset
            preset.name = trimmedName
            preset.workDuration = workDuration
            preset.restDuration = restDuration
            preset.rounds = rounds
        } else {
            // Create new preset
            let preset = TimerPreset(
                name: trimmedName,
                workDuration: workDuration,
                restDuration: restDuration,
                rounds: rounds
            )
            modelContext.insert(preset)
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview("Create") {
    PresetEditView(mode: .create)
        .modelContainer(for: TimerPreset.self, inMemory: true)
}
