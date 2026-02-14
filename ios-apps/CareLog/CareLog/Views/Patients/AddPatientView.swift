import SwiftUI
import SwiftData

struct AddPatientView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var firstName = ""
    @State private var selectedColor = PatientColors.palette[0].hex
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Patient First Name") {
                    TextField("First name only", text: $firstName)
                        .textContentType(.givenName)
                        .autocorrectionDisabled()
                }
                
                Section("Color Label") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(PatientColors.palette, id: \.hex) { color in
                            Circle()
                                .fill(Color(hex: color.hex) ?? .blue)
                                .frame(width: 44, height: 44)
                                .overlay {
                                    if selectedColor == color.hex {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.white)
                                            .font(.headline)
                                    }
                                }
                                .onTapGesture {
                                    selectedColor = color.hex
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    Text("CareLog stores first names only — no SSN, insurance, or identifiable health records. All data stays on your device.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("New Patient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let patient = Patient(firstName: firstName.trimmingCharacters(in: .whitespaces), colorHex: selectedColor)
                        modelContext.insert(patient)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(firstName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
