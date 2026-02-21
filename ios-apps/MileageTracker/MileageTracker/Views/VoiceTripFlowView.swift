import SwiftUI
import SwiftData

/// The voice-first conversational trip logging flow.
/// Steps through: Start Location → Start Odometer → Destination → Purpose → Confirm.
/// The app speaks each question aloud and listens for the user's verbal response.
/// Large buttons and text for use while driving.
struct VoiceTripFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedLocation.usageCount, order: .reverse) private var locations: [SavedLocation]

    @State private var speech = SpeechService()
    @State private var step: FlowStep = .startLocation
    @State private var isListeningForVoice = false

    // Trip data being collected
    @State private var startLocationName = ""
    @State private var endLocationName = ""
    @State private var startOdometer = ""
    @State private var endOdometer = ""
    @State private var businessPurpose = ""
    @State private var category: TripCategory = .patientCare
    @State private var isBusiness = true

    // Matched saved locations
    @State private var matchedStartLocation: SavedLocation?
    @State private var matchedEndLocation: SavedLocation?

    enum FlowStep: CaseIterable {
        case startLocation
        case startOdometer
        case destination
        case purpose
        case confirm
    }

    var body: some View {
        ZStack {
            // Background color based on step
            stepColor.ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: step)

            VStack(spacing: 24) {
                // Top bar
                HStack {
                    Button { cancelFlow() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer()
                    Text(stepLabel)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    // Step indicator
                    Text("\(stepNumber)/5")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal)

                Spacer()

                // Question
                Text(questionText)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                // Current answer display
                if step == .confirm {
                    confirmationView
                } else {
                    Text(currentAnswer.isEmpty ? "..." : currentAnswer)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.horizontal)
                }

                // Listening indicator
                if isListeningForVoice {
                    HStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.white)
                            .symbolEffect(.pulse)
                        Text("Listening...")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .font(.title3)
                }

                Spacer()

                // Quick-pick buttons for locations/purposes
                if step == .startLocation || step == .destination {
                    locationButtons
                } else if step == .purpose {
                    purposeButtons
                }

                // Action buttons
                HStack(spacing: 16) {
                    // Voice input button
                    if step != .confirm {
                        Button {
                            toggleVoiceInput()
                        } label: {
                            Image(systemName: isListeningForVoice ? "mic.slash.fill" : "mic.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                                .frame(width: 64, height: 64)
                                .background(.white.opacity(0.2), in: Circle())
                        }
                    }

                    // Next / Save button
                    if step == .confirm {
                        Button { saveTrip() } label: {
                            Text("Save Trip")
                                .font(.title2.bold())
                                .foregroundStyle(stepColor)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                        }
                    } else if !currentAnswer.isEmpty {
                        Button { advanceStep() } label: {
                            Text("Next")
                                .font(.title2.bold())
                                .foregroundStyle(stepColor)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                // Manual text input toggle
                if step != .confirm {
                    TextField("Or type here...", text: currentAnswerBinding)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .keyboardType(step == .startOdometer ? .decimalPad : .default)
                }
            }
            .padding()
        }
        .onAppear {
            speech.activateAudioSession()
            speakCurrentQuestion()
        }
        .onDisappear {
            speech.stopListening()
            speech.stopSpeaking()
            speech.deactivateAudioSession()
        }
    }

    // MARK: - Step Properties

    private var stepColor: Color {
        switch step {
        case .startLocation: return .blue
        case .startOdometer: return .indigo
        case .destination: return .teal
        case .purpose: return .orange
        case .confirm: return .green
        }
    }

    private var stepLabel: String {
        switch step {
        case .startLocation: return "START LOCATION"
        case .startOdometer: return "ODOMETER"
        case .destination: return "DESTINATION"
        case .purpose: return "PURPOSE"
        case .confirm: return "CONFIRM"
        }
    }

    private var stepNumber: Int {
        switch step {
        case .startLocation: return 1
        case .startOdometer: return 2
        case .destination: return 3
        case .purpose: return 4
        case .confirm: return 5
        }
    }

    private var questionText: String {
        switch step {
        case .startLocation: return "Where are you?"
        case .startOdometer: return "What's your odometer reading?"
        case .destination: return "Where are you heading?"
        case .purpose: return "What's the purpose of this trip?"
        case .confirm: return "Does this look right?"
        }
    }

    private var currentAnswer: String {
        switch step {
        case .startLocation: return startLocationName
        case .startOdometer: return startOdometer
        case .destination: return endLocationName
        case .purpose: return businessPurpose
        case .confirm: return ""
        }
    }

    private var currentAnswerBinding: Binding<String> {
        switch step {
        case .startLocation: return $startLocationName
        case .startOdometer: return $startOdometer
        case .destination: return $endLocationName
        case .purpose: return $businessPurpose
        case .confirm: return .constant("")
        }
    }

    // MARK: - Quick-Pick Views

    private var locationButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(locations.prefix(6)) { location in
                    Button {
                        selectLocation(location)
                    } label: {
                        Text(location.voiceName)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.2), in: Capsule())
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var purposeButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TripCategory.allCases) { cat in
                    Button {
                        category = cat
                        businessPurpose = cat.rawValue
                    } label: {
                        Label(cat.rawValue, systemImage: cat.icon)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.2), in: Capsule())
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var confirmationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            confirmRow("From", startLocationName)
            confirmRow("Odometer", startOdometer)
            confirmRow("To", endLocationName)
            confirmRow("Purpose", businessPurpose)
            confirmRow("Category", category.rawValue)
        }
        .padding(20)
        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func confirmRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
        }
    }

    // MARK: - Actions

    private func selectLocation(_ location: SavedLocation) {
        if step == .startLocation {
            startLocationName = location.name
            matchedStartLocation = location
        } else {
            endLocationName = location.name
            matchedEndLocation = location
        }
    }

    private func speakCurrentQuestion() {
        speech.speak(questionText) { [self] in
            startVoiceInput()
        }
    }

    private func startVoiceInput() {
        Task {
            let granted = await speech.requestPermissions()
            if granted {
                speech.startListening()
                isListeningForVoice = true
                // Auto-stop after 5 seconds of listening
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    if isListeningForVoice {
                        stopVoiceAndCapture()
                    }
                }
            }
        }
    }

    private func toggleVoiceInput() {
        if isListeningForVoice {
            stopVoiceAndCapture()
        } else {
            startVoiceInput()
        }
    }

    private func stopVoiceAndCapture() {
        speech.stopListening()
        isListeningForVoice = false

        let text = speech.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Try to match to a saved location
        if step == .startLocation || step == .destination {
            if let match = matchLocation(text) {
                selectLocation(match)
                return
            }
        }

        // Set the recognized text as the current answer
        switch step {
        case .startLocation: startLocationName = text
        case .startOdometer: startOdometer = text.filter { $0.isNumber || $0 == "." }
        case .destination: endLocationName = text
        case .purpose:
            businessPurpose = text
            // Try to match a category
            for cat in TripCategory.allCases {
                if text.localizedCaseInsensitiveContains(cat.rawValue) {
                    category = cat
                    break
                }
            }
        case .confirm: break
        }
    }

    /// Try to match spoken text to a saved location by name or shortName.
    private func matchLocation(_ text: String) -> SavedLocation? {
        let lowered = text.lowercased()
        return locations.first { location in
            lowered.contains(location.shortName.lowercased()) ||
            lowered.contains(location.name.lowercased()) ||
            location.shortName.lowercased().contains(lowered) ||
            location.name.lowercased().contains(lowered)
        }
    }

    private func advanceStep() {
        if isListeningForVoice { stopVoiceAndCapture() }

        guard let nextStep = nextStep else { return }
        withAnimation {
            step = nextStep
        }
        speakCurrentQuestion()
    }

    private var nextStep: FlowStep? {
        switch step {
        case .startLocation: return .startOdometer
        case .startOdometer: return .destination
        case .destination: return .purpose
        case .purpose: return .confirm
        case .confirm: return nil
        }
    }

    private func saveTrip() {
        let trip = Trip(
            startLocationName: startLocationName,
            startOdometer: Double(startOdometer) ?? 0,
            endLocationName: endLocationName,
            businessPurpose: businessPurpose,
            category: category,
            isBusiness: isBusiness,
            // Trip starts as incomplete — ending odometer logged later
            isComplete: false
        )
        trip.startLocation = matchedStartLocation
        trip.endLocation = matchedEndLocation

        // Record location usage for smart suggestions
        matchedStartLocation?.recordUsage()
        matchedEndLocation?.recordUsage()

        modelContext.insert(trip)

        speech.speak("Trip saved. Drive safe!") {
            dismiss()
        }
    }

    private func cancelFlow() {
        speech.stopListening()
        speech.stopSpeaking()
        dismiss()
    }
}
