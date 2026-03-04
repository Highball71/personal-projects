import SwiftUI

struct ContentView: View {
    @StateObject private var workoutManager = WorkoutManager()
    @State private var lowHR: Int = 120
    @State private var highHR: Int = 160
    @State private var metronomeEnabled: Bool = false
    @State private var metronomeBPM: Int = 170
    @State private var showingWorkout = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Heart icon
                Image(systemName: "heart.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)

                Text("Fast No Slow")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // Zone settings
                VStack(spacing: 12) {
                    HStack(spacing: 0) {
                        // Low threshold picker
                        VStack(spacing: 4) {
                            Text("Low Threshold")
                                .font(.headline)
                            Picker("Low HR", selection: $lowHR) {
                                ForEach(40...220, id: \.self) { value in
                                    Text("\(value) bpm").tag(value)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 120)
                            .clipped()
                            .onChange(of: lowHR) { _, newValue in
                                if newValue >= highHR {
                                    highHR = min(newValue + 1, 220)
                                }
                            }
                        }

                        // High threshold picker
                        VStack(spacing: 4) {
                            Text("High Threshold")
                                .font(.headline)
                            Picker("High HR", selection: $highHR) {
                                ForEach(40...220, id: \.self) { value in
                                    Text("\(value) bpm").tag(value)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 120)
                            .clipped()
                            .onChange(of: highHR) { _, newValue in
                                if newValue <= lowHR {
                                    lowHR = max(newValue - 1, 40)
                                }
                            }
                        }
                    }

                    // Visual zone bar
                    ZoneBar(low: lowHR, high: highHR)
                        .frame(height: 40)
                }
                .padding()
                .background(Color.gray.opacity(0.35))
                .cornerRadius(16)

                // Metronome settings
                VStack(spacing: 12) {
                    Toggle(isOn: $metronomeEnabled.animation(.easeInOut(duration: 0.25))) {
                        Label("Metronome", systemImage: "metronome")
                            .font(.headline)
                    }

                    if metronomeEnabled {
                        Stepper(value: $metronomeBPM, in: 60...200, step: 5) {
                            Text("\(metronomeBPM) BPM cadence")
                                .font(.subheadline)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.35))
                .cornerRadius(16)

                Spacer()

                // Start button
                Button(action: {
                    workoutManager.lowHR = lowHR
                    workoutManager.highHR = highHR
                    workoutManager.metronomeEnabled = metronomeEnabled
                    workoutManager.metronomeBPM = metronomeBPM
                    workoutManager.startWorkout()
                    showingWorkout = true
                }) {
                    Text("Start Workout")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(16)
                }

                Spacer()
            }
            .padding()
            .fullScreenCover(isPresented: $showingWorkout) {
                WorkoutView(workoutManager: workoutManager, isPresented: $showingWorkout)
            }
            .onAppear {
                workoutManager.requestAuthorization()
            }
        }
    }
}

// MARK: - Zone Bar
struct ZoneBar: View {
    let low: Int
    let high: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.35))

                // Below zone
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: geo.size.width * CGFloat(low) / 220.0)

                // In zone
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.5))
                    .frame(width: geo.size.width * CGFloat(high - low) / 220.0)
                    .offset(x: geo.size.width * CGFloat(low) / 220.0)

                // Labels
                HStack {
                    Text("\(low)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .offset(x: geo.size.width * CGFloat(low) / 220.0 - 10)
                    Spacer()
                }
                HStack {
                    Spacer()
                        .frame(width: geo.size.width * CGFloat(high) / 220.0 - 10)
                    Text("\(high)")
                        .font(.caption)
                        .fontWeight(.bold)
                    Spacer()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
