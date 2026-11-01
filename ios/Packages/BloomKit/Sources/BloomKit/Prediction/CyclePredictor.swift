import Foundation

/// A predicted future cycle: the ovulation leading up to a period, and the period itself.
public struct PredictedCycle: Hashable, Sendable {
    public let periodStart: CalendarDay
    public let periodLength: Int
    /// ± days of uncertainty around `periodStart`.
    public let uncertainty: Int
    /// Estimated ovulation before this period.
    public let ovulation: CalendarDay

    public var periodDays: ClosedRange<CalendarDay> {
        periodStart...periodStart.adding(days: periodLength - 1)
    }

    /// The five days before ovulation, the ovulation day and the day after.
    public var fertileWindow: ClosedRange<CalendarDay> {
        ovulation.adding(days: -5)...ovulation.adding(days: 1)
    }
}

/// Prediction markers for a single calendar day.
public struct DayMarkers: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let predictedPeriod = DayMarkers(rawValue: 1 << 0)
    public static let fertile = DayMarkers(rawValue: 1 << 1)
    public static let ovulation = DayMarkers(rawValue: 1 << 2)
}

public enum CyclePhase: String, Hashable, Sendable {
    case menstruation
    case follicular
    case fertile
    case ovulation
    case luteal
    /// The period is overdue.
    case late
    /// Nothing logged yet.
    case unknown
}

/// Where today is within the cycle.
public struct CycleStatus: Hashable, Sendable {
    public let phase: CyclePhase
    /// 1-based day of the current cycle.
    public let cycleDay: Int?
    /// Days until the next predicted period start (0 = today).
    public let daysUntilNextPeriod: Int?
    /// Days the period is overdue, 0 if not late.
    public let daysLate: Int

    public static let unknown = CycleStatus(phase: .unknown, cycleDay: nil, daysUntilNextPeriod: nil, daysLate: 0)
}

/// The complete prediction result for a given day.
public struct CycleForecast: Sendable {
    public let today: CalendarDay
    public let model: LearnedCycleModel
    /// Detected cycles, oldest first. The last one is the current cycle.
    public let cycles: [Cycle]
    public let currentCycleStart: CalendarDay?
    /// Predicted remaining days of a period that is currently running.
    public let ongoingPeriodRemaining: ClosedRange<CalendarDay>?
    /// Upcoming cycles, nearest first.
    public let upcoming: [PredictedCycle]
    public let status: CycleStatus

    private let markersByDay: [CalendarDay: DayMarkers]

    init(
        today: CalendarDay,
        model: LearnedCycleModel,
        cycles: [Cycle],
        currentCycleStart: CalendarDay?,
        ongoingPeriodRemaining: ClosedRange<CalendarDay>?,
        upcoming: [PredictedCycle],
        status: CycleStatus
    ) {
        self.today = today
        self.model = model
        self.cycles = cycles
        self.currentCycleStart = currentCycleStart
        self.ongoingPeriodRemaining = ongoingPeriodRemaining
        self.upcoming = upcoming
        self.status = status

        var markers: [CalendarDay: DayMarkers] = [:]
        if let ongoingPeriodRemaining {
            for day in ongoingPeriodRemaining {
                markers[day, default: []].insert(.predictedPeriod)
            }
        }
        for cycle in upcoming {
            for day in cycle.fertileWindow {
                markers[day, default: []].insert(.fertile)
            }
            markers[cycle.ovulation, default: []].insert(.ovulation)
            for day in cycle.periodDays {
                markers[day, default: []].insert(.predictedPeriod)
            }
        }
        self.markersByDay = markers
    }

    /// Predicted markers for `day`. Logged data is not included.
    public func markers(on day: CalendarDay) -> DayMarkers {
        markersByDay[day] ?? []
    }

    public var nextPeriod: PredictedCycle? { upcoming.first }
}

/// Predicts periods, ovulation and fertile windows from logged days.
///
/// Pure and deterministic: the same logs and `today` always give the same forecast.
public struct CyclePredictor: Sendable {
    public var learner: CycleLearner
    /// How many future cycles to predict.
    public var horizon = 6

    public init(priors: CyclePriors = .default) {
        self.learner = CycleLearner(priors: priors)
    }

