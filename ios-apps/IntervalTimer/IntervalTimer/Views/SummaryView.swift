import SwiftUI

/// Post-workout summary showing total time and rounds completed.
struct SummaryView: View {
    let totalTime: TimeInterval
    let roundsCompleted: Int
    let totalRounds: Int
    let workDuration: Int
    let restDuration: Int

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Celebration icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)

                Text("Workout Complete!")
                    .font(.largeTitle.weight(.bold))

                // Stats grid
                VStack(spacing: 20) {
                    StatRow(
                        icon: "clock.fill",
                        label: "Total Time",
                        value: formatTime(totalTime)
                    )
                    StatRow(
                        icon: "arrow.trianglehead.2.clockwise.rotate.90",
                        label: "Rounds",
                        value: "\(roundsCompleted) of \(totalRounds)"
                    )
                    StatRow(
                        icon: "flame.fill",
                        label: "Work",
                        value: "\(workDuration)s intervals"
                    )
                    StatRow(
                        icon: "leaf.fill",
                        label: "Rest",
                        value: "\(restDuration)s intervals"
                    )
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Stat Row

private struct StatRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.headline)
                .monospacedDigit()
        }
    }
}

#Preview {
    SummaryView(
        totalTime: 245,
        roundsCompleted: 8,
        totalRounds: 8,
        workDuration: 20,
        restDuration: 10
    )
}
