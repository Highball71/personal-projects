import Foundation
import SwiftData

/// Categories for trip purposes — required by IRS for audit compliance.
enum TripCategory: String, Codable, CaseIterable, Identifiable {
    case patientCare = "Patient Care"
    case administrative = "Administrative"
    case supplyRun = "Supply Run"
    case continuingEducation = "Continuing Education"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .patientCare: return "heart.text.clipboard"
        case .administrative: return "building.2"
        case .supplyRun: return "shippingbox"
        case .continuingEducation: return "book"
        case .other: return "ellipsis.circle"
        }
    }
}

/// A single logged trip with all IRS-required fields.
/// Each trip captures start/end locations, odometer readings, purpose, and category.
@Model
final class Trip {
    var date: Date
    var startLocationName: String
    var startOdometer: Double
    var endLocationName: String
    var endOdometer: Double
    var businessPurpose: String
    var categoryRaw: String
    var isBusiness: Bool
    var tollAmount: Double
    var parkingAmount: Double
    var notes: String
    var isComplete: Bool

    /// Link to a saved location for the start point (optional)
    var startLocation: SavedLocation?
    /// Link to a saved location for the end point (optional)
    var endLocation: SavedLocation?

    init(
        date: Date = Date(),
        startLocationName: String = "",
        startOdometer: Double = 0,
        endLocationName: String = "",
        endOdometer: Double = 0,
        businessPurpose: String = "",
        category: TripCategory = .patientCare,
        isBusiness: Bool = true,
        tollAmount: Double = 0,
        parkingAmount: Double = 0,
        notes: String = "",
        isComplete: Bool = false
    ) {
        self.date = date
        self.startLocationName = startLocationName
        self.startOdometer = startOdometer
        self.endLocationName = endLocationName
        self.endOdometer = endOdometer
        self.businessPurpose = businessPurpose
        self.categoryRaw = category.rawValue
        self.isBusiness = isBusiness
        self.tollAmount = tollAmount
        self.parkingAmount = parkingAmount
        self.notes = notes
        self.isComplete = isComplete
    }

    // MARK: - Computed Properties

    var category: TripCategory {
        get { TripCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    /// Distance driven, calculated from odometer readings.
    var miles: Double {
        guard endOdometer > startOdometer else { return 0 }
        return endOdometer - startOdometer
    }

    /// IRS deduction for this trip at current year's rate.
    func deduction(at rate: Double) -> Double {
        guard isBusiness else { return 0 }
        return miles * rate
    }

    /// Total deductible expenses (mileage deduction + tolls + parking).
    func totalDeductible(at rate: Double) -> Double {
        deduction(at: rate) + (isBusiness ? tollAmount + parkingAmount : 0)
    }

    /// Short summary for list display.
    var summary: String {
        if miles > 0 {
            return String(format: "%.1f mi — %@", miles, businessPurpose.isEmpty ? category.rawValue : businessPurpose)
        }
        return "In progress..."
    }

    /// Formatted date for display.
    var dateString: String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}
