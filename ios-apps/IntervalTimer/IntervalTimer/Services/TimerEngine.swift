import Foundation
import Observation

/// Core timer logic for interval workouts.
/// Tracks phase, round, and time remaining. Uses wall-clock timestamps
/// so the timer stays accurate even if ticks are delayed (e.g. background).
@Observable
class TimerEngine {
    // MARK: - Published State

    var currentPhase: TimerPhase = .countdown
    var currentRound: Int = 1
    var totalRounds: Int = 0
    var timeRemaining: Int = 3
    var isRunning: Bool = false
    var isPaused: Bool = false
    var totalElapsedTime: TimeInterval = 0
    var roundsCompleted: Int = 0

    // MARK: - Configuration

    private var workDuration: Int = 0
    private var restDuration: Int = 0

    // MARK: - Internal Timing

    private var timer: Timer?
    private var phaseStartDate: Date?
    private var phaseDuration: Int = 0
    private var elapsedBeforePause: TimeInterval = 0

    // MARK: - Callbacks

    /// Called when the phase changes (work/rest/done). Includes round info.
    var onPhaseChange: ((TimerPhase, Int, Int) -> Void)?

    /// Called at 10 seconds remaining and for 5-4-3-2-1 countdown.
    var onCountdown: ((Int) -> Void)?

    /// Called when the entire workout is complete.
    var onComplete: (() -> Void)?

    // Track which countdown values we've already announced,
    // so we don't repeat if a tick catches the same second twice
    private var announcedCountdowns: Set<Int> = []

    // MARK: - Public API

    func start(workDuration: Int, restDuration: Int, rounds: Int) {
        self.workDuration = workDuration
        self.restDuration = restDuration
        self.totalRounds = rounds
        self.currentRound = 1
        self.roundsCompleted = 0
        self.totalElapsedTime = 0
        self.elapsedBeforePause = 0
        self.isRunning = true
        self.isPaused = false

        beginPhase(.countdown, duration: 3)
    }

    func pause() {
        guard isRunning, !isPaused else { return }
        isPaused = true
        // Save elapsed time so far
        elapsedBeforePause = totalElapsedTime
        stopTimer()
    }

    func resume() {
        guard isRunning, isPaused else { return }
        isPaused = false
        // Recalculate phaseStartDate so the remaining time stays correct
        phaseStartDate = Date().addingTimeInterval(-Double(phaseDuration - timeRemaining))
        startTimer()
    }

    func stop() {
        stopTimer()
        isRunning = false
        isPaused = false
    }

    func togglePause() {
        if isPaused {
            resume()
        } else {
            pause()
        }
    }

    // MARK: - Phase Management

    private func beginPhase(_ phase: TimerPhase, duration: Int) {
        currentPhase = phase
        phaseDuration = duration
        timeRemaining = duration
        phaseStartDate = Date()
        announcedCountdowns = []
        startTimer()
    }

    private func advancePhase() {
        switch currentPhase {
        case .countdown:
            // Countdown done — start first work phase
            currentPhase = .work
            onPhaseChange?(.work, currentRound, totalRounds)
            beginPhase(.work, duration: workDuration)

        case .work:
            roundsCompleted = currentRound
            if currentRound >= totalRounds {
                // Workout complete
                stopTimer()
                currentPhase = .done
                timeRemaining = 0
                isRunning = false
                onPhaseChange?(.done, currentRound, totalRounds)
                onComplete?()
            } else {
                // Transition to rest
                onPhaseChange?(.rest, currentRound, totalRounds)
                beginPhase(.rest, duration: restDuration)
            }

        case .rest:
            // Rest done — next round
            currentRound += 1
            onPhaseChange?(.work, currentRound, totalRounds)
            beginPhase(.work, duration: workDuration)

        case .done:
            break
        }
    }

    // MARK: - Timer Tick

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // Make sure the timer fires during scroll/tracking events
        if let timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let startDate = phaseStartDate else { return }

        let elapsed = Date().timeIntervalSince(startDate)
        let remaining = max(0, phaseDuration - Int(elapsed))

        // Update total elapsed time
        totalElapsedTime = elapsedBeforePause + elapsed

        // Only do work if the displayed second changed
        if remaining != timeRemaining {
            timeRemaining = remaining

            // Announce "10 seconds" at 10, then spoken countdown 5-4-3-2-1.
            // The announcedCountdowns set prevents repeats if multiple ticks
            // land on the same second.
            let triggers: Set<Int> = [10, 5, 4, 3, 2, 1]
            if triggers.contains(timeRemaining) && !announcedCountdowns.contains(timeRemaining) {
                announcedCountdowns.insert(timeRemaining)
                onCountdown?(timeRemaining)
            }
        }

        if timeRemaining <= 0 {
            advancePhase()
        }
    }
}
