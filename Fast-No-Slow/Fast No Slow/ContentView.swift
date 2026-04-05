import SwiftUI

struct ContentView: View {
    @StateObject private var workoutManager = WorkoutManager()

    // Cadence (primary — form goal)
    @State private var cadenceTarget: Int = 170
    @State private var cadenceFloor: Int = 164
    @State private var floorManuallySet = false

    // HR guardrail (secondary — effort)
    @State private var hrHigh: Int = 150
    @State private var hrLow: Int = 120

    // Metronome
    @State private var metronomeMode: MetronomeMode = .continuous
    @State private var showingWorkout = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // App header
                        VStack(spacing: 8) {
                            Image(systemName: "figure.run")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                            Text("Fast No Slow")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .padding(.top, 20)

                        // CADENCE — primary card (form goal)
                        cadenceCard

                        // METRONOME — mode selection
                        metronomeCard

                        // HR GUARDRAIL — secondary card (effort)
                        hrGuardrailCard

                        // Start button
                        Button(action: startWorkout) {
                            Text("Start Workout")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.green)
                                .cornerRadius(16)
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 30)
                    }
                    .padding(.horizontal)
                }
            }
            .preferredColorScheme(.dark)
            .fullScreenCover(isPresented: $showingWorkout) {
                WorkoutView(workoutManager: workoutManager, isPresented: $showingWorkout)
            }
            .onAppear {
                workoutManager.requestAuthorization()
            }
        }
    }

    // MARK: - Cadence Card

    private var cadenceCard: some View {
        VStack(spacing: 14) {
            sectionHeader("Cadence", subtitle: "Form Goal")

            HStack(spacing: 0) {
                // Target picker
                VStack(spacing: 4) {
                    Text("Target")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    Picker("Target", selection: $cadenceTarget) {
                        ForEach(100...210, id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .clipped()
                }
                .frame(maxWidth: .infinity)

                // Floor picker
                VStack(spacing: 4) {
                    Text("Floor")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(white: 0.5))
                    Picker("Floor", selection: $cadenceFloor) {
                        ForEach(100...210, id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .clipped()
                }
                .frame(maxWidth: .infinity)
            }

            // Labels
            HStack {
                Text("1 beat = 1 step")
                    .font(.caption)
                    .foregroundColor(Color(white: 0.4))
                Spacer()
                Text("SPM")
                    .font(.caption)
                    .foregroundColor(Color(white: 0.4))
            }
        }
        .darkCard()
        .onChange(of: cadenceTarget) { _, newValue in
            // Auto-follow: floor tracks target - 6 unless manually set
            if !floorManuallySet {
                cadenceFloor = max(newValue - 6, 100)
            }
            // Clamp: floor can't exceed target
            if cadenceFloor > newValue {
                cadenceFloor = newValue
            }
        }
        .onChange(of: cadenceFloor) { _, newValue in
            floorManuallySet = true
            // Clamp: floor can't exceed target
            if newValue > cadenceTarget {
                cadenceFloor = cadenceTarget
            }
        }
    }

    // MARK: - Metronome Card

    private var metronomeCard: some View {
        VStack(spacing: 14) {
            sectionHeader("Metronome")

            metronomeModeCard(
                mode: .continuous,
                icon: "metronome.fill",
                subtitle: "Always on at target cadence"
            )
            metronomeModeCard(
                mode: .guardrail,
                icon: "waveform.path",
                subtitle: "Silent when on cadence, fades in when off"
            )
            metronomeModeCard(
                mode: .fade,
                icon: "speaker.wave.2.fill",
                subtitle: "Full 3 min, fades over 2 min, then guardrail"
            )
        }
        .darkCard()
    }

    // MARK: - HR Guardrail Card

    private var hrGuardrailCard: some View {
        VStack(spacing: 14) {
            sectionHeader("Heart Rate", subtitle: "Effort Guardrail")

            HStack(spacing: 0) {
                // Upper bound (strongly enforced)
                VStack(spacing: 4) {
                    Text("Upper")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                    Picker("Upper", selection: $hrHigh) {
                        ForEach(100...220, id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .clipped()
                }
                .frame(maxWidth: .infinity)

                // Lower bound (de-emphasized)
                VStack(spacing: 4) {
                    Text("Lower")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(white: 0.4))
                    Picker("Lower", selection: $hrLow) {
                        ForEach(60...200, id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .clipped()
                    .opacity(0.7)
                }
                .frame(maxWidth: .infinity)
            }

            ZoneBar(low: hrLow, high: hrHigh)
                .frame(height: 36)

            HStack {
                Text("Upper enforced strongly")
                    .font(.caption)
                    .foregroundColor(Color(white: 0.4))
                Spacer()
                Text("BPM")
                    .font(.caption)
                    .foregroundColor(Color(white: 0.4))
            }
        }
        .darkCard()
        .onChange(of: hrHigh) { _, newValue in
            if newValue <= hrLow {
                hrLow = max(newValue - 1, 60)
            }
        }
        .onChange(of: hrLow) { _, newValue in
            if newValue >= hrHigh {
                hrHigh = min(newValue + 1, 220)
            }
        }
    }

    // MARK: - Start Workout

    private func startWorkout() {
        workoutManager.cadenceTarget = CadenceTarget(
            target: cadenceTarget,
            floor: cadenceFloor
        )
        workoutManager.hrGuardrail = HRGuardrail(
            low: hrLow,
            high: hrHigh
        )
        workoutManager.metronomeMode = metronomeMode
        workoutManager.startWorkout()
        showingWorkout = true
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, subtitle: String? = nil) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            if let subtitle {
                Text("— \(subtitle)")
                    .font(.caption)
                    .foregroundColor(Color(white: 0.45))
            }
            Spacer()
        }
    }

    private func metronomeModeCard(mode: MetronomeMode, icon: String, subtitle: String) -> some View {
        let selected = metronomeMode == mode
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                metronomeMode = mode
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(selected ? .green : Color(white: 0.45))
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Color(white: 0.45))
                        .lineLimit(2)
                }

                Spacer()

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selected ? Color.green.opacity(0.1) : Color(white: 0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? Color.green.opacity(0.6) : Color(white: 0.15), lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dark Card Modifier

extension View {
    func darkCard() -> some View {
        self
            .padding()
            .background(.ultraThinMaterial.opacity(0.6))
            .background(Color(white: 0.08))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(white: 0.15), lineWidth: 1)
            )
    }
}

// MARK: - Zone Bar

struct ZoneBar: View {
    let low: Int
    let high: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(white: 0.15))

                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.25))
                    .frame(width: geo.size.width * CGFloat(low) / 220.0)

                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.45))
                    .frame(width: geo.size.width * CGFloat(high - low) / 220.0)
                    .offset(x: geo.size.width * CGFloat(low) / 220.0)

                HStack {
                    Text("\(low)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .offset(x: geo.size.width * CGFloat(low) / 220.0 - 10)
                    Spacer()
                }
                HStack {
                    Spacer()
                        .frame(width: geo.size.width * CGFloat(high) / 220.0 - 10)
                    Text("\(high)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
