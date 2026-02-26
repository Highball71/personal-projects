import SwiftUI
import SwiftData
import Speech

/// Determines which phase of the trip the voice flow handles.
enum TripFlowMode {
    /// Start a new trip: asks location + odometer, then auto-confirms.
    case startTrip
    /// End an existing in-progress trip: asks destination + odometer + purpose, then confirms.
    case endTrip(Trip)
}

/// The voice-first conversational trip logging flow, split into two phases:
///
/// **Start Trip** (2 questions + auto-confirm):
/// 1. "Where are you starting from?" → location match
/// 2. "What's your odometer reading?" → OdometerParser
/// 3. Auto-confirm: speaks summary, saves in-progress trip, dismisses
///
/// **End Trip** (3 questions + voice confirm):
/// 1. "Where did you end up?" → location match
/// 2. "What's your ending odometer?" → OdometerParser, validates > start odometer
/// 3. "What was the purpose of this trip?" → category match
/// 4. Confirm: summary + yes/no voice confirmation
///
/// Fully hands-free: the app speaks each question aloud, listens for the verbal
/// response, reads it back for confirmation, and auto-advances to the next step.
struct VoiceTripFlowView: View {
    let mode: TripFlowMode

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
    @State private var endOdometer = ""
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

    // Guards against stale recognition callbacks from a previous step.
    @State private var stepGeneration = 0

    // Prevents double-fire from silence timer + recognition task
    @State private var resultAccepted = false

    enum FlowStep {
        // Start Trip steps
        case startLocation
        case startOdometer
        case startConfirm
        // End Trip steps
        case endDestination
        case endOdometer
        case endPurpose
        case endConfirm
    }

