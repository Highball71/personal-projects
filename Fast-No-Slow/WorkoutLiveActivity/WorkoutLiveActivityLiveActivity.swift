import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Attributes
// NOTE: Must match WorkoutActivityAttributes in the main app target exactly.
struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var heartRate: Int
        var zoneStatus: String   // "ON TRACK", "QUICK FEET", "LIGHTEN UP", "EASE EFFORT"
        var elapsedTime: TimeInterval
        var cadence: Int
        var isPaused: Bool
    }
    var targetLow: Int
    var targetHigh: Int
    var targetCadence: Int
}

// MARK: - Widget

struct WorkoutLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // Lock screen / StandBy / banner view
            VStack(alignment: .leading, spacing: 6) {
                // Header row
                HStack {
                    Label("Fast No Slow", systemImage: "heart.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(context.state.isPaused ? "PAUSED" : context.state.zoneStatus)
                        .font(.caption2.weight(.bold))
                        .foregroundColor(
                            context.state.isPaused
                                ? .orange
                                : zoneColor(for: context.state.zoneStatus)
                        )
                }

                // HR + elapsed time
                HStack(alignment: .firstTextBaseline) {
                    Text("\(context.state.heartRate)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("BPM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatElapsed(context.state.elapsedTime))
                        .font(.system(.title3, design: .monospaced).weight(.semibold))
                }

                // Cadence + zone targets
                HStack {
                    Label("\(context.state.cadence) SPM", systemImage: "figure.run")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Zone: \(context.attributes.targetLow)–\(context.attributes.targetHigh)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .activityBackgroundTint(Color.black.opacity(0.85))
            .activitySystemActionForegroundColor(Color.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .font(.caption2)
                            Text("\(context.state.heartRate)")
                                .font(.title2.bold())
                        }
                        Text("BPM")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(context.state.cadence)")
                            .font(.title2.bold())
                        Text("SPM")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.isPaused ? "PAUSED" : context.state.zoneStatus)
                            .font(.caption.bold())
                            .foregroundColor(
                                context.state.isPaused
                                    ? .orange
                                    : zoneColor(for: context.state.zoneStatus)
                            )
                        Spacer()
                        Text(formatElapsed(context.state.elapsedTime))
                            .font(.caption.monospacedDigit())
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.caption2)
                    Text("\(context.state.heartRate)")
                        .font(.caption2.bold())
                }
            } compactTrailing: {
                Text("\(context.state.cadence)")
                    .font(.caption2.bold())
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "heart.fill")
                    .foregroundColor(context.state.isPaused ? .orange : .red)
                    .font(.caption2)
            }
            .widgetURL(URL(string: "fastnoslowapp://"))
            .keylineTint(Color.red)
        }
    }

    private func zoneColor(for status: String) -> Color {
        switch status {
        case "ON TRACK":     return .green
        case "QUICK FEET":   return .orange
        case "LIGHTEN UP":   return .yellow
        case "EASE EFFORT":  return .red
        default:             return .blue
        }
    }

    private func formatElapsed(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Previews

extension WorkoutActivityAttributes {
    fileprivate static var preview: WorkoutActivityAttributes {
        WorkoutActivityAttributes(targetLow: 140, targetHigh: 165, targetCadence: 170)
    }
}

extension WorkoutActivityAttributes.ContentState {
    fileprivate static var running: WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            heartRate: 155, zoneStatus: "ON TRACK",
            elapsedTime: 1245, cadence: 172, isPaused: false
        )
    }
    fileprivate static var paused: WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            heartRate: 148, zoneStatus: "ON TRACK",
            elapsedTime: 1245, cadence: 0, isPaused: true
        )
    }
}

#Preview("Notification", as: .content, using: WorkoutActivityAttributes.preview) {
    WorkoutLiveActivityLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.running
    WorkoutActivityAttributes.ContentState.paused
}
