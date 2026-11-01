import Foundation
import BloomKit

extension DayEntry {
    convenience init(log: DayLog) {
        self.init(day: log.day.isoString)
        apply(log)
    }

    /// The entry as a BloomKit value. `nil` only if the stored day is corrupt.
    var dayLog: DayLog? {
        guard let calendarDay = CalendarDay(day) else { return nil }
        return DayLog(
            day: calendarDay,
            flow: flowRaw.flatMap(FlowIntensity.init(rawValue:)),
            symptoms: Set(symptomsRaw.compactMap(Symptom.init(rawValue:))),
            discharge: dischargeRaw.flatMap(DischargeType.init(rawValue:)),
            sexualActivities: Self.decodeActivities(sexualActivitiesData),
            note: note
        )
    }

    /// Overwrites all logged values with `log`. The day itself is not changed.
    func apply(_ log: DayLog) {
        flowRaw = log.flow?.rawValue
        symptomsRaw = log.symptoms.map(\.rawValue).sorted()
        dischargeRaw = log.discharge?.rawValue
        sexualActivitiesData = log.sexualActivities.isEmpty ? nil : try? JSONEncoder().encode(log.sexualActivities)
        note = log.note
        updatedAt = .now
    }

    private static func decodeActivities(_ data: Data?) -> [SexualActivity] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([SexualActivity].self, from: data)) ?? []
    }
}
