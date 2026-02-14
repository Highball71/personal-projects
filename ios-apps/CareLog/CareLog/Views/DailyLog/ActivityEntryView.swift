import SwiftUI
import SwiftData

struct ActivityEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let patient: Patient
    
    @State private var description = ""
    @State private var durationMinutes = ""
    @State private var assistanceLevel = "Independent"
    @State private var notes = ""
    
    let assistanceLevels = ["Independent", "Supervised", "Minimal Assist", "Moderate Assist", "Maximum Assist", "Dependent"]
    
    // Common activities for quick tap
    let quickActivities = ["Walking", "Bathing", "Dressing", "Grooming", "Transfers", "Exercises", "Range of Motion", "Toileting", "Eating", "Reading", "TV/Music", "Social Visit", "Outdoor Time"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Quick Select") {
                    FlowLayout(spacing: 8) {
                        ForEach(quickActivities, id: \.self) { activity in
                            Button(activity) {
                                if description.isEmpty {
                                    description = activity
                                } else {
                                    description += ", \(activity)"
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(description.contains(activity) ? AppTheme.accent : .secondary)
                            .controlSize(.small)
                        }
                    }
                }
                
                Section("Activity Description") {
                    TextField("What activity was performed?", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Duration") {
                    HStack {
                        TextField("Minutes", text: $durationMinutes)
                            .keyboardType(.numberPad)
                        Text("minutes")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Section("Assistance Level") {
                    Picker("Level", selection: $assistanceLevel) {
                        ForEach(assistanceLevels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Notes") {
                    TextField("Additional notes...", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .bold()
                        .disabled(description.isEmpty)
                }
            }
        }
    }
    
    private func save() {
        let entry = CareEntry(patient: patient, entryType: .activity, noteText: notes)
        let activity = ActivityData(
            description: description,
            durationMinutes: Int(durationMinutes),
            assistanceLevel: assistanceLevel
        )
        entry.setActivity(activity)
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Flow Layout for Quick Select Tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }
        
        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}
