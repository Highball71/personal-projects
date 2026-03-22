import SwiftUI

struct WorkoutView: View {
    @ObservedObject var workoutManager: WorkoutManager
    @Binding var isPresented: Bool
    @State private var isHoldingStop = false
    @State private var holdProgress: CGFloat = 0
    @State private var holdTimer: Timer?
    @State private var ringPulse = false
    @State private var heartScale: CGFloat = 1.0

    // MARK: - Color System
    // emerald/green = in zone, red = too high, orange = drifting, slate = neutral
    private var ringColor: Color {
        switch workoutManager.zoneStatus {
        case .inZone:    return .green
        case .aboveZone: return .red
        case .belowZone: return Color(white: 0.35)
        }
    }

    private var bpmColor: Color {
        workoutManager.isInZone ? .green : .white
    }

    private var bannerColor: Color {
        switch workoutManager.zoneStatus {
        case .belowZone: return .blue
        case .inZone:    return .green
        case .aboveZone: return .red
        }
    }

    private var bannerIcon: String {
        switch workoutManager.zoneStatus {
        case .belowZone: return "hare"
        case .inZone:    return "checkmark.circle.fill"
        case .aboveZone: return "tortoise"
        }
    }

    var body: some View {
        if workoutManager.showSummary {
            SummaryView(workoutManager: workoutManager) {
                isPresented = false
            }
        } else {
            workoutContent
        }
    }

    // MARK: - Main Layout

    private var workoutContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                hrMonitorPill
                statusBanner

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Hero: pulsing HR ring
                        heartRateRing
                            .padding(.top, 8)