    init(mode: TripFlowMode = .startTrip) {
        self.mode = mode
        // Set initial step based on mode — @State defaults are overridden in onAppear
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
                    Text("\(stepNumber)/\(totalSteps)")
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
                if step == .endConfirm {
                    endConfirmationView
                } else if step == .startConfirm {
                    startConfirmationView
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
                if step == .startLocation || step == .endDestination {
                    locationButtons
                } else if step == .endPurpose {
                    purposeButtons
                }

                // Minimal action area — voice mic toggle only (for manual override)
                HStack(spacing: 16) {
                    if step == .startConfirm {
                        // Start Trip auto-confirm — just a manual save button as backup
                        Button { saveStartTrip() } label: {
                            Text("Save & Go")
                                .font(.title2.bold())
                                .foregroundStyle(stepColor)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                        }
                    } else if step == .endConfirm {
                        // End Trip confirm: save or redo buttons
                        Button { saveEndTrip() } label: {
                            Text("Save Trip")
                                .font(.title2.bold())
                                .foregroundStyle(stepColor)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                        }
                    } else {
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
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                // Manual text input — still available as fallback
                if step != .startConfirm && step != .endConfirm {
                    TextField("Or type here...", text: currentAnswerBinding)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .keyboardType(isOdometerStep ? .decimalPad : .default)
                        .onSubmit {
                            if !currentAnswer.isEmpty {
                                speech.stopListening()
                                speech.stopSpeaking()
                                isListeningForVoice = false
                                retryCount = 0
                                showManualFallback = false
                                showRetryMessage = false
                                resultAccepted = true
                                advanceStep()
                            }
                        }
                }
            }
            .padding()
        }
        .onAppear {
            // Set initial step based on mode
            switch mode {
            case .startTrip:
                step = .startLocation
            case .endTrip(let trip):
                step = .endDestination
                // Pre-fill start data from the existing trip
                startLocationName = trip.startLocationName
                startOdometer = trip.startOdometer > 0 ? String(Int(trip.startOdometer)) : ""
                matchedStartLocation = trip.startLocation
            }
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
            showRetryMessage = false
            resultAccepted = false
            isListeningForVoice = false
            beginStep()
        }
    }

    // MARK: - Computed Helpers

    private var isOdometerStep: Bool {
        step == .startOdometer || step == .endOdometer
    }

    private var totalSteps: Int {
        switch mode {
        case .startTrip: return 2
        case .endTrip: return 3
        }
    }

    // MARK: - Display

    private var displayText: String {
        if isListeningForVoice && !speech.recognizedText.isEmpty {
            if isOdometerStep {
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
        case .startConfirm: return .green
        case .endDestination: return .teal
        case .endOdometer: return .indigo
        case .endPurpose: return .orange
        case .endConfirm: return .green
        }
    }

    private var stepLabel: String {
        switch step {
        case .startLocation: return "START LOCATION"
        case .startOdometer: return "ODOMETER"
        case .startConfirm: return "CONFIRM"
        case .endDestination: return "DESTINATION"
        case .endOdometer: return "ODOMETER"
        case .endPurpose: return "PURPOSE"
        case .endConfirm: return "CONFIRM"
        }
    }

    private var stepNumber: Int {
        switch step {
        case .startLocation: return 1
        case .startOdometer: return 2
        case .startConfirm: return 2 // auto-confirm doesn't count as a user step
        case .endDestination: return 1
        case .endOdometer: return 2
        case .endPurpose: return 3
        case .endConfirm: return 3 // confirm doesn't count as a user step
        }
    }

    private var questionText: String {
        switch step {
        case .startLocation: return "Where are you starting from?"
        case .startOdometer: return "What's your odometer reading?"
        case .startConfirm: return "You're all set!"
        case .endDestination: return "Where did you end up?"
        case .endOdometer: return "What's your ending odometer?"
        case .endPurpose: return "What was the purpose of this trip?"
        case .endConfirm: return "Does this look right?"
        }
    }

    private var currentAnswer: String {
        switch step {
        case .startLocation: return startLocationName
        case .startOdometer: return startOdometer
        case .startConfirm: return ""
        case .endDestination: return endLocationName
        case .endOdometer: return endOdometer
        case .endPurpose: return businessPurpose
        case .endConfirm: return ""
        }
    }

    private var currentAnswerBinding: Binding<String> {
        switch step {
        case .startLocation: return $startLocationName
        case .startOdometer: return $startOdometer
        case .startConfirm: return .constant("")
        case .endDestination: return $endLocationName
        case .endOdometer: return $endOdometer
        case .endPurpose: return $businessPurpose
        case .endConfirm: return .constant("")
        }
    }

    // MARK: - Quick-Pick Views

    private var locationButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(locations.prefix(6)) { location in
                    Button {
                        selectLocation(location)
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

    private var startConfirmationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            confirmRow("From", startLocationName)
            confirmRow("Odometer", formatOdometer(startOdometer))
        }
        .padding(20)
        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var endConfirmationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            confirmRow("From", startLocationName)
            confirmRow("To", endLocationName)
            confirmRow("Miles", computedMilesString)
            confirmRow("Purpose", businessPurpose)
            confirmRow("Category", category.rawValue)
        }
        .padding(20)
        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    /// Computed miles for the end-trip confirmation display.
    private var computedMilesString: String {
        let start = Double(startOdometer) ?? 0
        let end = Double(endOdometer) ?? 0
        let miles = end - start
        return miles > 0 ? String(format: "%.0f", miles) : "—"
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
        speech.contextualStrings = locations.flatMap { loc in
            [loc.name, loc.shortName].filter { !$0.isEmpty }
        }
        speech.contextualStrings += TripCategory.allCases.map(\.rawValue)
    }

    private func installStepCallbacks() {
        let gen = stepGeneration
        speech.onListeningStopped = { [self] finalText in
            guard gen == self.stepGeneration, !self.resultAccepted else { return }
            handleRecognitionResult(finalText)
        }
        speech.onKeywordDetected = { [self] keyword in
            guard gen == self.stepGeneration, !self.resultAccepted else { return }
            handleKeyword(keyword)
        }
    }

    // MARK: - Flow Control

    private func beginStep() {
        guard !stepInitiated else { return }
        stepInitiated = true
        showRetryMessage = false

        stepGeneration += 1
        installStepCallbacks()

        if step == .startConfirm {
            // Auto-confirm for Start Trip: speak summary and save immediately
            speakStartSummaryAndSave()
        } else if step == .endConfirm {
            speakEndSummaryAndListen()
        } else {
            configureForCurrentStep()
            speech.speak(questionText) {
                startVoiceInput()
            }
        }
    }

    private func configureForCurrentStep() {
        switch step {
        case .startOdometer, .endOdometer:
            speech.minimumLength = 4
            speech.silenceTimeout = 5.0
        case .startLocation, .endDestination:
            speech.minimumLength = 0
            speech.silenceTimeout = 3.0
        case .endPurpose:
            speech.minimumLength = 0
            speech.silenceTimeout = 3.0
        case .startConfirm, .endConfirm:
            speech.minimumLength = 0
            speech.silenceTimeout = 3.0
        }
    }

    /// Start Trip auto-confirm: speak summary, save, dismiss.
    private func speakStartSummaryAndSave() {
        let odo = formatOdometer(startOdometer)
        let summary = "Starting from \(startLocationName), odometer \(odo). Drive safe!"

        speech.speak(summary) {
            self.saveStartTrip()
        }
    }

    /// End Trip confirm: speak summary and listen for yes/no.
    private func speakEndSummaryAndListen() {
        let start = Double(startOdometer) ?? 0
        let end = Double(endOdometer) ?? 0
        let miles = Int(end - start)
        let summary = "\(startLocationName) to \(endLocationName), \(miles) miles, \(businessPurpose). Save this trip?"

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
            isListeningForVoice = false
            speech.stopListening()
            let text = speech.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                handleRecognitionResult(text)
            }
        } else {
            retryCount = 0
            showManualFallback = false
            resultAccepted = false
            configureForCurrentStep()
            startVoiceInput()
        }
    }

