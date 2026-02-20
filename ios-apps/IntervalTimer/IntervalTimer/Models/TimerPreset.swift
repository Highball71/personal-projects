import Foundation
import SwiftData

/// A saved interval timer configuration.
/// Built-in presets (Tabata, HIIT) are defined as static constants.
/// Custom presets are persisted with SwiftData.
@Model
final class TimerPreset {
    var name: String
    var workDuration: Int    // seconds
    var restDuration: Int    // seconds
    var rounds: Int
    var createdAt: Date

    init(name: String, workDuration: Int, restDuration: Int, rounds: Int) {
        self.name = name
        self.workDuration = workDuration
        self.restDuration = restDuration
        self.rounds = rounds
        self.createdAt = Date()
    }

    /// Formatted work duration for display (e.g. "0:20")
    var workDisplay: String {
        formatDuration(workDuration)
    }

    /// Formatted rest duration for display (e.g. "0:10")
    var restDisplay: String {
        formatDuration(restDuration)
    }

    /// Summary string like "20s/10s × 8"
    var summary: String {
        "\(workDuration)s/\(restDuration)s \u{00d7} \(rounds)"
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Built-in Presets

extension TimerPreset {
    /// Standard Tabata protocol: 20s work, 10s rest, 8 rounds
    static let tabata = TimerPreset(
        name: "Tabata",
        workDuration: 20,
        restDuration: 10,
        rounds: 8
    )

    /// High-Intensity Interval Training: 40s work, 20s rest, 6 rounds
    static let hiit = TimerPreset(
        name: "HIIT",
        workDuration: 40,
        restDuration: 20,
        rounds: 6
    )

    /// All built-in presets, shown at the top of the list
    static let builtInPresets: [TimerPreset] = [tabata, hiit]
}
