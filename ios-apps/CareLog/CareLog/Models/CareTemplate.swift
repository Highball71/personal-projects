import SwiftData
import Foundation

// A template defines a set of entry types that should be created together
// e.g., "Morning Routine" creates: vitals + meal (breakfast) + medication + mood
@Model
final class CareTemplate {
    var id: UUID
    var name: String
    var templateDescription: String
    var entryTypesRaw: [String] // EntryType rawValues to create
    var isBuiltIn: Bool
    var createdAt: Date
    var icon: String
    
    init(name: String, description: String, entryTypes: [EntryType], icon: String = "doc.text", isBuiltIn: Bool = false) {
        self.id = UUID()
        self.name = name
        self.templateDescription = description
        self.entryTypesRaw = entryTypes.map { $0.rawValue }
        self.isBuiltIn = isBuiltIn
        self.createdAt = Date()
        self.icon = icon
    }
    
    var entryTypes: [EntryType] {
        entryTypesRaw.compactMap { EntryType(rawValue: $0) }
    }
    
    // MARK: - Built-in Templates
    static func defaultTemplates() -> [CareTemplate] {
        [
            CareTemplate(
                name: "Morning Routine",
                description: "Vitals, breakfast, morning meds, mood check",
                entryTypes: [.vitals, .meal, .medication, .mood],
                icon: "sunrise.fill",
                isBuiltIn: true
            ),
            CareTemplate(
                name: "Medication Pass",
                description: "Medication administration with vitals",
                entryTypes: [.vitals, .medication],
                icon: "pill.fill",
                isBuiltIn: true
            ),
            CareTemplate(
                name: "Wound Care",
                description: "Wound assessment and care documentation",
                entryTypes: [.woundCare],
                icon: "bandage.fill",
                isBuiltIn: true
            ),
            CareTemplate(
                name: "Meal Documentation",
                description: "Meal intake and fluid tracking",
                entryTypes: [.meal],
                icon: "fork.knife",
                isBuiltIn: true
            ),
            CareTemplate(
                name: "Therapy Session",
                description: "PT/OT/Speech therapy documentation",
                entryTypes: [.therapy, .activity, .mood],
                icon: "hands.clap.fill",
                isBuiltIn: true
            ),
            CareTemplate(
                name: "Evening Check",
                description: "Evening vitals, dinner, mood, bowel/bladder",
                entryTypes: [.vitals, .meal, .mood, .bowelBladder],
                icon: "moon.fill",
                isBuiltIn: true
            ),
            CareTemplate(
                name: "Full Assessment",
                description: "Complete documentation: vitals, meal, meds, activity, mood, B&B",
                entryTypes: [.vitals, .meal, .medication, .activity, .mood, .bowelBladder],
                icon: "checklist",
                isBuiltIn: true
            )
        ]
    }
}
