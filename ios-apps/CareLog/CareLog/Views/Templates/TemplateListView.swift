import SwiftUI
import SwiftData

struct TemplateListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CareTemplate.name) private var templates: [CareTemplate]
    @State private var showAddTemplate = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Built-In Templates") {
                    ForEach(templates.filter(\.isBuiltIn)) { template in
                        TemplateRow(template: template)
                    }
                }
                
                Section("Custom Templates") {
                    if templates.filter({ !$0.isBuiltIn }).isEmpty {
                        Text("No custom templates yet")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(templates.filter({ !$0.isBuiltIn })) { template in
                            TemplateRow(template: template)
                        }
                        .onDelete(perform: deleteCustomTemplates)
                    }
                }
            }
            .navigationTitle("Templates")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddTemplate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddTemplate) {
                AddTemplateView()
            }
        }
    }
    
    private func deleteCustomTemplates(offsets: IndexSet) {
        let custom = templates.filter { !$0.isBuiltIn }
        for index in offsets {
            modelContext.delete(custom[index])
        }
        try? modelContext.save()
    }
}

struct TemplateRow: View {
    let template: CareTemplate
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: template.icon)
                .font(.title3)
                .foregroundColor(AppTheme.primary)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(template.name)
                    .font(.subheadline.bold())
                
                Text(template.templateDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    ForEach(template.entryTypes) { type in
                        Image(systemName: type.icon)
                            .font(.caption2)
                            .foregroundColor(type.color)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Add Custom Template
struct AddTemplateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var description = ""
    @State private var selectedTypes: Set<EntryType> = []
    @State private var icon = "doc.text"
    
    let iconOptions = ["doc.text", "sunrise.fill", "moon.fill", "pill.fill", "heart.fill", "bandage.fill", "fork.knife", "figure.walk", "hands.clap.fill", "checklist", "star.fill", "house.fill"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Template Name") {
                    TextField("e.g., Evening Routine", text: $name)
                }
                
                Section("Description") {
                    TextField("Brief description...", text: $description)
                }
                
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(iconOptions, id: \.self) { iconName in
                            Image(systemName: iconName)
                                .font(.title3)
                                .frame(width: 40, height: 40)
                                .background(icon == iconName ? AppTheme.primary.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                                .onTapGesture {
                                    icon = iconName
                                }
                        }
                    }
                }
                
                Section("Entry Types (tap to select)") {
                    ForEach(EntryType.allCases) { type in
                        Button {
                            if selectedTypes.contains(type) {
                                selectedTypes.remove(type)
                            } else {
                                selectedTypes.insert(type)
                            }
                        } label: {
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundColor(type.color)
                                Text(type.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedTypes.contains(type) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppTheme.accent)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .bold()
                        .disabled(name.isEmpty || selectedTypes.isEmpty)
                }
            }
        }
    }
    
    private func save() {
        let template = CareTemplate(
            name: name,
            description: description,
            entryTypes: Array(selectedTypes),
            icon: icon,
            isBuiltIn: false
        )
        modelContext.insert(template)
        try? modelContext.save()
        dismiss()
    }
}
