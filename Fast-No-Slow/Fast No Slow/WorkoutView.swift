import SwiftUI

struct WorkoutView: View {
    @ObservedObject var workoutManager: WorkoutManager
    @Binding var isPresented: Bool
    @State private var isHoldingStop = false
    @State private var holdProgress: CGFloat = 0
    // Timer for long-press stop gesture
    @State private var holdTimer: Timer?

    var body: some View {
        // If workout is done, show summary
        if workoutManager.showSummary {
            SummaryView(workoutManager: workoutManager) {
                isPresented = false
            }
        } else {
            workoutContent
        }
    }

    private var workoutContent: some View {
        VStack(spacing: 0) {
            // HR monitor status pill
            hrMonitorPill

            // Status banner
            statusBanner

            ScrollView {
                VStack(spacing: 20) {
                    // Heart rate display with source icon
                    heartRateCard

                    // Cadence display
                    cadenceCard

                    // Time & Distance in zone
                    HStack(spacing: 16) {
                        statCard(
                            title: "Time in Zone",
                            value: formatTime(workoutManager.timeInZone),
                            icon: "timer",
                            color: .green
                        )
                        statCard(
                            title: "Zone Distance",
                            value: formatDistance(workoutManager.distanceInZone),
                            icon: "figure.walk",
                            color: .green
                        )
                    }

                    // Total stats
                    HStack(spacing: 16) {
                        statCard(
                            title: "Total Time",
                            value: formatTime(workoutManager.elapsedTime),
                            icon: "clock",
                            color: .blue
                        )
                        statCard(
                            title: "Total Distance",
                            value: formatDistance(workoutManager.totalDistance),
                            icon: "map",
                            color: .blue
                        )
                    }

                    // Elevation
                    HStack(spacing: 16) {
                        statCard(
                            title: "Elevation ↑",
                            value: formatElevation(workoutManager.elevationGain),
                            icon: "arrow.up.right",
                            color: .orange
                        )
                        statCard(
                            title: "Elevation ↓",
                            value: formatElevation(workoutManager.elevationLoss),
                            icon: "arrow.down.right",
                            color: .purple
                        )
                    }

                    // Stop button — requires hold to confirm
                    stopButton
                }
                .padding()
            }
        }
    }

    // MARK: - HR Monitor Pill
    private var hrMonitorPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(workoutManager.hrMonitorState == .connected ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            switch workoutManager.hrMonitorState {
            case .connected:
                Text(workoutManager.connectedDeviceName ?? "HR Monitor")
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
            case .searching:
                Text("Searching...")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            case .disconnected:
                Text("No Monitor")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    // MARK: - Status Banner
    private var statusBanner: some View {
        HStack {
            Image(systemName: statusIcon)
                .font(.title2)
            Text(workoutManager.zoneStatus.rawValue)
                .font(.title2)
                .fontWeight(.bold)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding()
        .background(statusColor)
        .animation(.easeInOut(duration: 0.3), value: workoutManager.zoneStatus)
    }

    private var statusColor: Color {
        switch workoutManager.zoneStatus {
        case .belowZone: return .blue
        case .inZone: return .green
        case .aboveZone: return .red
        }
    }

    private var statusIcon: String {
        switch workoutManager.zoneStatus {
        case .belowZone: return "hare"
        case .inZone: return "checkmark.circle.fill"
        case .aboveZone: return "tortoise"
        }
    }

    // MARK: - Heart Rate Card (with source icon)
    private var heartRateCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)
                .symbolEffect(.pulse, isActive: workoutManager.heartRate > 0)

            Text("\(Int(workoutManager.heartRate))")
                .font(.system(size: 72, weight: .bold, design: .rounded))

            // HR source icon — directly under the BPM number
            hrSourceIcon

            Text("BPM")
                .font(.title3)
                .foregroundColor(.secondary)

            // Zone indicator
            Text("Zone: \(workoutManager.lowHR) – \(workoutManager.highHR) bpm")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(16)
    }

    /// Small icon showing which HR source is active:
    /// waveform.path.ecg for chest strap, applewatch for Apple Watch.
    private var hrSourceIcon: some View {
        Group {
            switch workoutManager.hrSource {
            case .chestStrap:
                Label("Chest Strap", systemImage: "waveform.path.ecg")
                    .font(.caption)
                    .foregroundColor(.green)
            case .appleWatch:
                Label("Apple Watch", systemImage: "applewatch")
                    .font(.caption)
                    .foregroundColor(.blue)
            case .unknown:
                Label("Unknown", systemImage: "questionmark.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Cadence Card
    private var cadenceCard: some View {
        HStack {
            VStack(spacing: 4) {
                Text("\(Int(workoutManager.currentCadence))")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("SPM")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Target: \(workoutManager.targetCadence)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                // Visual indicator: on/off cadence
                if workoutManager.currentCadence > 0 {
                    let onCadence = abs(workoutManager.currentCadence - Double(workoutManager.targetCadence)) <= 10
                    Text(onCadence ? "On Cadence" : "Off Cadence")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(onCadence ? .green : .orange)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }

    // MARK: - Stop Button (long-press to confirm)
    private var stopButton: some View {
        ZStack {
            // Background track
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.red.opacity(0.3))
                .frame(height: 56)

            // Fill progress
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.red)
                    .frame(width: geo.size.width * holdProgress)
            }
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Text(isHoldingStop ? "Keep holding..." : "Hold to Stop")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .frame(height: 56)
        .padding(.top, 10)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isHoldingStop {
                        startHold()
                    }
                }
                .onEnded { _ in
                    cancelHold()
                }
        )
    }

    private func startHold() {
        isHoldingStop = true
        holdProgress = 0

        // Fill over 2 seconds, then stop workout
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            holdProgress += 0.05 / 2.0 // 2 seconds to fill
            if holdProgress >= 1.0 {
                timer.invalidate()
                holdTimer = nil
                isHoldingStop = false
                holdProgress = 0
                workoutManager.stopWorkout()
            }
        }
    }

    private func cancelHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        isHoldingStop = false
        withAnimation(.easeOut(duration: 0.2)) {
            holdProgress = 0
        }
    }

    // MARK: - Stat Card
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
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

    private func formatElevation(_ meters: Double) -> String {
        let feet = meters * 3.28084
        return String(format: "%.0f ft", feet)
    }
}
