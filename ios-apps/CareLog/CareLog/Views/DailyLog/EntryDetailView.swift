import SwiftUI

struct EntryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let entry: CareEntry
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: entry.entryType.icon)
                        .font(.title2)
                        .foregroundColor(entry.entryType.color)
                    
                    VStack(alignment: .leading) {
                        Text(entry.entryType.rawValue)
                            .font(.title3.bold())
                        Text(entry.timestamp, format: .dateTime.month().day().year().hour().minute())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let template = entry.fromTemplate {
                        Label(template, systemImage: "doc.text")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(entry.entryType.color.opacity(0.1))
                .cornerRadius(12)
                
                // Content
                VStack(alignment: .leading, spacing: 12) {
                    Text(entry.summary)
                        .font(.body)
                    
                    if !entry.noteText.isEmpty && entry.entryType != .note && entry.entryType != .woundCare && entry.entryType != .therapy {
                        Divider()
                        Text("Notes")
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)
                        Text(entry.noteText)
                            .font(.body)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                
                // Photos
                if !entry.photoData.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Photos (\(entry.photoData.count))")
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)
                        
                        ForEach(entry.photoData.indices, id: \.self) { index in
                            if let image = UIImage(data: entry.photoData[index]) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle("Entry Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}
