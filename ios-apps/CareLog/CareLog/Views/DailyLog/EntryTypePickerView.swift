import SwiftUI

struct EntryTypePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let patient: Patient
    @State private var selectedType: EntryType?
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(EntryType.allCases) { type in
                        Button {
                            selectedType = type
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: type.icon)
                                    .font(.title2)
                                    .foregroundColor(type.color)
                                
                                Text(type.rawValue)
                                    .font(.caption.bold())
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 90)
                            .background(type.color.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $selectedType) { type in
                entryForm(for: type)
            }
        }
    }
    
    @ViewBuilder
    private func entryForm(for type: EntryType) -> some View {
        switch type {
        case .vitals:
            VitalsEntryView(patient: patient)
        case .meal:
            MealEntryView(patient: patient)
        case .medication:
            MedEntryView(patient: patient)
        case .activity:
            ActivityEntryView(patient: patient)
        case .mood:
            MoodEntryView(patient: patient)
        case .bowelBladder:
            BowelBladderEntryView(patient: patient)
        case .note, .woundCare, .therapy:
            NoteEntryView(patient: patient, entryType: type)
        }
    }
}
