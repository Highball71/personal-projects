import SwiftUI
import SwiftData

struct PatientDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let patient: Patient
    
    @State private var selectedDate = Date()
    @State private var showAddEntry = false
    @State private var showTemplateSelector = false
    @State private var showExport = false
    
    private var entriesForDate: [CareEntry] {
        patient.entries(for: selectedDate)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Date selector bar
            dateBar
            
            if entriesForDate.isEmpty {
                emptyDayState
            } else {
                entryList
            }
        }
        .navigationTitle(patient.firstName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button {
                        showAddEntry = true
                    } label: {
                        Label("New Entry", systemImage: "plus.circle")
                    }
                    
                    Button {
                        showTemplateSelector = true
                    } label: {
                        Label("From Template", systemImage: "doc.text")
                    }
                    
                    Divider()
                    
                    Button {
                        showExport = true
                    } label: {
                        Label("Export Day", systemImage: "square.and.arrow.up")
                    }
                    .disabled(entriesForDate.isEmpty)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddEntry) {
            EntryTypePickerView(patient: patient)
        }
        .sheet(isPresented: $showTemplateSelector) {
            TemplateSelectorView(patient: patient)
        }
        .sheet(isPresented: $showExport) {
            PDFExportView(patient: patient, date: selectedDate, entries: entriesForDate)
        }
    }
    
    // MARK: - Date Bar
    private var dateBar: some View {
        HStack {
            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                if Calendar.current.isDateInToday(selectedDate) {
                    Text("Today")
                        .font(.headline)
                } else if Calendar.current.isDateInYesterday(selectedDate) {
                    Text("Yesterday")
                        .font(.headline)
                } else {
                    Text(selectedDate, style: .date)
                        .font(.headline)
                }
                
                Text("\(entriesForDate.count) entr\(entriesForDate.count == 1 ? "y" : "ies")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .onTapGesture {
                selectedDate = Date() // Tap to return to today
            }
            
            Spacer()
            
            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
            .disabled(Calendar.current.isDateInToday(selectedDate))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    // MARK: - Entry List
    private var entryList: some View {
        List {
            ForEach(entriesForDate) { entry in
                NavigationLink {
                    EntryDetailView(entry: entry)
                } label: {
                    EntryRowView(entry: entry)
                }
            }
            .onDelete(perform: deleteEntries)
        }
    }
    
    private var emptyDayState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No entries yet")
                .font(.title3)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Button {
                    showAddEntry = true
                } label: {
                    Label("New Entry", systemImage: "plus.circle.fill")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)
                
                Button {
                    showTemplateSelector = true
                } label: {
                    Label("Template", systemImage: "doc.text.fill")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
    }
    
    private func deleteEntries(offsets: IndexSet) {
        let entriesToDelete = offsets.map { entriesForDate[$0] }
        for entry in entriesToDelete {
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }
}

// MARK: - Entry Row
struct EntryRowView: View {
    let entry: CareEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            Image(systemName: entry.entryType.icon)
                .font(.title3)
                .foregroundColor(entry.entryType.color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(entry.entryType.rawValue)
                        .font(.subheadline.bold())
                    
                    Spacer()
                    
                    Text(entry.timeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(entry.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                if !entry.photoData.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                            .font(.caption2)
                        Text("\(entry.photoData.count) photo\(entry.photoData.count == 1 ? "" : "s")")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
