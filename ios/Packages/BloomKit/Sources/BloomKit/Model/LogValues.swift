import Foundation

/// How strong the bleeding is on a day.
public enum FlowIntensity: String, Codable, Sendable, CaseIterable, Comparable {
    /// Light spotting. Logged, but never starts or extends a period on its own.
    case spotting
    case light
    case medium
    case heavy

    /// Whether this day counts as a period (bleeding) day.
    public var countsAsPeriod: Bool { self != .spotting }

    private var rank: Int {
        switch self {
        case .spotting: 0
        case .light: 1
        case .medium: 2
        case .heavy: 3
        }
    }

    public static func < (lhs: FlowIntensity, rhs: FlowIntensity) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// Physical and emotional symptoms that can be logged per day.
public enum Symptom: String, Codable, Sendable, CaseIterable {
    case breastTenderness
    case cramps
    case headache
    case bloating
    case backPain
    case acne
    case fatigue
    case moodSwings
    case nausea
    case cravings
}

/// Cervical discharge observation.
public enum DischargeType: String, Codable, Sendable, CaseIterable {
    case dry
    case sticky
    case creamy
    case watery
    /// Clear and stretchy, like raw egg white. Typical around ovulation.
    case eggWhite
    case unusual

    /// Egg-white discharge is the strongest at-home sign of imminent ovulation.
    public var indicatesPeakFertility: Bool { self == .eggWhite }
}

/// Whether contraception was used.
public enum Protection: String, Codable, Sendable, CaseIterable {
    case protected
    case unprotected
}

/// A single logged sexual activity. A day can have several.
public struct SexualActivity: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var protection: Protection

    public init(id: UUID = UUID(), protection: Protection) {
        self.id = id
        self.protection = protection
    }
}
