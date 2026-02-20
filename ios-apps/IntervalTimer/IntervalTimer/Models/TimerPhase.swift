import SwiftUI

/// Represents the current phase of a workout interval timer.
enum TimerPhase: Equatable {
    case countdown   // Initial 3-second countdown before first work phase
    case work
    case rest
    case done

    var displayName: String {
        switch self {
        case .countdown: "GET READY"
        case .work: "WORK"
        case .rest: "REST"
        case .done: "DONE"
        }
    }

    /// Background color for each phase — bold for work, calm for rest
    var color: Color {
        switch self {
        case .countdown: Color.indigo
        case .work: Color.red
        case .rest: Color.teal
        case .done: Color.green
        }
    }
}
