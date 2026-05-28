import SwiftUI
import AVFoundation

/// Settings sheet: coach voice + metronome volume.
/// Presented from the Start screen. Changes persist via UserDefaults and
/// apply live (the metronome volume forwards to the running engine).
struct SettingsView: View {
    @ObservedObject var workoutManager: WorkoutManager
    @Binding var isPresented: Bool

    // Local mirror of the persisted metronome volume so the slider stays smooth.
    @State private var metronomeVolume: Float = MetronomeVolumeStore.volume

    var body: some View {
        NavigationStack {
            Form {
                Section("Coaching") {
                    NavigationLink {
                        CoachVoicePickerView()
                    } label: {
                        HStack {
                            Label("Coach voice", systemImage: "person.wave.2.fill")
                            Spacer()
                            Text(selectedVoiceName)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Section("Metronome") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Metronome volume", systemImage: "metronome.fill")
                            Spacer()
                            Text("\(Int(metronomeVolume * 100))%")
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        HStack(spacing: 12) {
                            Image(systemName: "speaker.fill")
                                .foregroundColor(.secondary)
                            Slider(value: $metronomeVolume, in: 0...1)
                                .tint(.green)
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresented = false }
                }
            }
            .onChange(of: metronomeVolume) { _, newValue in
                // Persist + apply live to the (possibly running) metronome.
                workoutManager.setMetronomeVolume(newValue)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var selectedVoiceName: String {
        CoachVoiceStore.resolvedVoice()?.name ?? "Default"
    }
}

/// Lists the available English voices. Tapping a row previews the voice
/// (speaks "Pace check") and selects it. The selection persists immediately.
struct CoachVoicePickerView: View {
    @State private var selectedIdentifier: String? = CoachVoiceStore.resolvedVoice()?.identifier
    private let voices = CoachVoiceStore.availableVoices()

    // Dedicated synthesizer so previews don't collide with live coaching.
    private let previewSynth = AVSpeechSynthesizer()

    var body: some View {
        List {
            Section {
                ForEach(voices, id: \.identifier) { voice in
                    Button {
                        select(voice)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(voice.name)
                                    .foregroundColor(.primary)
                                Text("\(voice.language) · \(qualityLabel(voice.quality))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if voice.identifier == selectedIdentifier {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            } footer: {
                Text("Tap a voice to hear a preview and select it. New default is a male US voice.")
            }
        }
        .navigationTitle("Coach Voice")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func select(_ voice: AVSpeechSynthesisVoice) {
        CoachVoiceStore.savedIdentifier = voice.identifier
        selectedIdentifier = voice.identifier
        preview(voice)
    }

    private func preview(_ voice: AVSpeechSynthesisVoice) {
        previewSynth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: "Pace check")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = voice
        previewSynth.speak(utterance)
    }

    private func qualityLabel(_ quality: AVSpeechSynthesisVoiceQuality) -> String {
        switch quality {
        case .premium:  return "Premium"
        case .enhanced: return "Enhanced"
        default:        return "Standard"
        }
    }
}
