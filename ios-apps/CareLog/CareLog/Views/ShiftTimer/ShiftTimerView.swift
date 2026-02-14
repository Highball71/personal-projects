import SwiftUI
import SwiftData

struct ShiftTimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Patient> { !$0.isArchived },
           sort: \Patient.firstName) private var patients: [Patient]
    @Query(sort: \Shift.startTime, order: .reverse) private var allShifts: [Shift]
    
    @State private var selectedPatient: Patient?
    @State private var showNoteAlert = false
    @State private var shiftNote = ""
    @State private var timer: Timer?
    @State private var elapsedTime: TimeInterval = 0
    
    private var activeShift: Shift? {
        allShifts.first(where: { $0.isActive })
    }
    
    private var recentShifts: [Shift] {
        Array(allShifts.filter { !$0.isActive }.prefix(20))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Active shift display
                activeShiftCard
                
                // History
                List {
                    if !recentShifts.isEmpty {
                        Section("Recent Shifts") {
                            ForEach(recentShifts) { shift in
                                ShiftRow(shift: shift)
                            }
                        }
                        
                        Section {
                            // Weekly summary
                            let weekShifts = shiftsThisWeek
                            let totalHours = weekShifts.reduce(0.0) { $0 + $1.durationDecimalHours }
                            HStack {
                                Text("This Week")
                                    .font(.subheadline.bold())
                                Spacer()
                                Text(String(format: "%.1f hrs", totalHours))
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Shifts")
            .onAppear { startTimerIfNeeded() }
            .onDisappear { timer?.invalidate() }
        }
    }
    
    // MARK: - Active Shift Card
    private var activeShiftCard: some View {
        VStack(spacing: 16) {
            if let shift = activeShift {
                // Active shift display
                VStack(spacing: 8) {
                    HStack {
                        Circle()
                            .fill(.green)
                            .frame(width: 10, height: 10)
                        Text("On Shift — \(shift.patient?.firstName ?? "Unknown")")
                            .font(.headline)
                    }
                    
                    Text(formatElapsed(elapsedTime))
                        .font(.system(size: 48, weight: .light, design: .monospaced))
                        .foregroundColor(AppTheme.primary)
                    
                    Text("Started: \(shift.startTime, format: .dateTime.hour().minute())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button {
                        clockOut(shift: shift)
                    } label: {
                        Label("Clock Out", systemImage: "stop.circle.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
            } else {
                // Clock in
                VStack(spacing: 12) {
                    Text("No Active Shift")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if patients.isEmpty {
                        Text("Add a patient first to start tracking shifts.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Patient", selection: $selectedPatient) {
                            Text("Select Patient").tag(nil as Patient?)
                            ForEach(patients) { patient in
                                Text(patient.firstName).tag(patient as Patient?)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        Button {
                            clockIn()
                        } label: {
                            Label("Clock In", systemImage: "play.circle.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(selectedPatient != nil ? AppTheme.accent : Color.gray)
                                .cornerRadius(12)
                        }
                        .disabled(selectedPatient == nil)
                        .padding(.horizontal)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    // MARK: - Actions
    private func clockIn() {
        guard let patient = selectedPatient else { return }
        let shift = Shift(patient: patient)
        modelContext.insert(shift)
        try? modelContext.save()
        startTimerIfNeeded()
    }
    
    private func clockOut(shift: Shift) {
        shift.clockOut()
        try? modelContext.save()
        timer?.invalidate()
        timer = nil
        elapsedTime = 0
    }
    
    private func startTimerIfNeeded() {
        guard let shift = activeShift else { return }
        elapsedTime = Date().timeIntervalSince(shift.startTime)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime = Date().timeIntervalSince(shift.startTime)
        }
    }
    
    private func formatElapsed(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private var shiftsThisWeek: [Shift] {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return allShifts.filter { $0.startTime >= startOfWeek && !$0.isActive }
    }
}

struct ShiftRow: View {
    let shift: Shift
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    if let patient = shift.patient {
                        Circle()
                            .fill(patient.color)
                            .frame(width: 10, height: 10)
                        Text(patient.firstName)
                            .font(.subheadline.bold())
                    }
                }
                Text(shift.timeRangeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 3) {
                Text(shift.durationString)
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.primary)
                Text(shift.dateString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
