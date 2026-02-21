import Foundation
import SwiftData

/// A saved location the user visits frequently.
/// Short names enable voice recognition ("Joey's house" instead of full address).
/// Usage count tracks frequency so the app can suggest locations intelligently.
@Model
final class SavedLocation {
    var name: String
    var shortName: String
    var address: String
    var isFrequent: Bool
    var usageCount: Int
    var latitude: Double?
    var longitude: Double?
    var createdAt: Date

    /// Trips that started at this location
    @Relationship(deleteRule: .nullify, inverse: \Trip.startLocation)
    var tripsFrom: [Trip]

    /// Trips that ended at this location
    @Relationship(deleteRule: .nullify, inverse: \Trip.endLocation)
    var tripsTo: [Trip]

    init(
        name: String,
        shortName: String = "",
        address: String = "",
        isFrequent: Bool = false,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.name = name
        self.shortName = shortName.isEmpty ? name : shortName
        self.address = address
        self.isFrequent = isFrequent
        self.usageCount = 0
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = Date()
        self.tripsFrom = []
        self.tripsTo = []
    }

    /// The name the user says to select this location by voice.
    var voiceName: String {
        shortName.isEmpty ? name : shortName
    }

    /// Bump usage count when this location is used for a trip.
    func recordUsage() {
        usageCount += 1
        isFrequent = usageCount >= 3
    }

    // MARK: - Built-in Locations

    /// Seed locations for initial setup. User can customize these.
    static let defaultLocations: [SavedLocation] = [
        SavedLocation(name: "Home Office", shortName: "home", isFrequent: true),
        SavedLocation(name: "Pittsburgh Office", shortName: "Pittsburgh", isFrequent: true),
    ]
}
