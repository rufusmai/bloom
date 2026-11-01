import SwiftUI
import BloomKit

extension CalendarDay {
    /// Start of the day in the current time zone, for display with `Date.FormatStyle`.
    var asDate: Date { date(in: .current) }

    func formatted(_ style: Date.FormatStyle) -> String {
        asDate.formatted(style)
    }

    /// e.g. "Mon, 3 Nov"
    var shortTitle: String {
        formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    /// e.g. "3 November"
    var mediumTitle: String {
        formatted(.dateTime.day().month(.wide))
    }
}

extension FlowIntensity {
    var title: LocalizedStringResource {
        switch self {
        case .spotting: "Spotting"
        case .light: "Light"
        case .medium: "Medium"
        case .heavy: "Heavy"
        }
    }

    var dropCount: Int {
        switch self {
        case .spotting: 0
        case .light: 1
        case .medium: 2
        case .heavy: 3
        }
    }

    /// Fill strength of logged period days in the calendar.
    var fillOpacity: Double {
        switch self {
        case .spotting: 0
        case .light: 0.45
        case .medium: 0.75
        case .heavy: 1
        }
    }
}

extension Symptom {
    var title: LocalizedStringResource {
        switch self {
        case .breastTenderness: "Breast tenderness"
        case .cramps: "Cramps"
        case .headache: "Headache"
        case .bloating: "Bloating"
        case .backPain: "Back pain"
        case .acne: "Acne"
        case .fatigue: "Fatigue"
        case .moodSwings: "Mood swings"
        case .nausea: "Nausea"
        case .cravings: "Cravings"
        }
    }
}

extension DischargeType {
    var title: LocalizedStringResource {
        switch self {
        case .dry: "Dry"
        case .sticky: "Sticky"
        case .creamy: "Creamy"
        case .watery: "Watery"
        case .eggWhite: "Egg white"
        case .unusual: "Unusual"
        }
    }
}

extension Protection {
    var title: LocalizedStringResource {
        switch self {
        case .protected: "Protected"
        case .unprotected: "Unprotected"
        }
    }

    var systemImage: String {
        switch self {
        case .protected: "checkmark.shield"
        case .unprotected: "shield.slash"
        }
    }
}

extension CyclePhase {
    var title: LocalizedStringResource {
        switch self {
        case .menstruation: "Period"
        case .follicular: "Follicular phase"
        case .fertile: "Fertile window"
        case .ovulation: "Ovulation day"
        case .luteal: "Luteal phase"
        case .late: "Period is late"
        case .unknown: "No data yet"
        }
    }
}

extension PredictionConfidence {
    var title: LocalizedStringResource {
        switch self {
        case .low: "Low confidence"
        case .medium: "Medium confidence"
        case .high: "High confidence"
        }
    }
}

extension CycleStatus {
    var headline: LocalizedStringResource {
        switch phase {
        case .unknown:
            return "Log your period to see predictions"
        case .menstruation:
            return "Day \(cycleDay ?? 1) of your period"
        case .late:
            return "Period \(daysLate) days late"
        case .follicular, .fertile, .ovulation, .luteal:
            switch daysUntilNextPeriod ?? 0 {
            case ...0: return "Period expected today"
            case 1: return "Period expected tomorrow"
            case let days: return "Period in \(days) days"
            }
        }
    }
}
