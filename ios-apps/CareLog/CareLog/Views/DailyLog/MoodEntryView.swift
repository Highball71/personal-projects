import SwiftUI
import SwiftData

struct MoodEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let patient: Patient
    
    @State private var mood: MoodLevel = .good
    @State private var cooperative = true
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Mood / Behavior") {
                    Picker("Mood", selection: $mood) {
                        ForEach(MoodLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Toggle("Cooperative with Care", isOn: $cooperative)
                }
                
                Section("Observations") {
                    TextField("Behavioral observations, triggers, changes...", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
                
                Section("Quick Notes") {
                    let quickNotes = ["Calm and pleasant", "Sleeping well", "Restless", "Tearful", "Combative", "Oriented x3", "Confused to time", "Sundowning", "Verbal outbursts", "Repetitive questions"]
                    
                    FlowLayout(spacing: 8) {
                        ForEach(quickNotes, id: \.self) { note in
                            Button(note) {
                                if notes.isEmpty {
                                    notes = note
                                } else {
                                    notes += ". \(note)"
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
            .navigationTitle("Mood / Behavior")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .bold()
                }
            }
        }
    }
    
    private func save() {
        let entry = CareEntry(patient: patient, entryType: .mood, noteText: "")
        let moodData = MoodData(mood: mood, cooperative: cooperative, notes: notes)
        entry.setMood(moodData)
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
    }
}
