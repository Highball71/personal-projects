import SwiftUI

struct ContentView: View {
    @StateObject private var workoutManager = WorkoutManager()
    @State private var lowHR: Double = 120
    @State private var highHR: Double = 150
    @State private var targetCadence: Double = 170
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
                            Image(systemName: "heart.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.red)
                            Text("Fast No Slow")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .padding(.top, 20)

                        // Zone settings card
                        VStack(spacing: 18) {
                            sectionHeader("Heart Rate Zone")

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Low: \(Int(lowHR)) bpm")
                                    .font(.subheadline)
                                    .foregroundColor(Color(white: 0.5))
                                Slider(value: $lowHR, in: 60...200, step: 1)
                                    .tint(.green)
                                    .onChange(of: lowHR) { _, newValue in
                                        if newValue >= highHR {
                                            highHR = min(newValue + 1, 220)
                                        }
                                    }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("High: \(Int(highHR)) bpm")
                                    .font(.subheadline)
                                    .foregroundColor(Color(white: 0.5))
                                Slider(value: $highHR, in: 61...220, step: 1)
                                    .tint(.red)
                                    .onChange(of: highHR) { _, newValue in
                                        if newValue <= lowHR {
                                            lowHR = max(newValue - 1, 60)
                                        }
                                    }
                            }

                            ZoneBar(low: Int(lowHR), high: Int(highHR))
                                .frame(height: 36)
                        }
                        .darkCard()

                        // Metronome mode cards
                        VStack(spacing: 14) {
                            sectionHeader("Metronome")

                            metronomeCard(
                                mode: .continuous,
                                icon: "metronome.fill",
                                subtitle: "Always on at target cadence"
                            )
                            metronomeCard(
                                mode: .guardrail,
                                icon: "waveform.path",
                                subtitle: "Silent when on cadence, fades in when off"
                            )
                            metronomeCard(
                                mode: .fade,
                                icon: "speaker.wave.2.fill",
                                subtitle: "Full 3 min, fades over 2 min, then guardrail"
                            )
                        }
                        .darkCard()

                        // Target cadence + tolerance info card
                        VStack(spacing: 14) {
                            sectionHeader("Cadence Target")

                            HStack(alignment: .firstTextBaseline) {
                                Text("\(Int(targetCadence))")
                                    .font(.system(size: 44, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("SPM")
                                    .font(.subheadline)
                                    .foregroundColor(Color(white: 0.5))
                            }

                            Slider(value: $targetCadence, in: 100...210, step: 1)
                                .tint(.orange)

                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(Color(white: 0.4))
                                Text("Tolerance: ±10 SPM")
                                    .font(.caption)
                                    .foregroundColor(Color(white: 0.4))
                            }
                        }
                        .darkCard()

                        // Start button
                        Button(action: {
                            workoutManager.lowHR = Int(lowHR)
                            workoutManager.highHR = Int(highHR)
                            workoutManager.targetCadence = Int(targetCadence)
                            workoutManager.metronomeMode = metronomeMode
                            workoutManager.startWorkout()
                            showingWorkout = true
                        }) {
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

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
        }
    }

    // MARK: - Metronome Mode Card

    private func metronomeCard(mode: MetronomeMode, icon: String, subtitle: String) -> some View {
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
