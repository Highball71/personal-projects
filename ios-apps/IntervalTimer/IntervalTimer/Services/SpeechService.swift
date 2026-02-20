import AVFoundation

/// Wraps AVSpeechSynthesizer for voice announcements during workouts.
/// Announces phase changes ("Work!", "Rest!"), round info, and countdowns.
class SpeechService {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        // Interrupt any current speech so announcements stay timely
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.1
        utterance.volume = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    /// Announce a phase transition with round context
    func announcePhaseChange(phase: TimerPhase, round: Int, totalRounds: Int) {
        switch phase {
        case .work:
            speak("Work! Round \(round) of \(totalRounds)")
        case .rest:
            speak("Rest!")
        case .done:
            speak("Workout complete! Great job!")
        case .countdown:
            break
        }
    }

    /// Speak a countdown number ("3", "2", "1")
    func announceCountdown(_ seconds: Int) {
        speak("\(seconds)")
    }

    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
