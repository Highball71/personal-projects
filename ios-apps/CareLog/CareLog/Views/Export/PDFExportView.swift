import SwiftUI
import SwiftData

struct PDFExportView: View {
    @Environment(\.dismiss) private var dismiss
    let patient: Patient
    let date: Date
    let entries: [CareEntry]
    
    @State private var pdfData: Data?
    @State private var showShareSheet = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Preview header
                VStack(spacing: 8) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 50))
                        .foregroundColor(AppTheme.primary)
                    
                    Text("Daily Summary")
                        .font(.title2.bold())
                    
                    Text("\(patient.firstName) — \(date, format: .dateTime.month().day().year())")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(entries.count) entries")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 30)
                
                // Entry summary
                VStack(alignment: .leading, spacing: 8) {
                    let grouped = Dictionary(grouping: entries) { $0.entryType }
                    ForEach(EntryType.allCases.filter { grouped[$0] != nil }) { type in
                        if let count = grouped[type]?.count {
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundColor(type.color)
                                    .frame(width: 24)
                                Text(type.rawValue)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(count)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
                
                // Export buttons
                VStack(spacing: 12) {
                    Button {
                        generateAndShare()
                    } label: {
                        Label("Share PDF", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.primary)
                            .cornerRadius(12)
                    }
                    
                    Text("Share via iMessage, Email, AirDrop, or save to Files")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let data = pdfData {
                    ShareSheet(activityItems: [data])
                }
            }
        }
    }
    
    private func generateAndShare() {
        let shifts = patient.shifts.filter {
            Calendar.current.isDate($0.startTime, inSameDayAs: date)
        }
        pdfData = PDFGenerator.generateDailySummary(
            patient: patient,
            date: date,
            entries: entries,
            shifts: shifts
        )
        showShareSheet = true
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
