import Foundation

/// One menstrual cycle: from the start of a period to the day before the next period starts.
public struct Cycle: Identifiable, Hashable, Sendable {
    public let period: DetectedPeriod
    /// Days from this period start to the next period start. `nil` for the current, ongoing cycle.
    public let length: Int?
    /// Last day with egg-white discharge in this cycle. Used as an ovulation marker.
    public let ovulationMarker: CalendarDay?

    public init(period: DetectedPeriod, length: Int?, ovulationMarker: CalendarDay?) {
        self.period = period
        self.length = length
        self.ovulationMarker = ovulationMarker
    }

    public var id: CalendarDay { start }
    public var start: CalendarDay { period.start }
    public var isCurrent: Bool { length == nil }

    /// The day the next cycle started, if this cycle is complete.
    public var nextStart: CalendarDay? {
        length.map { start.adding(days: $0) }
    }

    /// Days from the ovulation marker to the next period, if both are known.
    public var lutealLength: Int? {
        guard let nextStart, let ovulationMarker else { return nil }
        return nextStart.days(since: ovulationMarker)
    }
}

public enum CycleHistory {
    /// Builds cycles (oldest first) from detected periods. The last cycle is the current one.
    public static func cycles(from periods: [DetectedPeriod], logs: [DayLog]) -> [Cycle] {
        let peakDays = logs
            .filter { $0.discharge?.indicatesPeakFertility == true }
            .map(\.day)
            .sorted()

        return periods.indices.map { index in
            let period = periods[index]
            let nextStart = index + 1 < periods.count ? periods[index + 1].start : nil
            let marker = peakDays.last { day in
                day > period.end && (nextStart.map { day < $0 } ?? true)
            }
            return Cycle(
                period: period,
                length: nextStart.map { $0.days(since: period.start) },
                ovulationMarker: marker
            )
        }
    }
}
