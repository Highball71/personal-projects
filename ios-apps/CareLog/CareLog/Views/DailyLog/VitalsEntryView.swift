import SwiftUI
import SwiftData

struct VitalsEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let patient: Patient
    
    @State private var bpSystolic = ""
    @State private var bpDiastolic = ""
    @State private var pulse = ""
    @State private var temperature = ""
    @State private var o2Sat = ""
    @State private var weight = ""
    @State private var bloodSugar = ""
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Blood Pressure") {
                    HStack {
                        TextField("Systolic", text: $bpSystolic)
                            .keyboardType(.numberPad)
                        Text("/")
                            .foregroundColor(.secondary)
                        TextField("Diastolic", text: $bpDiastolic)
                            .keyboardType(.numberPad)
                        Text("mmHg")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Section("Heart Rate") {
                    HStack {
                        TextField("Pulse", text: $pulse)
                            .keyboardType(.numberPad)
                        Text("bpm")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Section("Temperature") {
                    HStack {
                        TextField("Temp", text: $temperature)
                            .keyboardType(.decimalPad)
                        Text("°F")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Section("Oxygen Saturation") {
                    HStack {
                        TextField("O₂ Sat", text: $o2Sat)
                            .keyboardType(.numberPad)
                        Text("%")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Section("Weight") {
                    HStack {
                        TextField("Weight", text: $weight)
                            .keyboardType(.decimalPad)
                        Text("lbs")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Section("Blood Sugar") {
                    HStack {
                        TextField("Blood Sugar", text: $bloodSugar)
                            .keyboardType(.numberPad)
                        Text("mg/dL")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Section("Notes") {
                    TextField("Additional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Vitals")
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
        let entry = CareEntry(patient: patient, entryType: .vitals, noteText: notes)
        
        var vitals = VitalsData()
        vitals.bpSystolic = Int(bpSystolic)
        vitals.bpDiastolic = Int(bpDiastolic)
        vitals.pulse = Int(pulse)
        vitals.temperature = Double(temperature)
        vitals.o2Saturation = Int(o2Sat)
        vitals.weight = Double(weight)
        vitals.bloodSugar = Int(bloodSugar)
        
        entry.setVitals(vitals)
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
    }
}
