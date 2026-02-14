import SwiftUI
import SwiftData

struct MealEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let patient: Patient
    
    @State private var mealType: MealType = .lunch
    @State private var description = ""
    @State private var intake: IntakeAmount = .good
    @State private var fluidOz = ""
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Meal Type") {
                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("What Was Served") {
                    TextField("e.g., Scrambled eggs, toast, juice", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Intake Amount") {
                    Picker("Intake", selection: $intake) {
                        ForEach(IntakeAmount.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Fluids") {
                    HStack {
                        TextField("Fluid intake", text: $fluidOz)
                            .keyboardType(.numberPad)
                        Text("oz")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Section("Notes") {
                    TextField("Additional notes...", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .bold()
                        .disabled(description.isEmpty)
                }
            }
        }
    }
    
    private func save() {
        let entry = CareEntry(patient: patient, entryType: .meal, noteText: notes)
        let meal = MealData(
            mealType: mealType,
            description: description,
            intake: intake,
            fluidOz: Int(fluidOz)
        )
        entry.setMeal(meal)
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
    }
}
