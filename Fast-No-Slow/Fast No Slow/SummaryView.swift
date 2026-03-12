import SwiftUI

// Post-workout summary. Shows time in zone, zone compliance %,
// cadence compliance %, and basic run stats. Nothing else new.
struct SummaryView: View {
    @ObservedObject var workoutManager: WorkoutManager
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Workout Summary")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 40)

            Spacer()

            // Compliance cards
            VStack(spacing: 16) {
                summaryRow(
                    label: "Time in Zone",
                    value: formatTime(workoutManager.timeInZone),
                    icon: "heart.fill",
                    color: .green
                )

                summaryRow(
                    label: "Zone Compliance",
                    value: zoneComplianceText,
                    icon: "percent",
                    color: zoneComplianceColor
                )

                summaryRow(
                    label: "Cadence Compliance",
                    value: cadenceComplianceText,
                    icon: "figure.run",
                    color: cadenceComplianceColor
                )
            }

            // Basic stats
            VStack(spacing: 16) {
                summaryRow(
                    label: "Total Time",
                    value: formatTime(workoutManager.elapsedTime),
                    icon: "clock",
                    color: .blue
                )

                summaryRow(
                    label: "Total Distance",
                    value: formatDistance(workoutManager.totalDistance),
                    icon: "map",
                    color: .blue
                )
            }

            Spacer()

            Button(action: onDismiss) {
                Text("Done")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(16)
            }
            .padding(.bottom, 30)
        }
        .padding()
    }

    // MARK: - Compliance Calculations

    private var zoneCompliancePercent: Double {
        guard workoutManager.elapsedTime > 0 else { return 0 }
        return (workoutManager.timeInZone / workoutManager.elapsedTime) * 100
    }

    private var zoneComplianceText: String {
        String(format: "%.0f%%", zoneCompliancePercent)
    }

    private var zoneComplianceColor: Color {
        zoneCompliancePercent >= 80 ? .green : zoneCompliancePercent >= 50 ? .yellow : .red
    }

    private var cadenceCompliancePercent: Double {
        guard workoutManager.elapsedTime > 0 else { return 0 }
        return (workoutManager.timeOnCadence / workoutManager.elapsedTime) * 100
    }

    private var cadenceComplianceText: String {
        String(format: "%.0f%%", cadenceCompliancePercent)
    }

    private var cadenceComplianceColor: Color {
        cadenceCompliancePercent >= 80 ? .green : cadenceCompliancePercent >= 50 ? .yellow : .red
    }

    // MARK: - Row

    private func summaryRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 36)
            Text(label)
                .font(.headline)
            Spacer()
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }

    // MARK: - Formatters

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatDistance(_ meters: Double) -> String {
        let miles = meters * 0.000621371
        return String(format: "%.2f mi", miles)
    }
}
