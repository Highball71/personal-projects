import SwiftUI

struct WatchWorkoutView: View {
    @StateObject private var mirror = WorkoutMirror()

    var body: some View {
        Group {
            if mirror.isWorkoutActive {
                activeLayout
            } else {
                idleLayout
            }
        }
        .containerBackground(.black.gradient, for: .navigation)
    }

    // MARK: - Active Layout (during a run)

    private var activeLayout: some View {
        VStack(spacing: 6) {
            // Coaching banner
            Text(mirror.isPaused ? "PAUSED" : mirror.cueLabel)
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(bannerColor)
                .cornerRadius(6)

            // Heart rate — the hero number
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.footnote)
                Text("\(mirror.heartRate)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(bpmColor)
                    .contentTransition(.numericText())
            }

            // Zone range
            Text("\(mirror.zoneLow)–\(mirror.zoneHigh) bpm")
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer(minLength: 2)

            // Cadence (left) + elapsed time (right)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(mirror.cadence)")
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundColor(.white)
                    Text("SPM")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(format(mirror.elapsedTime))
                    .font(.footnote.monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 6)
    }

    // MARK: - Idle Layout (no active workout)

    private var idleLayout: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.run")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("Start a workout\non your iPhone")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Colors (mirrors the iPhone's color language)

    private var bannerColor: Color {
        if mirror.isPaused { return .orange }
        switch mirror.cueLabel {
        case "ON TRACK":    return .green
        case "PICK IT UP":  return .blue
        case "LIGHTEN UP":  return .yellow
        case "EASE EFFORT": return .red
        default:            return .gray
        }
    }

    private var bpmColor: Color {
        switch mirror.cueLabel {
        case "PICK IT UP":  return .blue
        case "LIGHTEN UP":  return .yellow
        case "EASE EFFORT": return .red
        default:            return .green
        }
    }

    private func format(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    WatchWorkoutView()
}
