import SwiftUI

/// Full-screen workout timer with large countdown display.
/// Background color changes based on phase. Tap anywhere to pause/resume.
struct TimerView: View {
    let workDuration: Int
    let restDuration: Int
    let rounds: Int

    @Environment(\.dismiss) private var dismiss

    @State private var engine = TimerEngine()
    @State private var speechService = SpeechService()
    @State private var audioService = AudioSessionService()
    @State private var hapticService = HapticService()
    @State private var voiceService = VoiceCommandService()

    @State private var showSummary = false
    @State private var voiceCommandsEnabled = false

    var body: some View {
        ZStack {
            // Full-screen background color based on current phase
            engine.currentPhase.color
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: engine.currentPhase)

            VStack(spacing: 20) {
                // Top bar with stop button
                HStack {
                    Button {
                        stopWorkout()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    // Voice command toggle
                    if voiceService.isAvailable {
                        Button {
                            toggleVoiceCommands()
                        } label: {
                            Image(systemName: voiceCommandsEnabled ? "mic.fill" : "mic.slash")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Phase label
                Text(engine.currentPhase.displayName)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .animation(.none, value: engine.currentPhase)

                // Large countdown number — the main thing you see mid-workout
                Text("\(engine.timeRemaining)")
                    .font(.system(size: 140, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.1), value: engine.timeRemaining)

                // Round indicator
                if engine.currentPhase != .countdown {
                    Text("Round \(engine.currentRound) of \(engine.totalRounds)")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer()

                // Pause/resume hint
                if engine.isRunning {
                    Text(engine.isPaused ? "TAP TO RESUME" : "TAP TO PAUSE")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.bottom, 8)
                }
            }
            .padding()

            // Pause overlay
            if engine.isPaused {
                VStack {
                    Spacer()
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("PAUSED")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.top, 8)
                    Spacer()
                }
            }
        }
        // Tap anywhere to toggle pause
        .contentShape(Rectangle())
        .onTapGesture {
            if engine.isRunning {
                engine.togglePause()
                if engine.isPaused {
                    speechService.speak("Paused")
                } else {
                    speechService.speak("Resume")
                }
            }
        }
        .onAppear {
            startWorkout()
        }
        .sheet(isPresented: $showSummary) {
            SummaryView(
                totalTime: engine.totalElapsedTime,
                roundsCompleted: engine.roundsCompleted,
                totalRounds: engine.totalRounds,
                workDuration: workDuration,
                restDuration: restDuration
            )
        }
        // Keep the screen on during workouts
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .statusBarHidden()
    }

    // MARK: - Workout Lifecycle

    private func startWorkout() {
        // Set up audio so TTS works (including in background)
        audioService.activateForWorkout()

        // Wire up engine callbacks
        engine.onPhaseChange = { phase, round, total in
            speechService.announcePhaseChange(phase: phase, round: round, totalRounds: total)
            hapticService.phaseTransition()
        }

        engine.onCountdown = { seconds in
            speechService.announceCountdown(seconds)
        }

        engine.onComplete = {
            hapticService.workoutComplete()
            voiceService.stopListening()
            // Brief delay so "Workout complete!" finishes speaking
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showSummary = true
            }
        }

        // Wire up voice commands
        voiceService.onCommand = { command in
            switch command {
            case .pause:
                if engine.isRunning && !engine.isPaused {
                    engine.pause()
                    speechService.speak("Paused")
                }
            case .resume:
                if engine.isRunning && engine.isPaused {
                    engine.resume()
                    speechService.speak("Resume")
                }
            case .stop:
                stopWorkout()
            }
        }

        // Start the timer
        engine.start(workDuration: workDuration, restDuration: restDuration, rounds: rounds)
    }

    private func stopWorkout() {
        engine.stop()
        speechService.stopSpeaking()
        voiceService.stopListening()
        audioService.deactivate()
        dismiss()
    }

    private func toggleVoiceCommands() {
        if voiceCommandsEnabled {
            voiceService.stopListening()
            voiceCommandsEnabled = false
        } else {
            Task {
                let granted = await voiceService.requestPermissions()
                if granted {
                    voiceService.startListening()
                    voiceCommandsEnabled = true
                }
            }
        }
    }
}

#Preview {
    TimerView(workDuration: 20, restDuration: 10, rounds: 8)
}
