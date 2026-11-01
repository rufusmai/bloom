import BloomKit

extension CalendarDay {
    static func d(_ iso: String) -> CalendarDay {
        guard let day = CalendarDay(iso) else { fatalError("Invalid test date \(iso)") }
        return day
    }
}

/// Builds a history of periods: one period per start, each `periodLength` days of `.medium` flow.
func history(
    firstStart: CalendarDay,
    cycleLengths: [Int],
    periodLength: Int = 5
) -> (logs: [DayLog], starts: [CalendarDay]) {
    var starts = [firstStart]
    for length in cycleLengths {
        starts.append(starts[starts.count - 1].adding(days: length))
    }
    let logs = starts.flatMap { start in
        (0..<periodLength).map { DayLog(day: start.adding(days: $0), flow: .medium) }
    }
    return (logs, starts)
}
