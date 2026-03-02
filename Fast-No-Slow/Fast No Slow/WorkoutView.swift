import SwiftUI

struct WorkoutView: View {
    @ObservedObject var workoutManager: WorkoutManager
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Status banner
            statusBanner
            
            ScrollView {
                VStack(spacing: 20) {
                    // Heart rate display
                    heartRateCard
                    
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
                    
                    // Stop button
                    Button(action: {
                        workoutManager.stopWorkout()
                        isPresented = false
                    }) {
                        Text("Stop Workout")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(16)
                    }
                    .padding(.top, 10)
                }
                .padding()
            }
        }
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
