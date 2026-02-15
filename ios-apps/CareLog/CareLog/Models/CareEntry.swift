import SwiftUI
import SwiftData
import Foundation

// MARK: - Entry Type Enum
enum EntryType: String, Codable, CaseIterable, Identifiable {
    case vitals = "Vitals"
    case meal = "Meal"
    case medication = "Medication"
    case activity = "Activity"
    case mood = "Mood/Behavior"
    case bowelBladder = "Bowel/Bladder"
    case note = "Note"
    case woundCare = "Wound Care"
    case therapy = "Therapy"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .vitals: return "heart.text.clipboard"
        case .meal: return "fork.knife"
        case .medication: return "pill.fill"
        case .activity: return "figure.walk"
        case .mood: return "face.smiling"
        case .bowelBladder: return "drop.fill"
        case .note: return "note.text"
        case .woundCare: return "bandage.fill"
        case .therapy: return "hands.clap.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .vitals: return .red
        case .meal: return .orange
        case .medication: return .purple
        case .activity: return .green
        case .mood: return .yellow
        case .bowelBladder: return .cyan
        case .note: return .gray
        case .woundCare: return .pink
        case .therapy: return .teal
        }
    }
}

// MARK: - Vitals Data
struct VitalsData: Codable, Equatable {
    var bpSystolic: Int?
    var bpDiastolic: Int?
    var pulse: Int?
    var temperature: Double?
    var o2Saturation: Int?
    var weight: Double?
    var bloodSugar: Int?
    
    var bpString: String? {
        guard let sys = bpSystolic, let dia = bpDiastolic else { return nil }
        return "\(sys)/\(dia)"
    }
    
