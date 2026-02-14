import SwiftUI
import SwiftData

struct TemplateSelectorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CareTemplate.name) private var templates: [CareTemplate]
    let patient: Patient
    
    @State private var selectedTemplate: CareTemplate?
    @State private var currentEntryIndex = 0
    @State private var createdCount = 0
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(templates) { template in
                    Button {
                        startTemplate(template)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: template.icon)
                                .font(.title2)
                                .foregroundColor(AppTheme.primary)
                                .frame(width: 36)
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(template.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(template.templateDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 6) {
                                    ForEach(template.entryTypes) { type in
                                        Label(type.rawValue, systemImage: type.icon)
                                            .font(.caption2)
                                            .foregroundColor(type.color)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Choose Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $selectedTemplate) { template in
                TemplateFlowView(patient: patient, template: template) {
                    dismiss()
                }
            }
        }
    }
    
    private func startTemplate(_ template: CareTemplate) {
        selectedTemplate = template
    }
}

// MARK: - Template Flow View
// Walks through each entry type in the template sequentially
struct TemplateFlowView: View {
    let patient: Patient
    let template: CareTemplate
    let onComplete: () -> Void
    
    @State private var currentIndex = 0
    @State private var completedCount = 0
    @Environment(\.dismiss) private var dismiss
    
    var currentType: EntryType? {
        guard currentIndex < template.entryTypes.count else { return nil }
        return template.entryTypes[currentIndex]
    }
    
    var body: some View {
        NavigationStack {
            if let type = currentType {
                VStack(spacing: 0) {
                    // Progress bar
                    ProgressView(value: Double(currentIndex), total: Double(template.entryTypes.count))
                        .tint(AppTheme.accent)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    Text("Step \(currentIndex + 1) of \(template.entryTypes.count): \(type.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    
                    // Show the appropriate entry form
                    entryView(for: type)
                }
            } else {
                // All done
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(AppTheme.accent)
                    
                    Text("Template Complete!")
                        .font(.title2.bold())
                    
                    Text("\(template.name) — \(completedCount) entries created")
                        .foregroundColor(.secondary)
                    
                    Button("Done") {
                        dismiss()
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.primary)
                }
            }
        }
    }
    
    @ViewBuilder
    private func entryView(for type: EntryType) -> some View {
        // Each form view will dismiss itself on save, which advances to next
        switch type {
        case .vitals:
            TemplateEntryWrapper(onSave: advanceToNext) {
                VitalsEntryView(patient: patient)
            }
        case .meal:
            TemplateEntryWrapper(onSave: advanceToNext) {
                MealEntryView(patient: patient)
            }
        case .medication:
            TemplateEntryWrapper(onSave: advanceToNext) {
                MedEntryView(patient: patient)
            }
        case .activity:
            TemplateEntryWrapper(onSave: advanceToNext) {
                ActivityEntryView(patient: patient)
            }
        case .mood:
            TemplateEntryWrapper(onSave: advanceToNext) {
                MoodEntryView(patient: patient)
            }
        case .bowelBladder:
            TemplateEntryWrapper(onSave: advanceToNext) {
                BowelBladderEntryView(patient: patient)
            }
        case .note, .woundCare, .therapy:
            TemplateEntryWrapper(onSave: advanceToNext) {
                NoteEntryView(patient: patient, entryType: type)
            }
        }
    }
    
    private func advanceToNext() {
        completedCount += 1
        currentIndex += 1
    }
}

// Wrapper that detects when an entry form dismisses (saves)
struct TemplateEntryWrapper<Content: View>: View {
    let onSave: () -> Void
    let content: () -> Content
    @State private var isPresented = true
    
    var body: some View {
        content()
            .onDisappear {
                // When the entry form dismisses, advance
                onSave()
            }
    }
}