    // MARK: - Recognition Handling

    private func handleRecognitionResult(_ text: String) {
        isListeningForVoice = false

        guard !text.isEmpty else {
            retryCurrentStep()
            return
        }

        resultAccepted = true

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
            guard let parsed = OdometerParser.parse(text) else {
                resultAccepted = false
                speech.speak("I heard \(text), but that seems too short for an odometer reading. Try again.") {
                    self.configureForCurrentStep()
                    self.startVoiceInput()
                }
                return
            }
            startOdometer = parsed
            speakAndAdvance(formatOdometer(parsed))

        case .endDestination:
            if let match = matchLocation(text) {
                selectLocation(match)
                speakAndAdvance(match.voiceName)
            } else {
                endLocationName = text
                speakAndAdvance(text)
            }

        case .endOdometer:
            guard let parsed = OdometerParser.parse(text) else {
                resultAccepted = false
                speech.speak("I heard \(text), but that seems too short for an odometer reading. Try again.") {
                    self.configureForCurrentStep()
                    self.startVoiceInput()
                }
                return
            }
            // Validate end odometer > start odometer
            let startValue = Double(startOdometer) ?? 0
            let endValue = Double(parsed) ?? 0
            if endValue <= startValue {
                resultAccepted = false
                let startFormatted = formatOdometer(startOdometer)
                speech.speak("Your ending odometer needs to be higher than \(startFormatted). Try again.") {
                    self.configureForCurrentStep()
                    self.startVoiceInput()
                }
                return
            }
            endOdometer = parsed
            speakAndAdvance(formatOdometer(parsed))

        case .endPurpose:
            businessPurpose = text
            for cat in TripCategory.allCases {
                if text.localizedCaseInsensitiveContains(cat.rawValue) {
                    category = cat
                    break
                }
            }
            speakAndAdvance(businessPurpose)

        case .startConfirm:
            // Auto-confirm — shouldn't get recognition results here
            break

        case .endConfirm:
            handleEndConfirmation(text)
        }
    }

    private func handleKeyword(_ keyword: String) {
        switch keyword {
        case "done", "save":
            if step == .endConfirm {
                isListeningForVoice = false
                speech.stopListening()
                saveEndTrip()
            } else {
                isListeningForVoice = false
                speech.stopListening()
                let text = speech.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleaned = removeTrailingKeyword(text, keyword: keyword)
                handleRecognitionResult(cleaned)
            }
        case "yes", "correct":
            if step == .endConfirm {
                isListeningForVoice = false
                speech.stopListening()
                saveEndTrip()
            }
        case "no", "cancel":
            if step == .endConfirm {
                isListeningForVoice = false
                speech.stopListening()
                speech.speak("OK, let's start over.") {
                    withAnimation {
                        self.step = .endDestination
                    }
                    self.endLocationName = ""
                    self.endOdometer = ""
                    self.businessPurpose = ""
                }
            }
        default:
            break
        }
    }

    private func handleEndConfirmation(_ text: String) {
        let lowered = text.lowercased()
        if lowered.contains("yes") || lowered.contains("save") || lowered.contains("correct") {
            saveEndTrip()
        } else if lowered.contains("no") || lowered.contains("cancel") || lowered.contains("redo") {
            speech.speak("OK, let's start over.") {
                withAnimation {
                    self.step = .endDestination
                }
                self.endLocationName = ""
                self.endOdometer = ""
                self.businessPurpose = ""
            }
        } else {
            speech.speak("Sorry, say yes to save or no to start over.") {
                self.startVoiceInput(taskHint: .confirmation)
            }
        }
    }

    private func retryCurrentStep() {
        retryCount += 1

        if retryCount >= maxRetries {
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

    private func speakAndAdvance(_ recognizedValue: String) {
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
        switch step {
        case .startLocation:
            startLocationName = location.name
            matchedStartLocation = location
        case .endDestination:
            endLocationName = location.name
            matchedEndLocation = location
        default:
            break
        }
    }

    private func advanceStep() {
        speech.stopListening()
        speech.stopSpeaking()
        isListeningForVoice = false
        retryCount = 0
        showManualFallback = false
        showRetryMessage = false
        resultAccepted = false

        guard let nextStep else { return }
        withAnimation {
            step = nextStep
        }
    }

    private var nextStep: FlowStep? {
        switch step {
        // Start Trip flow
        case .startLocation: return .startOdometer
        case .startOdometer: return .startConfirm
        case .startConfirm: return nil
        // End Trip flow
        case .endDestination: return .endOdometer
        case .endOdometer: return .endPurpose
        case .endPurpose: return .endConfirm
        case .endConfirm: return nil
        }
    }

    private func matchLocation(_ text: String) -> SavedLocation? {
        let lowered = text.lowercased()
        return locations.first { location in
            lowered.contains(location.shortName.lowercased()) ||
            lowered.contains(location.name.lowercased()) ||
            location.shortName.lowercased().contains(lowered) ||
            location.name.lowercased().contains(lowered)
        }
    }

    private func formatOdometer(_ value: String) -> String {
        if let number = Double(value) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: number)) ?? value
        }
        return value
    }

    private func removeTrailingKeyword(_ text: String, keyword: String) -> String {
        let lowered = text.lowercased()
        if lowered.hasSuffix(keyword) {
            let trimmed = String(text.dropLast(keyword.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? text : trimmed
        }
        return text
    }

    // MARK: - Save Logic

    /// Save a new in-progress trip (Start Trip flow).
    /// Sets start location + odometer, leaves end fields empty, isComplete = false.
    private func saveStartTrip() {
        if isListeningForVoice {
            speech.stopListening()
            isListeningForVoice = false
        }

        let trip = Trip(
            startLocationName: startLocationName,
            startOdometer: Double(startOdometer) ?? 0,
            isBusiness: isBusiness,
            isComplete: false
        )
        trip.startLocation = matchedStartLocation
        matchedStartLocation?.recordUsage()

        modelContext.insert(trip)
        dismiss()
    }

    /// Complete an existing in-progress trip (End Trip flow).
    /// Fills in destination, end odometer, purpose, category, and marks complete.
    private func saveEndTrip() {
        if isListeningForVoice {
            speech.stopListening()
            isListeningForVoice = false
        }

        guard case .endTrip(let trip) = mode else { return }

        trip.endLocationName = endLocationName
        trip.endOdometer = Double(endOdometer) ?? 0
        trip.businessPurpose = businessPurpose
        trip.category = category
        trip.isBusiness = isBusiness
        trip.endLocation = matchedEndLocation
        trip.isComplete = true

        matchedEndLocation?.recordUsage()

        speech.speak("Trip saved!") {
            dismiss()
        }
    }

    private func cancelFlow() {
        speech.stopListening()
        speech.stopSpeaking()
        dismiss()
    }
}
