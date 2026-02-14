import SwiftUI
import SwiftData

struct PatientListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Patient> { !$0.isArchived },
           sort: \Patient.firstName) private var patients: [Patient]
    @State private var showAddPatient = false
    
    var body: some View {
        NavigationStack {
            Group {
                if patients.isEmpty {
                    emptyState
                } else {
                    patientList
                }
            }
            .navigationTitle("CareLog")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if patients.count < 10 {
                        Button {
                            showAddPatient = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddPatient) {
                AddPatientView()
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.clipboard")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.secondary)
            
            Text("Welcome to CareLog")
                .font(.title2.bold())
            
            Text("Add your first patient to start\ndocumenting daily care.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showAddPatient = true
            } label: {
                Label("Add Patient", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.primary)
        }
        .padding()
    }
    
    private var patientList: some View {
        List {
            ForEach(patients) { patient in
                NavigationLink {
                    PatientDetailView(patient: patient)
                } label: {
                    PatientRow(patient: patient)
                }
            }
            .onDelete(perform: archivePatients)
        }
    }
    
    private func archivePatients(offsets: IndexSet) {
        for index in offsets {
            patients[index].isArchived = true
        }
        try? modelContext.save()
    }
}

// MARK: - Patient Row
struct PatientRow: View {
    let patient: Patient
    
    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(patient.color)
                .frame(width: 44, height: 44)
                .overlay {
                    Text(String(patient.firstName.prefix(1)))
                        .font(.title3.bold())
                        .foregroundColor(.white)
                }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(patient.firstName)
                    .font(.headline)
                
                let count = patient.todayEntries.count
                Text(count == 0 ? "No entries today" : "\(count) entr\(count == 1 ? "y" : "ies") today")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Active shift indicator
            if patient.shifts.contains(where: { $0.isActive }) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("On Shift")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
