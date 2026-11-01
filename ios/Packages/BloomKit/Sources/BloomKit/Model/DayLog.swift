import Foundation

/// Everything logged for one calendar day. This is the input for predictions.
public struct DayLog: Identifiable, Hashable, Codable, Sendable {
    public var day: CalendarDay
    public var flow: FlowIntensity?
    public var symptoms: Set<Symptom>
    public var discharge: DischargeType?
    public var sexualActivities: [SexualActivity]
    public var note: String

    public var id: CalendarDay { day }

    public init(
        day: CalendarDay,
        flow: FlowIntensity? = nil,
        symptoms: Set<Symptom> = [],
        discharge: DischargeType? = nil,
        sexualActivities: [SexualActivity] = [],
        note: String = ""
    ) {
        self.day = day
        self.flow = flow
        self.symptoms = symptoms
        self.discharge = discharge
        self.sexualActivities = sexualActivities
        self.note = note
    }

    /// Whether this day counts as a period day (spotting does not).
    public var isBleeding: Bool { flow?.countsAsPeriod == true }

    public var isEmpty: Bool {
        flow == nil
            && symptoms.isEmpty
            && discharge == nil
            && sexualActivities.isEmpty
            && note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
