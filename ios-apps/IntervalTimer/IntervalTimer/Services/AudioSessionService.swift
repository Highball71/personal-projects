import AVFoundation

/// Manages the AVAudioSession for background audio playback during workouts.
/// Uses .playAndRecord to support both TTS output and voice command input.
class AudioSessionService {
    /// Configure the audio session for a workout.
    /// Uses .playAndRecord so TTS and voice recognition can coexist.
    /// .defaultToSpeaker ensures audio plays through the speaker (not earpiece).
    func activateForWorkout() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetoothHFP, .duckOthers]
            )
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    /// Deactivate the audio session when the workout is done.
    /// Notifies other apps so they can resume their audio.
    func deactivate() {
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
}
