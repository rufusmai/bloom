import Foundation

/// A period detected from logged bleeding days.
public struct DetectedPeriod: Hashable, Sendable {
    /// First bleeding day.
    public let start: CalendarDay
    /// Last logged bleeding day.
    public let end: CalendarDay

    public init(start: CalendarDay, end: CalendarDay) {
        self.start = start
        self.end = end
    }

    /// Number of days from the first to the last bleeding day (inclusive).
    public var length: Int { end.days(since: start) + 1 }

    public func contains(_ day: CalendarDay) -> Bool {
        (start...end).contains(day)
    }
}

/// Turns individual bleeding days into periods.
public enum PeriodDetector {
    /// Up to this many days without logged bleeding still belong to the same period.
    /// People often forget to log a day in the middle of their period.
    public static let maxGapDays = 2

    /// Bleeding that starts sooner than this after the previous period start is treated
    /// as intermenstrual bleeding, not as a new period.
    public static let minimumCycleLength = 15

    /// Detects periods in `logs` (any order). Spotting is ignored.
    public static func detectPeriods(in logs: some Sequence<DayLog>) -> [DetectedPeriod] {
        let bleedingDays = Set(logs.lazy.filter(\.isBleeding).map(\.day)).sorted()

        var episodes: [DetectedPeriod] = []
        for day in bleedingDays {
            if let last = episodes.last, day.days(since: last.end) <= maxGapDays + 1 {
                episodes[episodes.count - 1] = DetectedPeriod(start: last.start, end: day)
            } else {
                episodes.append(DetectedPeriod(start: day, end: day))
            }
        }

        var periods: [DetectedPeriod] = []
        for episode in episodes {
            if let last = periods.last, episode.start.days(since: last.start) < minimumCycleLength {
                continue
            }
            periods.append(episode)
        }
        return periods
    }
}
