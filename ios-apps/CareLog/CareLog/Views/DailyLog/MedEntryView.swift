import SwiftUI
import SwiftData

struct MedEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let patient: Patient
    
    @State private var medName = ""
    @State private var dose = ""
    @State private var route = "Oral"
    @State private var given = true
    @State private var refusedReason = ""
    @State private var notes = ""
    
    let routes = ["Oral", "Topical", "Subcutaneous", "Intramuscular", "Inhaled", "Sublingual", "Rectal", "Transdermal", "Ophthalmic", "Otic", "Nasal"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    TextField("Medication name", text: $medName)
                        .autocorrectionDisabled()
                    TextField("Dose (e.g., 500mg, 10mL)", text: $dose)
                        .autocorrectionDisabled()
                }
                
                Section("Route") {
                    Picker("Route", selection: $route) {
                        ForEach(routes, id: \.self) { r in
                            Text(r).tag(r)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Administration") {
                    Toggle("Medication Given", isOn: $given)
                    
                    if !given {
                        TextField("Reason refused/held", text: $refusedReason, axis: .vertical)
                            .lineLimit(2...4)
                    }
                }
                
                Section("Notes") {
                    TextField("Additional notes...", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .bold()
                        .disabled(medName.isEmpty)
                }
            }
        }
    }
    
    private func save() {
        let entry = CareEntry(patient: patient, entryType: .medication, noteText: notes)
        let med = MedicationData(
            name: medName,
            dose: dose,
            route: route,
            given: given,
            refusedReason: given ? nil : refusedReason
        )
        entry.setMedication(med)
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
    }
}
