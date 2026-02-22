import SwiftUI
import SwiftData
import Speech

/// The voice-first conversational trip logging flow.
/// Steps through: Start Location → Start Odometer → Destination → Purpose → Confirm.
///
/// Fully hands-free: the app speaks each question aloud, listens for the verbal
/// response, reads it back for confirmation, and auto-advances to the next step.
/// The screen shows a glanceable display of the current step and recognized text
/// but never requires a touch.
struct VoiceTripFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedLocation.usageCount, order: .reverse) private var locations: [SavedLocation]

    @State private var speech = SpeechService()
    @State private var step: FlowStep = .startLocation
    @State private var isListeningForVoice = false
    @State private var showRetryMessage = false

    // Trip data being collected
    @State private var startLocationName = ""
    @State private var endLocationName = ""
    @State private var startOdometer = ""
    @State private var businessPurpose = ""
    @State private var category: TripCategory = .patientCare
    @State private var isBusiness = true

    // Matched saved locations
    @State private var matchedStartLocation: SavedLocation?
    @State private var matchedEndLocation: SavedLocation?

    // Tracks whether we've initiated the flow for a step (prevents re-triggering)
    @State private var stepInitiated = false

    // Retry tracking — cap at 3 attempts per step before showing manual fallback
    @State private var retryCount = 0
    @State private var showManualFallback = false
    private let maxRetries = 3

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
                    Text(displayText)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(2)
                        .padding(.horizontal)
                        .contentTransition(.numericText())
                        .animation(.default, value: displayText)
                }

                // Listening indicator
                if showManualFallback {
                    HStack(spacing: 8) {
                        Image(systemName: "keyboard")
                            .foregroundStyle(.white)
                        Text("Type your answer or tap the mic")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .font(.subheadline)
                } else if isListeningForVoice {
                    HStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.white)
                            .symbolEffect(.pulse)
                        Text("Listening...")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .font(.title3)
                } else if showRetryMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.white)
                        Text("Trying again...")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .font(.title3)
                }

                Spacer()

                // Quick-pick buttons — still available as a fallback
                if step == .startLocation || step == .destination {
                    locationButtons
                } else if step == .purpose {
                    purposeButtons
                }

                // Minimal action area — voice mic toggle only (for manual override)
                HStack(spacing: 16) {
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

                        // Manual skip/next if voice captured something
                        if !currentAnswer.isEmpty {
                            Button { advanceStep() } label: {
                                Text("Next")
                                    .font(.title2.bold())
                                    .foregroundStyle(stepColor)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    } else {
                        // Confirm step: save or redo buttons
                        Button { saveTrip() } label: {
                            Text("Save Trip")
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

                // Manual text input — still available as fallback
                if step != .confirm {
                    TextField("Or type here...", text: currentAnswerBinding)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .keyboardType(step == .startOdometer ? .decimalPad : .default)
                        .onSubmit {
                            if !currentAnswer.isEmpty {
                                advanceStep()
                            }
                        }
                }
            }
            .padding()
        }
        .onAppear {
            configureSpeechService()
            speech.activateAudioSession()
            beginStep()
        }
        .onDisappear {
            speech.stopListening()
            speech.stopSpeaking()
            speech.deactivateAudioSession()
        }
        .onChange(of: step) { _, _ in
            stepInitiated = false
            retryCount = 0
            showManualFallback = false
            beginStep()
        }
    }

    // MARK: - Display

    /// What to show in the big text area — live partial results while listening,
    /// or the captured answer once done.
    private var displayText: String {
        if isListeningForVoice && !speech.recognizedText.isEmpty {
            // Show live partial results while listening
            if step == .startOdometer {
                return speech.recognizedText.filter { $0.isNumber || $0 == "." }
            }
            return speech.recognizedText
        }
        return currentAnswer.isEmpty ? "..." : currentAnswer
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
                        // Auto-advance after quick-pick
                        speakAndAdvance(location.voiceName)
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
                        speakAndAdvance(cat.rawValue)
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
            confirmRow("Odometer", formatOdometer(startOdometer))
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

    // MARK: - Speech Service Configuration

    private func configureSpeechService() {
        // Feed location names as contextual strings to improve recognition accuracy
        speech.contextualStrings = locations.flatMap { loc in
            [loc.name, loc.shortName].filter { !$0.isEmpty }
        }
        // Add purpose keywords
        speech.contextualStrings += TripCategory.allCases.map(\.rawValue)

        // Set up the callback for when listening auto-stops
        speech.onListeningStopped = { [self] finalText in
            handleRecognitionResult(finalText)
        }

        // Set up keyword detection
        speech.onKeywordDetected = { [self] keyword in
            handleKeyword(keyword)
        }
    }

    // MARK: - Flow Control

    /// Begin a new step: speak the question, then start listening.
    private func beginStep() {
        guard !stepInitiated else { return }
        stepInitiated = true
        showRetryMessage = false

        if step == .confirm {
            speakSummaryAndListen()
        } else {
            // Configure speech for this step
            configureForCurrentStep()

            speech.speak(questionText) {
                startVoiceInput()
            }
        }
    }

    /// Configure recognition parameters based on the current step.
    private func configureForCurrentStep() {
        switch step {
        case .startOdometer:
            // Odometer readings are 5-6 digits; don't stop until we have at least 4
            speech.minimumLength = 4
            speech.silenceTimeout = 4.0
        case .startLocation, .destination:
            speech.minimumLength = 0
            speech.silenceTimeout = 3.0
        case .purpose:
            speech.minimumLength = 0
            speech.silenceTimeout = 3.0
        case .confirm:
            speech.minimumLength = 0
            speech.silenceTimeout = 3.0
        }
    }

    /// Speak the full summary aloud and listen for yes/no confirmation.
    private func speakSummaryAndListen() {
        let odo = formatOdometer(startOdometer)
        let summary = "\(odo) miles on odometer, from \(startLocationName) to \(endLocationName), \(businessPurpose). Save this trip?"

        // For the confirm step, listen for yes/no keywords
        speech.minimumLength = 0
        speech.silenceTimeout = 5.0

        speech.speak(summary) {
            startVoiceInput(taskHint: .confirmation)
        }
    }

    private func startVoiceInput(taskHint: SFSpeechRecognitionTaskHint = .dictation) {
        Task {
            let granted = await speech.requestPermissions()
            if granted {
                speech.startListening(taskHint: taskHint)
                isListeningForVoice = true
            }
        }
    }

    private func toggleVoiceInput() {
        if isListeningForVoice {
            // Manual stop — capture what we have
            isListeningForVoice = false
            speech.stopListening()
            let text = speech.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                handleRecognitionResult(text)
            }
        } else {
            // Reset retry state so the user gets fresh attempts
            retryCount = 0
            showManualFallback = false
            configureForCurrentStep()
            startVoiceInput()
        }
    }

    // MARK: - Recognition Handling

    /// Process the recognized text for the current step.
    /// Called when the silence timer fires or a keyword triggers.
    private func handleRecognitionResult(_ text: String) {
        isListeningForVoice = false

        guard !text.isEmpty else {
            retryCurrentStep()
            return
        }

        switch step {
        case .startLocation:
            if let match = matchLocation(text) {
                selectLocation(match)
                speakAndAdvance(match.voiceName)
            } else {
                startLocationName = text
                speakAndAdvance(text)
            }

        case .startOdometer:
            let digits = text.filter { $0.isNumber || $0 == "." }
            guard digits.count >= 4 else {
                // Not enough digits — tell the user and retry
                speech.speak("I heard \(text), but that seems too short for an odometer reading. Try again.") {
                    self.configureForCurrentStep()
                    self.startVoiceInput()
                }
                return
            }
            startOdometer = digits
            speakAndAdvance(formatOdometer(digits))

        case .destination:
            if let match = matchLocation(text) {
                selectLocation(match)
                speakAndAdvance(match.voiceName)
            } else {
                endLocationName = text
                speakAndAdvance(text)
            }

        case .purpose:
            businessPurpose = text
            // Try to match a category from spoken text
            for cat in TripCategory.allCases {
                if text.localizedCaseInsensitiveContains(cat.rawValue) {
                    category = cat
                    break
                }
            }
            speakAndAdvance(businessPurpose)

        case .confirm:
            handleConfirmation(text)
        }
    }

    /// Handle a detected keyword.
    private func handleKeyword(_ keyword: String) {
        switch keyword {
        case "done", "save":
            if step == .confirm {
                // "Save" on confirm step = save the trip
                isListeningForVoice = false
                speech.stopListening()
                saveTrip()
            } else {
                // "Done" on any other step = stop listening and process
                isListeningForVoice = false
                speech.stopListening()
                let text = speech.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
                // Remove the keyword from the end of the text
                let cleaned = removeTrailingKeyword(text, keyword: keyword)
                handleRecognitionResult(cleaned)
            }
        case "yes", "correct":
            if step == .confirm {
                isListeningForVoice = false
                speech.stopListening()
                saveTrip()
            }
        case "no", "cancel":
            if step == .confirm {
                isListeningForVoice = false
                speech.stopListening()
                // Go back to step 1 so they can redo
                speech.speak("OK, let's start over.") {
                    withAnimation {
                        self.step = .startLocation
                    }
                    self.startLocationName = ""
                    self.endLocationName = ""
                    self.startOdometer = ""
                    self.businessPurpose = ""
                }
            }
        default:
            break
        }
    }

    /// Handle yes/no confirmation at the final step.
    private func handleConfirmation(_ text: String) {
        let lowered = text.lowercased()
        if lowered.contains("yes") || lowered.contains("save") || lowered.contains("correct") {
            saveTrip()
        } else if lowered.contains("no") || lowered.contains("cancel") || lowered.contains("redo") {
            speech.speak("OK, let's start over.") {
                withAnimation {
                    self.step = .startLocation
                }
                self.startLocationName = ""
                self.endLocationName = ""
                self.startOdometer = ""
                self.businessPurpose = ""
            }
        } else {
            // Didn't understand — ask again
            speech.speak("Sorry, say yes to save or no to start over.") {
                self.startVoiceInput(taskHint: .confirmation)
            }
        }
    }

    /// If recognition came back empty or failed, say so and retry.
    /// Caps at 3 retries per step, then falls back to manual input.
    private func retryCurrentStep() {
        retryCount += 1

        if retryCount >= maxRetries {
            // Give up on voice — show manual input fallback
            showRetryMessage = false
            showManualFallback = true
            speech.speak("Let's try typing instead.")
            return
        }

        showRetryMessage = true
        speech.speak("I didn't catch that. Try again.") {
            self.showRetryMessage = false
            self.configureForCurrentStep()
            self.startVoiceInput()
        }
    }

    /// Speak back the recognized answer, then advance to the next step.
    /// Mic is always killed before TTS to prevent feedback loop.
    private func speakAndAdvance(_ recognizedValue: String) {
        // Always stop listening before speaking — SpeechService.speak() also
        // does this, but we track isListeningForVoice separately in the view.
        speech.stopListening()
        isListeningForVoice = false

        speech.speak(recognizedValue) {
            guard let nextStep = self.nextStep else { return }
            withAnimation {
                self.step = nextStep
            }
        }
    }

    // MARK: - Helpers

    private func selectLocation(_ location: SavedLocation) {
        if step == .startLocation {
            startLocationName = location.name
            matchedStartLocation = location
        } else {
            endLocationName = location.name
            matchedEndLocation = location
        }
    }

    private func advanceStep() {
        if isListeningForVoice {
            speech.stopListening()
            isListeningForVoice = false
        }

        guard let nextStep else { return }
        withAnimation {
            step = nextStep
        }
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

    /// Format an odometer string with comma separators for readability.
    private func formatOdometer(_ value: String) -> String {
        if let number = Double(value) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: number)) ?? value
        }
        return value
    }

    /// Remove a trailing keyword from recognized text.
    /// e.g., "twelve thousand done" → "twelve thousand"
    private func removeTrailingKeyword(_ text: String, keyword: String) -> String {
        let lowered = text.lowercased()
        if lowered.hasSuffix(keyword) {
            let trimmed = String(text.dropLast(keyword.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? text : trimmed
        }
        return text
    }

    private func saveTrip() {
        if isListeningForVoice {
            speech.stopListening()
            isListeningForVoice = false
        }

        let trip = Trip(
            startLocationName: startLocationName,
            startOdometer: Double(startOdometer) ?? 0,
            endLocationName: endLocationName,
            businessPurpose: businessPurpose,
            category: category,
            isBusiness: isBusiness,
            isComplete: false
        )
        trip.startLocation = matchedStartLocation
        trip.endLocation = matchedEndLocation

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
