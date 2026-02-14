import SwiftUI
import SwiftData

struct ExportSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Patient> { !$0.isArchived },
           sort: \Patient.firstName) private var patients: [Patient]
    @Query(sort: \MileageEntry.date, order: .reverse) private var mileageEntries: [MileageEntry]
    @Query(sort: \Shift.startTime, order: .reverse) private var shifts: [Shift]
    
    @State private var selectedPatient: Patient?
    @State private var exportStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @State private var exportEndDate = Date()
    @State private var showShareSheet = false
    @State private var exportData: Data?
    @State private var exportType: ExportType = .dailySummary
    
    enum ExportType: String, CaseIterable {
        case dailySummary = "Daily Summaries"
        case mileageReport = "Mileage Report"
        case shiftReport = "Shift Report"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Export Type") {
                    Picker("Type", selection: $exportType) {
                        ForEach(ExportType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                if exportType == .dailySummary {
                    Section("Patient") {
                        Picker("Patient", selection: $selectedPatient) {
                            Text("Select Patient").tag(nil as Patient?)
                            ForEach(patients) { patient in
                                Text(patient.firstName).tag(patient as Patient?)
                            }
                        }
                    }
                }
                
                Section("Date Range") {
                    DatePicker("From", selection: $exportStartDate, displayedComponents: .date)
                    DatePicker("To", selection: $exportEndDate, displayedComponents: .date)
                }
                
                Section {
                    Button {
                        generateExport()
                    } label: {
                        Label("Generate & Share PDF", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(exportType == .dailySummary && selectedPatient == nil)
                }
                
                // MARK: - App Info
                Section("About CareLog") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Data Storage")
                        Spacer()
                        Text("On Device Only")
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Privacy")
                            .font(.subheadline)
                        Text("CareLog stores all data locally on your device. No data is sent to any server. First names only — no SSN, insurance numbers, or identifiable health records are collected.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Data Management") {
                    NavigationLink("Archived Patients") {
                        ArchivedPatientsView()
                    }
                }
            }
            .navigationTitle("Export & Settings")
            .sheet(isPresented: $showShareSheet) {
                if let data = exportData {
                    ShareSheet(activityItems: [data])
                }
            }
        }
    }
    
    private func generateExport() {
        switch exportType {
        case .dailySummary:
            guard let patient = selectedPatient else { return }
            // Generate summary for today (could be enhanced to do a date range)
            let entries = patient.entries(for: exportEndDate)
            let dayShifts = patient.shifts.filter {
                Calendar.current.isDate($0.startTime, inSameDayAs: exportEndDate)
            }
            exportData = PDFGenerator.generateDailySummary(
                patient: patient,
                date: exportEndDate,
                entries: entries,
                shifts: dayShifts
            )
            
        case .mileageReport:
            let filtered = mileageEntries.filter { $0.date >= exportStartDate && $0.date <= exportEndDate }
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            let range = "\(formatter.string(from: exportStartDate)) – \(formatter.string(from: exportEndDate))"
            exportData = PDFGenerator.generateMileageReport(entries: filtered, dateRange: range)
            
        case .shiftReport:
            let filtered = shifts.filter { $0.startTime >= exportStartDate && $0.startTime <= exportEndDate && !$0.isActive }
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            let range = "\(formatter.string(from: exportStartDate)) – \(formatter.string(from: exportEndDate))"
            exportData = PDFGenerator.generateShiftReport(shifts: filtered, dateRange: range)
        }
        
        showShareSheet = true
    }
}

// MARK: - Archived Patients View
struct ArchivedPatientsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Patient> { $0.isArchived },
           sort: \Patient.firstName) private var archivedPatients: [Patient]
    
    var body: some View {
        List {
            if archivedPatients.isEmpty {
                Text("No archived patients")
                    .foregroundColor(.secondary)
            } else {
                ForEach(archivedPatients) { patient in
                    HStack {
                        Circle()
                            .fill(patient.color)
                            .frame(width: 30, height: 30)
                            .overlay {
                                Text(String(patient.firstName.prefix(1)))
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                            }
                        
                        Text(patient.firstName)
                        
                        Spacer()
                        
                        Button("Restore") {
                            patient.isArchived = false
                            try? modelContext.save()
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .navigationTitle("Archived Patients")
    }
}
