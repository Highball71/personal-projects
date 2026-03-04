import SwiftUI

struct WorkoutView: View {
    @ObservedObject var workoutManager: WorkoutManager
    @Binding var isPresented: Bool
    @State private var isLocked: Bool = false
    @State private var unlockProgress: CGFloat = 0
    @State private var isHoldingUnlock: Bool = false

    var body: some View {
        ZStack {
            // Main workout content
            VStack(spacing: 0) {
                // Status banner
                statusBanner

                ScrollView {
                    VStack(spacing: 20) {
                        // Heart rate display
                        heartRateCard

                        // Cadence
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

                        // Lock & Stop buttons
                        HStack(spacing: 16) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isLocked = true
                                }
                            }) {
                                Label("Lock Screen", systemImage: "lock.fill")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .cornerRadius(16)
                            }

                            Button(action: {
                                workoutManager.stopWorkout()
                                isPresented = false
                            }) {
                                Label("Stop", systemImage: "stop.fill")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .cornerRadius(16)
                            }
                        }
                        .padding(.top, 10)
                    }
                    .padding()
                }
            }

            // Lock overlay
            if isLocked {
                lockOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isLocked)
    }

    // MARK: - Lock Overlay
    private var lockOverlay: some View {
        ZStack {
            // Semi-transparent background that intercepts touches
            Color.black.opacity(0.15)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { }

            // Unlock button
            VStack(spacing: 12) {
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 4)
                        .frame(width: 64, height: 64)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: unlockProgress)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))

                    Image(systemName: unlockProgress >= 1.0 ? "lock.open.fill" : "lock.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }

                Text("Hold to Unlock")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 1.0)
                    .onChanged { _ in
                        isHoldingUnlock = true
                        withAnimation(.linear(duration: 1.0)) {
                            unlockProgress = 1.0
                        }
                    }
                    .onEnded { _ in
                        isHoldingUnlock = false
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isLocked = false
                        }
                        unlockProgress = 0
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in
                        // Reset progress if released early
                        if isLocked {
                            isHoldingUnlock = false
                            withAnimation(.easeOut(duration: 0.2)) {
                                unlockProgress = 0
                            }
                        }
                    }
            )
        }
    }

    // MARK: - Status Banner
    private var statusBanner: some View {
        HStack {
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption)
            }
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

    // MARK: - Heart Rate Card
    private var heartRateCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)
                .symbolEffect(.pulse, isActive: workoutManager.heartRate > 0)

            Text("\(Int(workoutManager.heartRate))")
                .font(.system(size: 72, weight: .bold, design: .rounded))

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

    // MARK: - Cadence Card
    private var cadenceCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "shoeprints.fill")
                .font(.title2)
                .foregroundColor(.mint)
            VStack(alignment: .leading, spacing: 2) {
                Text(workoutManager.cadence.map { "\($0)" } ?? "—")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("steps/min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(16)
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
