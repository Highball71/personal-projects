import Foundation
import SwiftData

/// Type of odometer snapshot — taken at the beginning or end of a tax year.
enum SnapshotType: String, Codable {
    case startOfYear = "Start of Year"
    case endOfYear = "End of Year"
}

/// A photo of the odometer with a reading, used for IRS documentation.
/// The IRS recommends recording odometer at start and end of each tax year
/// to establish total miles driven vs. business miles.
@Model
final class OdometerSnapshot {
    var date: Date
    var reading: Double
    var photo: Data?
    var typeRaw: String
    var year: Int
    var notes: String

    init(
        date: Date = Date(),
        reading: Double = 0,
        photo: Data? = nil,
        type: SnapshotType = .startOfYear,
        year: Int = Calendar.current.component(.year, from: Date()),
        notes: String = ""
    ) {
        self.date = date
        self.reading = reading
        self.photo = photo
        self.typeRaw = type.rawValue
        self.year = year
        self.notes = notes
    }

    var type: SnapshotType {
        get { SnapshotType(rawValue: typeRaw) ?? .startOfYear }
        set { typeRaw = newValue.rawValue }
    }

    var readingString: String {
        String(format: "%.0f", reading)
    }
}
