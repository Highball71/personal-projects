import SwiftData
import Foundation

@Model
final class Shift {
    var id: UUID
    var patient: Patient?
    var startTime: Date
    var endTime: Date?
    var notes: String
    var isActive: Bool
    
    init(patient: Patient) {
        self.id = UUID()
        self.patient = patient
        self.startTime = Date()
        self.endTime = nil
        self.notes = ""
        self.isActive = true
    }
    
    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
    
    var durationString: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var durationDecimalHours: Double {
        duration / 3600.0
    }
    
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: startTime)
    }
    
    var timeRangeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let start = formatter.string(from: startTime)
        let end = endTime.map { formatter.string(from: $0) } ?? "Active"
        return "\(start) – \(end)"
    }
    
    func clockOut() {
        self.endTime = Date()
        self.isActive = false
    }
}
