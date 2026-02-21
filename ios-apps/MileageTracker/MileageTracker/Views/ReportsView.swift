import SwiftUI
import SwiftData

/// Generate quarterly and annual IRS-compliant mileage reports as PDFs.
/// Reports include trip-by-trip detail, totals, deductions, and expenses.
struct ReportsView: View {
    @Query(sort: \Trip.date) private var trips: [Trip]
    @Query private var settings: [YearlySettings]
    @Query(sort: \OdometerSnapshot.date) private var snapshots: [OdometerSnapshot]

    @State private var selectedReport: ReportType = .annual
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedQuarter = currentQuarter()
    @State private var generatedPDF: Data?
    @State private var showingShareSheet = false

    enum ReportType: String, CaseIterable {
        case annual = "Annual"
        case q1 = "Q1 (Jan–Mar)"
        case q2 = "Q2 (Apr–Jun)"
        case q3 = "Q3 (Jul–Sep)"
        case q4 = "Q4 (Oct–Dec)"
    }

    private var irsRate: Double {
        settings.first { $0.year == selectedYear }?.irsRate ?? 0.725
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Report Period") {
                    Picker("Year", selection: $selectedYear) {
                        ForEach(availableYears, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }

                    Picker("Report Type", selection: $selectedReport) {
                        ForEach(ReportType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }

                Section("Preview") {
                    let filtered = filteredTrips
                    let businessMiles = filtered.filter(\.isBusiness).reduce(0.0) { $0 + $1.miles }
                    let personalMiles = filtered.filter { !$0.isBusiness }.reduce(0.0) { $0 + $1.miles }
                    let deduction = businessMiles * irsRate

                    LabeledContent("Total Trips", value: "\(filtered.count)")
                    LabeledContent("Business Miles", value: String(format: "%.1f", businessMiles))
                    LabeledContent("Personal Miles", value: String(format: "%.1f", personalMiles))
                    LabeledContent("Mileage Deduction", value: String(format: "$%.2f", deduction))
                }

                Section {
                    Button {
                        generateReport()
                    } label: {
                        Label("Generate PDF Report", systemImage: "doc.text.fill")
                    }
                    .disabled(filteredTrips.isEmpty)
                }
            }
            .navigationTitle("Reports")
            .sheet(isPresented: $showingShareSheet) {
                if let pdf = generatedPDF {
                    ShareSheet(items: [pdf])
                }
            }
        }
    }

    // MARK: - Filtering

    private var availableYears: [Int] {
        let years = Set(trips.map { Calendar.current.component(.year, from: $0.date) })
        let current = Calendar.current.component(.year, from: Date())
        return Array(years.union([current])).sorted(by: >)
    }

    private var filteredTrips: [Trip] {
        let yearTrips = trips.filter {
            Calendar.current.component(.year, from: $0.date) == selectedYear && $0.isComplete
        }

        switch selectedReport {
        case .annual: return yearTrips
        case .q1: return yearTrips.filter { monthOf($0.date) >= 1 && monthOf($0.date) <= 3 }
        case .q2: return yearTrips.filter { monthOf($0.date) >= 4 && monthOf($0.date) <= 6 }
        case .q3: return yearTrips.filter { monthOf($0.date) >= 7 && monthOf($0.date) <= 9 }
        case .q4: return yearTrips.filter { monthOf($0.date) >= 10 && monthOf($0.date) <= 12 }
        }
    }

    private func monthOf(_ date: Date) -> Int {
        Calendar.current.component(.month, from: date)
    }

    private static func currentQuarter() -> ReportType {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 1...3: return .q1
        case 4...6: return .q2
        case 7...9: return .q3
        default: return .q4
        }
    }

    // MARK: - PDF Generation

    private func generateReport() {
        let title: String
        let dateRange: String
        let yearStr = String(selectedYear)

        switch selectedReport {
        case .annual:
            title = "Annual Mileage Report — \(yearStr)"
            dateRange = "January 1 – December 31, \(yearStr)"
        case .q1:
            title = "Q1 Mileage Report — \(yearStr)"
            dateRange = "January 1 – March 31, \(yearStr)"
        case .q2:
            title = "Q2 Mileage Report — \(yearStr)"
            dateRange = "April 1 – June 30, \(yearStr)"
        case .q3:
            title = "Q3 Mileage Report — \(yearStr)"
            dateRange = "July 1 – September 30, \(yearStr)"
        case .q4:
            title = "Q4 Mileage Report — \(yearStr)"
            dateRange = "October 1 – December 31, \(yearStr)"
        }

        // Find odometer snapshots for this year
        let startSnapshot = snapshots.first {
            $0.year == selectedYear && $0.type == .startOfYear
        }
        let endSnapshot = snapshots.first {
            $0.year == selectedYear && $0.type == .endOfYear
        }

        generatedPDF = PDFReportGenerator.generateReport(
            trips: filteredTrips,
            title: title,
            dateRange: dateRange,
            irsRate: irsRate,
            odometerStart: startSnapshot?.reading,
            odometerEnd: endSnapshot?.reading
        )
        showingShareSheet = true
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
