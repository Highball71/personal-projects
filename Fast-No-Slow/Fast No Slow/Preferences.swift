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

    /// A sensible male default, chosen by what's actually installed.
    ///
    /// We resolve by name (not a hardcoded identifier) so a missing download
    /// degrades gracefully. Verified on-device (iOS 26.5): a stock iPhone has
    /// NO premium/enhanced en-US male voice installed — the only en-US voice
    /// tagged `male` is Fred, the robotic legacy voice, which is a poor coach.
    /// So the ranked list prefers good en-US males when present (Aaron, Tom,
    /// Evan, Nathan) and then falls to Daniel/Arthur (en-GB) and Rishi (en-IN),
    /// which ship on most devices without a download and sound far better than
    /// Fred. Fred is reached only as a true last resort.
    static func defaultVoice() -> AVSpeechSynthesisVoice? {
        let english = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }

        let ranked = ["Aaron", "Tom", "Evan", "Nathan", "Daniel", "Arthur", "Rishi"]
        for name in ranked {
            // If a named voice is installed at multiple qualities, take the best.
            if let best = english
                .filter({ $0.name.localizedCaseInsensitiveContains(name) })
                .max(by: { $0.quality.rawValue < $1.quality.rawValue }) {
                return best
            }
        }
        // Any en-US male, then any English male, then a generic en-US voice.
        if let usMale = english.first(where: { $0.language == "en-US" && $0.gender == .male }) {
            return usMale
        }
        if let male = english.first(where: { $0.gender == .male }) {
            return male
        }
        return AVSpeechSynthesisVoice(language: "en-US")
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
