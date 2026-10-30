//
//  DurationText.swift
//  FluffyList
//
//  How a recipe's total time reads everywhere it's shown: "45 min",
//  "1 hr", "1 hr 15 min", "12 hr 30 min". A slow-cooker recipe used to
//  read "750 min" (device pass 2026-10-29).
//

import Foundation

enum DurationText {
    /// Minutes under an hour stay minutes; an hour or more splits into
    /// hours plus any leftover minutes.
    nonisolated static func totalTime(minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) min" }
        let hours = minutes / 60
        let leftover = minutes % 60
        return leftover == 0 ? "\(hours) hr" : "\(hours) hr \(leftover) min"
    }
}
