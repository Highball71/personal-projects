//
//  StateRegionMap.swift
//  FluffyList
//
//  US state → USRegion for the one-time "Use my location" region
//  prompt: reverse geocoding yields a state (CLPlacemark's
//  administrativeArea — usually the two-letter code, but full names
//  appear in some locales, so both are accepted), and this static
//  table names the growing region. Pure and unit-tested.
//
//  Judgment calls, revisit freely: the mountain states are split by
//  harvest character — MT/WY/CO with the Plains, UT/NV with the
//  Southwest, ID with the Pacific Northwest; AK joins the Pacific
//  Northwest (a short northern season is the closest cell we have).
//  HAWAII IS DELIBERATELY UNMAPPED — a tropical year fits none of
//  the eight cells honestly, so a Hawaiian falls back to the manual
//  picker rather than getting confidently wrong suggestions. Anything
//  outside the US is the caller's job to reject (country code check).
//

import Foundation

enum StateRegionMap {

    /// The region for a US state, given either the two-letter code
    /// ("NC") or the full name ("North Carolina"), case-insensitively.
    /// nil for Hawaii, territories, and anything unrecognized — the
    /// prompt then falls back to the manual picker.
    static func region(forState state: String) -> USRegion? {
        let trimmed = state.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.count == 2 {
            return regionsByCode[trimmed.uppercased()]
        }
        guard let code = codesByName[trimmed.lowercased()] else { return nil }
        return regionsByCode[code]
    }

    /// Code → region. Hawaii is absent on purpose (see header).
    private static let regionsByCode: [String: USRegion] = [
        // Northeast
        "CT": .northeast, "MA": .northeast, "ME": .northeast, "NH": .northeast,
        "NY": .northeast, "RI": .northeast, "VT": .northeast,
        // Mid-Atlantic
        "DC": .midAtlantic, "DE": .midAtlantic, "MD": .midAtlantic,
        "NJ": .midAtlantic, "PA": .midAtlantic, "VA": .midAtlantic, "WV": .midAtlantic,
        // Southeast
        "AL": .southeast, "AR": .southeast, "FL": .southeast, "GA": .southeast,
        "KY": .southeast, "LA": .southeast, "MS": .southeast, "NC": .southeast,
        "SC": .southeast, "TN": .southeast,
        // Midwest
        "IA": .midwest, "IL": .midwest, "IN": .midwest, "MI": .midwest,
        "MN": .midwest, "MO": .midwest, "OH": .midwest, "WI": .midwest,
        // Plains (incl. the eastern mountain states)
        "CO": .plains, "KS": .plains, "MT": .plains, "ND": .plains,
        "NE": .plains, "SD": .plains, "WY": .plains,
        // Southwest (incl. the Great Basin)
        "AZ": .southwest, "NM": .southwest, "NV": .southwest,
        "OK": .southwest, "TX": .southwest, "UT": .southwest,
        // Pacific Northwest
        "AK": .pacificNorthwest, "ID": .pacificNorthwest,
        "OR": .pacificNorthwest, "WA": .pacificNorthwest,
        // California
        "CA": .california,
    ]

    /// Lowercased full name → code, for locales where reverse
    /// geocoding spells the state out. Hawaii resolves to "HI", which
    /// the code table then (deliberately) misses.
    private static let codesByName: [String: String] = [
        "alabama": "AL", "alaska": "AK", "arizona": "AZ", "arkansas": "AR",
        "california": "CA", "colorado": "CO", "connecticut": "CT",
        "delaware": "DE", "district of columbia": "DC", "florida": "FL",
        "georgia": "GA", "hawaii": "HI", "idaho": "ID", "illinois": "IL",
        "indiana": "IN", "iowa": "IA", "kansas": "KS", "kentucky": "KY",
        "louisiana": "LA", "maine": "ME", "maryland": "MD",
        "massachusetts": "MA", "michigan": "MI", "minnesota": "MN",
        "mississippi": "MS", "missouri": "MO", "montana": "MT",
        "nebraska": "NE", "nevada": "NV", "new hampshire": "NH",
        "new jersey": "NJ", "new mexico": "NM", "new york": "NY",
        "north carolina": "NC", "north dakota": "ND", "ohio": "OH",
        "oklahoma": "OK", "oregon": "OR", "pennsylvania": "PA",
        "rhode island": "RI", "south carolina": "SC", "south dakota": "SD",
        "tennessee": "TN", "texas": "TX", "utah": "UT", "vermont": "VT",
        "virginia": "VA", "washington": "WA", "west virginia": "WV",
        "wisconsin": "WI", "wyoming": "WY",
    ]
}
