import SwiftData
import Foundation

@Model
final class MileageEntry {
    var id: UUID
    var patient: Patient?
    var date: Date
    var startOdometer: Double
    var endOdometer: Double
    var purpose: String
    var notes: String
    
    init(patient: Patient? = nil, startOdometer: Double = 0, endOdometer: Double = 0, purpose: String = "") {
        self.id = UUID()
        self.patient = patient
        self.date = Date()
        self.startOdometer = startOdometer
        self.endOdometer = endOdometer
        self.purpose = purpose
        self.notes = ""
    }
    
    var miles: Double {
        max(0, endOdometer - startOdometer)
    }
    
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var summary: String {
        "\(String(format: "%.1f", miles)) mi — \(purpose)"
    }
    
    // 2025 IRS standard mileage rate for medical/business
    static let irsRate: Double = 0.70
    
    var deductionAmount: Double {
        miles * Self.irsRate
    }
}