                        // Thin divider
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 1)
                            .padding(.horizontal, 24)

                        // Cadence readout
                        cadenceDisplay

                        // 2x2 stats grid — frosted glass
                        statsGrid

                        // Pause / Resume
                        pauseButton

                        // Hold-to-stop
                        stopButton
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - HR Monitor Pill

    private var hrMonitorPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(workoutManager.hrMonitorState == .connected ? Color.green : Color(white: 0.4))
                .frame(width: 8, height: 8)
            switch workoutManager.hrMonitorState {
            case .connected:
                Text(workoutManager.connectedDeviceName ?? "HR Monitor")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            case .searching:
                Text("Searching...")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.45))
            case .disconnected:
                Text("No Monitor")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.45))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    // MARK: - Status Banner

    private var statusBanner: some View {
        let paused = workoutManager.isPaused
        return HStack(spacing: 8) {
            Image(systemName: paused ? "pause.fill" : bannerIcon)
                .font(.title3)
            Text(paused ? "PAUSED" : workoutManager.zoneStatus.rawValue)
                .font(.title3)
                .fontWeight(.bold)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(paused ? Color.orange : bannerColor)
        .animation(.easeInOut(duration: 0.3), value: workoutManager.zoneStatus)
        .animation(.easeInOut(duration: 0.3), value: workoutManager.isPaused)
    }

    // MARK: - Heart Rate Ring

    private var heartRateRing: some View {
        ZStack {
            // Outer glow ring — pulses gently
            Circle()
                .stroke(lineWidth: 6)
                .foregroundColor(ringColor)
                .shadow(color: workoutManager.isInZone ? .green.opacity(0.5) : .clear, radius: 24)
                .frame(width: 220, height: 220)
                .scaleEffect(ringPulse ? 1.025 : 1.0)
                .animation(
                    .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                    value: ringPulse
                )

            // Inner content
            VStack(spacing: 2) {
                // Heart icon — bounces on each HR update
                Image(systemName: "heart.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.red)
                    .scaleEffect(heartScale)

                // BPM — massive, colored by zone
                Text("\(Int(workoutManager.heartRate))")
                    .font(.system(size: 76, weight: .bold, design: .rounded))
                    .foregroundColor(bpmColor)
                    .contentTransition(.numericText())

                // HR source icon
                hrSourceIcon

                // Zone range
                Text("Zone: \(workoutManager.lowHR)–\(workoutManager.highHR) bpm")
                    .font(.caption)
                    .foregroundColor(Color(white: 0.5))
            }
        }
        .frame(height: 230)
        .onAppear { ringPulse = true }
        .onChange(of: workoutManager.heartRate) { _, _ in
            // Heartbeat bounce
            withAnimation(.interpolatingSpring(stiffness: 220, damping: 8)) {
                heartScale = 1.35
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.interpolatingSpring(stiffness: 220, damping: 10)) {
                    heartScale = 1.0
                }
            }
        }
    }

    // MARK: - HR Source Icon

    private var hrSourceIcon: some View {
        Group {
            switch workoutManager.hrSource {
            case .chestStrap:
                Label("Chest Strap", systemImage: "waveform.path.ecg")
                    .font(.caption2)
                    .foregroundColor(.green)
            case .appleWatch:
                Label("Apple Watch", systemImage: "applewatch")
                    .font(.caption2)
                    .foregroundColor(.blue)
            case .unknown:
                Label("Unknown", systemImage: "questionmark.circle")
                    .font(.caption2)
                    .foregroundColor(Color(white: 0.45))
            }
        }
    }

    // MARK: - Cadence Display

    private var cadenceDisplay: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(Int(workoutManager.currentCadence))")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("SPM")
                .font(.subheadline)
                .foregroundColor(Color(white: 0.45))

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("Target \(workoutManager.targetCadence)")
                    .font(.caption)
                    .foregroundColor(Color(white: 0.45))
                if workoutManager.currentCadence > 0 {
                    let onCadence = abs(workoutManager.currentCadence - Double(workoutManager.targetCadence)) <= 10
                    Text(onCadence ? "On Cadence" : "Off Cadence")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(onCadence ? .green : .orange)
                }
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - 2x2 Stats Grid (frosted glass)

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)], spacing: 12) {
            glassCard(
                title: "Time in Zone",
                value: formatTime(workoutManager.timeInZone),
                icon: "timer",
                color: .green
            )
            glassCard(
                title: "Distance",
                value: formatDistance(workoutManager.totalDistance),
                icon: "figure.run",
                color: .blue
            )
            glassCard(
                title: "Duration",
                value: formatTime(workoutManager.elapsedTime),
                icon: "clock",
                color: .blue
            )
            glassCard(
                title: "Elevation",
                value: formatElevation(workoutManager.elevationGain),
                icon: "arrow.up.right",
                color: .orange
            )
        }
    }

    private func glassCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Text(title)
                .font(.caption2)
                .foregroundColor(Color(white: 0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    // MARK: - Pause / Resume Button

    private var pauseButton: some View {
        Button {
            if workoutManager.isPaused {
                workoutManager.resumeWorkout()
            } else {
                workoutManager.pauseWorkout()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: workoutManager.isPaused ? "play.fill" : "pause.fill")
                    .font(.title3)
                Text(workoutManager.isPaused ? "Resume" : "Pause")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(workoutManager.isPaused ? Color.green.opacity(0.85) : Color.white.opacity(0.12))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(workoutManager.isPaused ? Color.green : Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .animation(.easeInOut(duration: 0.2), value: workoutManager.isPaused)
    }

    // MARK: - Stop Button (hold to confirm)

    private var stopButton: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.red.opacity(0.2))
                .frame(height: 54)

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.red)
                    .frame(width: geo.size.width * holdProgress)
            }
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Text(isHoldingStop ? "Keep holding..." : "Hold to Stop")
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(height: 54)
        .padding(.top, 4)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isHoldingStop { startHold() }
                }
                .onEnded { _ in
                    cancelHold()
                }
        )
    }

    private func startHold() {
        isHoldingStop = true
        holdProgress = 0
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            holdProgress += 0.05 / 2.0
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
        withAnimation(.easeOut(duration: 0.2)) { holdProgress = 0 }
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
