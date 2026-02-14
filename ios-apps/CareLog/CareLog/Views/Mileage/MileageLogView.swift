import SwiftUI
import SwiftData

struct MileageLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MileageEntry.date, order: .reverse) private var entries: [MileageEntry]
    @Query(filter: #Predicate<Patient> { !$0.isArchived },
           sort: \Patient.firstName) private var patients: [Patient]
    @State private var showAddEntry = false
    
    private var thisMonthMiles: Double {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        return entries.filter { $0.date >= startOfMonth }.reduce(0) { $0 + $1.miles }
    }
    
    private var thisYearMiles: Double {
        let calendar = Calendar.current
        let startOfYear = calendar.dateInterval(of: .year, for: Date())?.start ?? Date()
        return entries.filter { $0.date >= startOfYear }.reduce(0) { $0 + $1.miles }
    }
    
    private var thisYearDeduction: Double {
        thisYearMiles * MileageEntry.irsRate
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary card
                summaryCard
                
                List {
                    if entries.isEmpty {
                        Text("No mileage entries yet. Tap + to add your first trip.")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(entries) { entry in
                            MileageRow(entry: entry)
                        }
                        .onDelete(perform: deleteEntries)
                    }
                }
            }
            .navigationTitle("Mileage")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddEntry) {
                AddMileageView(patients: patients)
            }
        }
    }
    
    private var summaryCard: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text(String(format: "%.0f", thisMonthMiles))
                    .font(.title2.bold())
                    .foregroundColor(AppTheme.primary)
                Text("Miles This Month")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            Divider().frame(height: 40)
            
            VStack(spacing: 4) {
                Text(String(format: "%.0f", thisYearMiles))
                    .font(.title2.bold())
                    .foregroundColor(AppTheme.primary)
                Text("Miles This Year")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            Divider().frame(height: 40)
            
            VStack(spacing: 4) {
                Text(String(format: "$%.0f", thisYearDeduction))
                    .font(.title2.bold())
                    .foregroundColor(AppTheme.accent)
                Text("Tax Deduction")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    private func deleteEntries(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(entries[index])
        }
        try? modelContext.save()
    }
}

struct MileageRow: View {
    let entry: MileageEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.purpose)
                    .font(.subheadline.bold())
                HStack {
                    if let patient = entry.patient {
                        Circle()
                            .fill(patient.color)
                            .frame(width: 8, height: 8)
                        Text(patient.firstName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("·")
                            .foregroundColor(.secondary)
                    }
                    Text(entry.dateString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "%.1f mi", entry.miles))
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.primary)
                Text(String(format: "$%.2f", entry.deductionAmount))
                    .font(.caption)
                    .foregroundColor(AppTheme.accent)
            }
        }
    }
}

// MARK: - Add Mileage Entry
struct AddMileageView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let patients: [Patient]
    
    @State private var selectedPatient: Patient?
    @State private var startOdometer = ""
    @State private var endOdometer = ""
    @State private var purpose = ""
    @State private var notes = ""
    @State private var date = Date()
    
    let commonPurposes = ["Patient Visit", "Pharmacy Pickup", "Medical Supply Run", "Doctor Appointment", "Lab/Testing", "Home Health Office"]
    
    var calculatedMiles: Double {
        guard let start = Double(startOdometer), let end = Double(endOdometer), end > start else { return 0 }
        return end - start
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    
                    if !patients.isEmpty {
                        Picker("Patient", selection: $selectedPatient) {
                            Text("General / No Patient").tag(nil as Patient?)
                            ForEach(patients) { patient in
                                Text(patient.firstName).tag(patient as Patient?)
                            }
                        }
                    }
                }
                
                Section("Odometer") {
                    HStack {
                        TextField("Start", text: $startOdometer)
                            .keyboardType(.decimalPad)
                        Text("→")
                            .foregroundColor(.secondary)
                        TextField("End", text: $endOdometer)
                            .keyboardType(.decimalPad)
                    }
                    
                    if calculatedMiles > 0 {
                        HStack {
                            Text("Trip Distance")
                            Spacer()
                            Text(String(format: "%.1f miles", calculatedMiles))
                                .foregroundColor(AppTheme.primary)
                                .bold()
                        }
                        HStack {
                            Text("Deduction")
                            Spacer()
                            Text(String(format: "$%.2f", calculatedMiles * MileageEntry.irsRate))
                                .foregroundColor(AppTheme.accent)
                                .bold()
                        }
                    }
                }
                
                Section("Purpose") {
                    TextField("Trip purpose", text: $purpose)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(commonPurposes, id: \.self) { p in
                            Button(p) {
                                purpose = p
                            }
                            .buttonStyle(.bordered)
                            .tint(purpose == p ? AppTheme.primary : .secondary)
                            .controlSize(.small)
                        }
                    }
                }
                
                Section("Notes") {
                    TextField("Optional notes...", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("New Mileage Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .bold()
                        .disabled(calculatedMiles <= 0 || purpose.isEmpty)
                }
            }
        }
    }
    
    private func save() {
        let entry = MileageEntry(
            patient: selectedPatient,
            startOdometer: Double(startOdometer) ?? 0,
            endOdometer: Double(endOdometer) ?? 0,
            purpose: purpose
        )
        entry.date = date
        entry.notes = notes
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
    }
}