    var summary: String {
        var parts: [String] = []
        if let bp = bpString { parts.append("BP \(bp)") }
        if let p = pulse { parts.append("P \(p)") }
        if let t = temperature { parts.append("T \(String(format: "%.1f", t))°") }
        if let o2 = o2Saturation { parts.append("O₂ \(o2)%") }
        if let w = weight { parts.append("Wt \(String(format: "%.1f", w)) lbs") }
        if let bs = bloodSugar { parts.append("BS \(bs)") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Meal Data
enum MealType: String, Codable, CaseIterable {
    case breakfast = "Breakfast"
    case morningSnack = "AM Snack"
    case lunch = "Lunch"
    case afternoonSnack = "PM Snack"
    case dinner = "Dinner"
    case eveningSnack = "Evening Snack"
    case supplement = "Supplement/Ensure"
}

enum IntakeAmount: String, Codable, CaseIterable {
    case none = "Refused"
    case poor = "Poor (<25%)"
    case fair = "Fair (25-50%)"
    case good = "Good (50-75%)"
    case excellent = "Excellent (>75%)"
    case all = "All (100%)"
}

struct MealData: Codable, Equatable {
    var mealType: MealType
    var description: String
    var intake: IntakeAmount
    var fluidOz: Int?
    
    var summary: String {
        var s = "\(mealType.rawValue): \(description)"
        s += " — \(intake.rawValue)"
        if let fl = fluidOz { s += ", \(fl) oz fluids" }
        return s
    }
}

// MARK: - Medication Data
struct MedicationData: Codable, Equatable {
    var name: String
    var dose: String
    var route: String // oral, topical, injection, inhaled, etc.
    var given: Bool
    var refusedReason: String?
    
    var summary: String {
        if given {
            return "\(name) \(dose) (\(route)) — Given"
        } else {
            return "\(name) \(dose) (\(route)) — Refused\(refusedReason.map { ": \($0)" } ?? "")"
        }
    }
}

// MARK: - Activity Data
struct ActivityData: Codable, Equatable {
    var description: String
    var durationMinutes: Int?
    var assistanceLevel: String // Independent, Supervised, Minimal Assist, Moderate Assist, Maximum Assist, Dependent
    
    var summary: String {
        var s = description
        if let dur = durationMinutes { s += " (\(dur) min)" }
        s += " — \(assistanceLevel)"
        return s
    }
}

// MARK: - Mood/Behavior Data
enum MoodLevel: String, Codable, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case agitated = "Agitated"
    case withdrawn = "Withdrawn"
    case confused = "Confused"
    case anxious = "Anxious"
}

struct MoodData: Codable, Equatable {
    var mood: MoodLevel
    var cooperative: Bool
    var notes: String
    
    var summary: String {
        var s = "Mood: \(mood.rawValue)"
        s += cooperative ? ", Cooperative" : ", Non-cooperative"
        if !notes.isEmpty { s += " — \(notes)" }
        return s
    }
}

// MARK: - Bowel/Bladder Data
struct BowelBladderData: Codable, Equatable {
    var bowelMovement: Bool
    var bowelDescription: String? // Normal, Loose, Hard, Diarrhea, Constipated
    var urineOutput: String? // Normal, Decreased, Increased, Incontinent
    var notes: String
    
    var summary: String {
        var parts: [String] = []
        if bowelMovement {
            parts.append("BM: \(bowelDescription ?? "Yes")")
        } else {
            parts.append("No BM")
        }
        if let urine = urineOutput { parts.append("Urine: \(urine)") }
        if !notes.isEmpty { parts.append(notes) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Care Entry Model
@Model
final class CareEntry {
    var id: UUID
    var patient: Patient?
    var timestamp: Date
    var entryTypeRaw: String
    var dataJSON: Data // Encoded entry data
    var noteText: String
    var photoData: [Data] // Stored photo JPEGs
    var fromTemplate: String? // Template name if created from template
    
    var entryType: EntryType {
        get { EntryType(rawValue: entryTypeRaw) ?? .note }
        set { entryTypeRaw = newValue.rawValue }
    }
    
    init(patient: Patient, entryType: EntryType, noteText: String = "") {
        self.id = UUID()
        self.patient = patient
        self.timestamp = Date()
        self.entryTypeRaw = entryType.rawValue
        self.dataJSON = Data()
        self.noteText = noteText
        self.photoData = []
    }
    
    // MARK: - Typed Data Accessors
    
    func getVitals() -> VitalsData? {
        guard entryType == .vitals else { return nil }
        return try? JSONDecoder().decode(VitalsData.self, from: dataJSON)
    }
    
    func setVitals(_ data: VitalsData) {
        self.dataJSON = (try? JSONEncoder().encode(data)) ?? Data()
    }
    
    func getMeal() -> MealData? {
        guard entryType == .meal else { return nil }
        return try? JSONDecoder().decode(MealData.self, from: dataJSON)
    }
    
    func setMeal(_ data: MealData) {
        self.dataJSON = (try? JSONEncoder().encode(data)) ?? Data()
    }
    
    func getMedication() -> MedicationData? {
        guard entryType == .medication else { return nil }
        return try? JSONDecoder().decode(MedicationData.self, from: dataJSON)
    }
    
    func setMedication(_ data: MedicationData) {
        self.dataJSON = (try? JSONEncoder().encode(data)) ?? Data()
    }
    
    func getActivity() -> ActivityData? {
        guard entryType == .activity else { return nil }
        return try? JSONDecoder().decode(ActivityData.self, from: dataJSON)
    }
    
    func setActivity(_ data: ActivityData) {
        self.dataJSON = (try? JSONEncoder().encode(data)) ?? Data()
    }
    
    func getMood() -> MoodData? {
        guard entryType == .mood else { return nil }
        return try? JSONDecoder().decode(MoodData.self, from: dataJSON)
    }
    
    func setMood(_ data: MoodData) {
        self.dataJSON = (try? JSONEncoder().encode(data)) ?? Data()
    }
    
    func getBowelBladder() -> BowelBladderData? {
        guard entryType == .bowelBladder else { return nil }
        return try? JSONDecoder().decode(BowelBladderData.self, from: dataJSON)
    }
    
    func setBowelBladder(_ data: BowelBladderData) {
        self.dataJSON = (try? JSONEncoder().encode(data)) ?? Data()
    }
    
    // MARK: - Summary for display
    var summary: String {
        switch entryType {
        case .vitals: return getVitals()?.summary ?? noteText
        case .meal: return getMeal()?.summary ?? noteText
        case .medication: return getMedication()?.summary ?? noteText
        case .activity: return getActivity()?.summary ?? noteText
        case .mood: return getMood()?.summary ?? noteText
        case .bowelBladder: return getBowelBladder()?.summary ?? noteText
        case .note: return noteText
        case .woundCare: return noteText
        case .therapy: return noteText
        }
    }
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}
