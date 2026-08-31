//
//  SeasonalCalendar.swift
//  FluffyList
//
//  Seasonal Suggestions v1 (design settled 2026-08-30, built on the
//  seasonal-v1 branch): a bundled, curated calendar of US produce —
//  8 hand-drawn regions × 12 monthly periods, each entry flagged peak
//  or available. Deterministic and offline; the JSON in
//  Resources/SeasonalCalendar.json is the single source of truth and
//  the place to correct harvest timing.
//
//  The household's region is a device setting (@AppStorage
//  "seasonalRegion", raw USRegion value, "" = unset). No region set
//  means the whole feature is dormant — no DB column, no migration.
//

import Foundation
import os

/// The ~8 hand-drawn US regions the calendar is curated for —
/// deliberately not USDA zones (they measure winter cold, not harvest
/// timing) and not 50 states (uncuratable). Raw values are the JSON
/// region keys AND the stored setting value — never rename.
enum USRegion: String, CaseIterable, Identifiable, Codable {
    case northeast = "northeast"
    case midAtlantic = "mid_atlantic"
    case southeast = "southeast"
    case midwest = "midwest"
    case plains = "plains"
    case southwest = "southwest"
    case pacificNorthwest = "pacific_nw"
    case california = "california"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .northeast: return "Northeast"
        case .midAtlantic: return "Mid-Atlantic"
        case .southeast: return "Southeast"
        case .midwest: return "Midwest"
        case .plains: return "Plains"
        case .southwest: return "Southwest"
        case .pacificNorthwest: return "Pacific Northwest"
        case .california: return "California"
        }
    }
}

/// One region-month cell: produce at the height of local harvest
/// (peak) vs. honestly obtainable — shoulder seasons and storage
/// crops (available). Names are lowercase, singular keywords.
struct SeasonalProduce: Decodable, Equatable {
    let peak: [String]
    let available: [String]

    var isEmpty: Bool { peak.isEmpty && available.isEmpty }
}

/// The bundled calendar. Loaded once; a missing or malformed resource
/// logs and yields nil, which renders the feature dormant rather than
/// crashing (same posture as an unset region).
struct SeasonalCalendar: Decodable {
    /// region raw value → month ("1"–"12") → produce cell.
    let regions: [String: [String: SeasonalProduce]]

    private enum CodingKeys: String, CodingKey { case regions }

    /// The app-wide instance, decoded from the bundle at first use.
    static let shared: SeasonalCalendar? = load()

    static func load(bundle: Bundle = .main) -> SeasonalCalendar? {
        guard let url = bundle.url(forResource: "SeasonalCalendar", withExtension: "json") else {
            Logger.supabase.error("SeasonalCalendar: resource missing from bundle")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(SeasonalCalendar.self, from: data)
        } catch {
            Logger.supabase.error("SeasonalCalendar: failed to decode — \(error.localizedDescription)")
            return nil
        }
    }

    /// The produce cell for a region and calendar month (1–12).
    /// nil for an out-of-range month or a region the JSON lacks.
    func produce(for region: USRegion, month: Int) -> SeasonalProduce? {
        guard (1...12).contains(month) else { return nil }
        return regions[region.rawValue]?[String(month)]
    }
}
