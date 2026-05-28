import AVFoundation
import Foundation

/// User-tunable preferences that persist across launches via UserDefaults.
///
/// Two settings live here today:
///   • Coach voice  — which AVSpeechSynthesisVoice the coaching engine speaks with.
///   • Metronome volume — a 0...1 scale applied to the metronome click.
///
/// Both are deliberately simple static stores so any layer (UI, WorkoutManager,
/// MetronomeEngine) can read/write them without plumbing a shared object around.

// MARK: - Coach Voice

enum CoachVoiceStore {
    static let defaultsKey = "coachVoiceIdentifier"

    /// The user's chosen voice identifier, or nil if they haven't picked one.
    static var savedIdentifier: String? {
        get { UserDefaults.standard.string(forKey: defaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    /// All selectable English voices, best quality first, then alphabetical.
    /// Used to populate the Settings → Coach voice list.
    static func availableVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted {
                if $0.quality.rawValue != $1.quality.rawValue {
                    return $0.quality.rawValue > $1.quality.rawValue
                }
                if $0.name != $1.name { return $0.name < $1.name }
                return $0.language < $1.language
            }
    }

    /// The voice the coaching engine should actually speak with.
    /// Falls back to the male default if the saved voice is missing
    /// (e.g. the user deleted it, or it never shipped on this iOS version).
    static func resolvedVoice() -> AVSpeechSynthesisVoice? {
        if let id = savedIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: id) {
            return voice
        }
        return defaultVoice()
    }

    /// A sensible male en-US default, chosen by what's actually installed.
    /// Preference order: Aaron → Tom → any male en-US → any en-US.
    /// Aaron and Tom are both reliable male en-US voices across recent iOS
    /// versions; we resolve by name rather than hardcoding an identifier so
    /// a missing download degrades gracefully instead of going silent.
    static func defaultVoice() -> AVSpeechSynthesisVoice? {
        let enUS = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "en-US" }

        for preferredName in ["Aaron", "Tom"] {
            if let match = enUS.first(where: { $0.name.localizedCaseInsensitiveContains(preferredName) }) {
                return match
            }
        }
        if let male = enUS.first(where: { $0.gender == .male }) {
            return male
        }
        return enUS.first ?? AVSpeechSynthesisVoice(language: "en-US")
    }
}

// MARK: - Metronome Volume

enum MetronomeVolumeStore {
    static let defaultsKey = "metronomeVolume"

    /// 0.0...1.0 scale applied on top of the metronome's own envelope.
    /// Defaults to 1.0 (full) so existing users hear no change. The
    /// `object(forKey:)` check distinguishes "never set" (→ 1.0) from a
    /// deliberate 0.0 (silent).
    static var volume: Float {
        get {
            guard UserDefaults.standard.object(forKey: defaultsKey) != nil else { return 1.0 }
            return Float(UserDefaults.standard.double(forKey: defaultsKey))
        }
        set {
            UserDefaults.standard.set(Double(min(max(newValue, 0), 1)), forKey: defaultsKey)
        }
    }
}