    /// - Parameters:
    ///   - logs: All logged days, in any order. Days after `today` are ignored.
    ///   - today: The reference day.
    ///   - lastPeriodStartHint: Used only if no period has been logged yet, e.g. from onboarding.
    public func forecast(
        logs: [DayLog],
        today: CalendarDay,
        lastPeriodStartHint: CalendarDay? = nil
    ) -> CycleForecast {
        let pastLogs = logs.filter { $0.day <= today }
        let periods = PeriodDetector.detectPeriods(in: pastLogs)
        let cycles = CycleHistory.cycles(from: periods, logs: pastLogs)
        let model = learner.learn(from: cycles, today: today)

        let periodLength = max(1, Int(model.periodLength.rounded()))
        let lutealLength = Int(model.lutealLength.rounded())

        // The period that anchors the current cycle: logged, or the onboarding hint.
        let anchor: DetectedPeriod
        let isLoggedAnchor: Bool
        if let last = periods.last {
            anchor = last
            isLoggedAnchor = true
        } else if let hint = lastPeriodStartHint, hint <= today {
            anchor = DetectedPeriod(start: hint, end: hint)
            isLoggedAnchor = false
        } else {
            return CycleForecast(
                today: today, model: model, cycles: cycles, currentCycleStart: nil,
                ongoingPeriodRemaining: nil, upcoming: [], status: .unknown
            )
        }

        // Is the period still running today?
        let expectedPeriodEnd = anchor.start.adding(days: periodLength - 1)
        let isOnPeriod: Bool
        if isLoggedAnchor {
            isOnPeriod = today.days(since: anchor.end) <= 1
                || (today <= expectedPeriodEnd && today.days(since: anchor.end) <= PeriodDetector.maxGapDays)
        } else {
            isOnPeriod = today <= expectedPeriodEnd
        }
        var ongoingRemaining: ClosedRange<CalendarDay>?
        if isOnPeriod {
            let from = max(anchor.end.adding(days: 1), today)
            if from <= expectedPeriodEnd {
                ongoingRemaining = from...expectedPeriodEnd
            }
        }

        // Next period: from the learned cycle length, or from this cycle's observed ovulation.
        var expectedNextStart = anchor.start.adding(days: Int(model.cycleLength.rounded()))
        var firstOvulation = expectedNextStart.adding(days: -lutealLength)
        if let marker = cycles.last?.ovulationMarker, cycles.last?.start == anchor.start,
           marker.days(since: anchor.start) >= 7 {
            firstOvulation = marker
            expectedNextStart = marker.adding(days: lutealLength)
        }

        var daysLate = 0
        var firstStart = expectedNextStart
        if expectedNextStart < today, !isOnPeriod {
            daysLate = today.days(since: expectedNextStart)
            firstStart = today
        }

        let upcoming = (0..<horizon).map { index -> PredictedCycle in
            let start = firstStart.adding(days: Int((model.cycleLength * Double(index)).rounded()))
            let spread = model.cycleLengthDeviation * Double(index + 1).squareRoot()
            return PredictedCycle(
                periodStart: start,
                periodLength: periodLength,
                uncertainty: min(max(Int(spread.rounded()), 1), 7),
                ovulation: index == 0 ? firstOvulation : start.adding(days: -lutealLength)
            )
        }

        let next = upcoming[0]
        let phase: CyclePhase
        if isOnPeriod {
            phase = .menstruation
        } else if daysLate > 0 {
            phase = .late
        } else if today == next.ovulation {
            phase = .ovulation
        } else if next.fertileWindow.contains(today) {
            phase = .fertile
        } else if today < next.fertileWindow.lowerBound {
            phase = .follicular
        } else {
            phase = .luteal
        }

        let status = CycleStatus(
            phase: phase,
            cycleDay: today.days(since: anchor.start) + 1,
            daysUntilNextPeriod: next.periodStart.days(since: today),
            daysLate: daysLate
        )

        return CycleForecast(
            today: today,
            model: model,
            cycles: cycles,
            currentCycleStart: anchor.start,
            ongoingPeriodRemaining: ongoingRemaining,
            upcoming: upcoming,
            status: status
        )
    }
}
