import SwiftUI
import SwiftData

struct BowelBladderEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let patient: Patient
    
    @State private var bowelMovement = false
    @State private var bowelDescription = "Normal"
    @State private var urineOutput = "Normal"
    @State private var notes = ""
    
    let bowelDescriptions = ["Normal", "Loose", "Hard", "Diarrhea", "Constipated", "Tarry/Dark", "Blood-tinged"]
    let urineDescriptions = ["Normal", "Decreased", "Increased", "Concentrated/Dark", "Cloudy", "Incontinent - Small", "Incontinent - Large", "Catheter Output"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Bowel") {
                    Toggle("Bowel Movement", isOn: $bowelMovement)
                    
                    if bowelMovement {
                        Picker("Description", selection: $bowelDescription) {
                            ForEach(bowelDescriptions, id: \.self) { desc in
                                Text(desc).tag(desc)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                Section("Bladder / Urine") {
                    Picker("Urine Output", selection: $urineOutput) {
                        ForEach(urineDescriptions, id: \.self) { desc in
                            Text(desc).tag(desc)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Notes") {
                    TextField("Additional observations...", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Bowel / Bladder")
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
        let entry = CareEntry(patient: patient, entryType: .bowelBladder, noteText: "")
        let data = BowelBladderData(
            bowelMovement: bowelMovement,
            bowelDescription: bowelMovement ? bowelDescription : nil,
            urineOutput: urineOutput,
            notes: notes
        )
        entry.setBowelBladder(data)
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
    }
}
