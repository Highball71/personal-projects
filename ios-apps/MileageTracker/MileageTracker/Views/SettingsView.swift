import SwiftUI
import SwiftData
import PhotosUI

/// App settings: IRS rate, reminders, odometer snapshots, and location management.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [YearlySettings]
    @Query(sort: \OdometerSnapshot.date, order: .reverse) private var snapshots: [OdometerSnapshot]

    @State private var showingOdometerCapture = false
    @State private var captureType: SnapshotType = .startOfYear

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private var currentSettings: YearlySettings? {
        settings.first { $0.year == currentYear }
    }

    var body: some View {
        NavigationStack {
            Form {
                // IRS Rate
                if let yearSettings = currentSettings {
                    Section("IRS Mileage Rate") {
                        HStack {
                            Text("\(currentYear) Rate")
                            Spacer()
                            TextField("Rate", value: Bindable(yearSettings).irsRate, format: .currency(code: "USD"))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        Text("The standard IRS mileage rate for business use. Updated annually by the IRS.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Daily Reminders
                    Section("Reminders") {
                        Toggle("Weekday Reminder", isOn: Bindable(yearSettings).reminderEnabled)
                        if yearSettings.reminderEnabled {
                            DatePicker(
                                "Reminder Time",
                                selection: Bindable(yearSettings).reminderDate,
                                displayedComponents: .hourAndMinute
                            )
                            .onChange(of: yearSettings.reminderDate) {
                                scheduleReminders(yearSettings)
                            }
                        }
                        Text("Get a nudge on weekdays if no trip has been logged.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .onChange(of: yearSettings.reminderEnabled) {
                        if yearSettings.reminderEnabled {
                            Task {
                                let granted = await NotificationService.requestPermission()
                                if granted {
                                    scheduleReminders(yearSettings)
                                } else {
                                    yearSettings.reminderEnabled = false
                                }
                            }
                        } else {
                            NotificationService.cancelReminders()
                        }
                    }
                }

                // Odometer Snapshots
                Section("Odometer Records") {
                    Button {
                        captureType = .startOfYear
                        showingOdometerCapture = true
                    } label: {
                        Label("Record Start-of-Year Odometer", systemImage: "camera")
                    }

                    Button {
                        captureType = .endOfYear
                        showingOdometerCapture = true
                    } label: {
                        Label("Record End-of-Year Odometer", systemImage: "camera")
                    }

                    if !snapshots.isEmpty {
                        ForEach(snapshots) { snapshot in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(snapshot.type.rawValue) \(snapshot.year)")
                                        .font(.subheadline.bold())
                                    Text(snapshot.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(snapshot.readingString)
                                    .font(.headline.monospacedDigit())
                                if snapshot.photo != nil {
                                    Image(systemName: "photo")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }

                    Text("The IRS recommends recording your odometer at the start and end of each year to document total vs. business miles.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // About
                Section("About") {
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("IRS Compliance", value: "2026 Rules")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingOdometerCapture) {
                OdometerCaptureView(snapshotType: captureType)
            }
        }
    }

    private func scheduleReminders(_ yearSettings: YearlySettings) {
        NotificationService.scheduleWeekdayReminders(
            hour: yearSettings.reminderHour,
            minute: yearSettings.reminderMinute
        )
    }
}

// MARK: - Odometer Capture

/// Simple view to enter an odometer reading and optionally take a photo.
struct OdometerCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let snapshotType: SnapshotType

    @State private var reading = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section("Odometer Reading") {
                    TextField("Enter reading", text: $reading)
                        .keyboardType(.numberPad)
                        .font(.title2.monospacedDigit())
                }

                Section("Photo (Optional)") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(
                            photoData != nil ? "Change Photo" : "Take or Choose Photo",
                            systemImage: "camera"
                        )
                    }
                    .onChange(of: selectedPhoto) {
                        Task {
                            if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                                photoData = data
                            }
                        }
                    }

                    if photoData != nil {
                        Text("Photo attached")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("\(snapshotType.rawValue) Odometer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let snapshot = OdometerSnapshot(
                            reading: Double(reading) ?? 0,
                            photo: photoData,
                            type: snapshotType
                        )
                        modelContext.insert(snapshot)
                        dismiss()
                    }
                    .disabled(reading.isEmpty)
                }
            }
        }
    }
}
