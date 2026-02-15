import SwiftUI
import SwiftData
import Foundation

@Model
final class Patient {
    var id: UUID
    var firstName: String
    var colorHex: String
    var createdAt: Date
    var isArchived: Bool
    
    @Relationship(deleteRule: .cascade, inverse: \CareEntry.patient)
    var entries: [CareEntry]
    
    @Relationship(deleteRule: .cascade, inverse: \Shift.patient)
    var shifts: [Shift]
    
    @Relationship(deleteRule: .cascade, inverse: \MileageEntry.patient)
    var mileageEntries: [MileageEntry]
    
    init(firstName: String, colorHex: String = "#4A90D9") {
        self.id = UUID()
        self.firstName = firstName
        self.colorHex = colorHex
        self.createdAt = Date()
        self.isArchived = false
        self.entries = []
        self.shifts = []
        self.mileageEntries = []
    }
    
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
    
    var todayEntries: [CareEntry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        return entries.filter { $0.timestamp >= startOfDay }
            .sorted { $0.timestamp < $1.timestamp }
    }
    
    func entries(for date: Date) -> [CareEntry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return entries.filter { $0.timestamp >= startOfDay && $0.timestamp < endOfDay }
            .sorted { $0.timestamp < $1.timestamp }
    }
}
