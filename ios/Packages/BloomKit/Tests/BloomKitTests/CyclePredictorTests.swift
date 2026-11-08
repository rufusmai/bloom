import Testing
@testable import BloomKit

@Suite("CyclePredictor")
struct CyclePredictorTests {
    let predictor = CyclePredictor()

    @Test func withoutDataThereIsNoForecast() {
        let forecast = predictor.forecast(logs: [], today: .d("2026-11-01"))
        #expect(forecast.status == .unknown)
        #expect(forecast.upcoming.isEmpty)
        #expect(forecast.model.cycleLength == 28)
        #expect(forecast.model.periodLength == 5)
        #expect(forecast.model.confidence == .low)
    }

    @Test func onboardingHintAnchorsTheFirstPrediction() {
        let today = CalendarDay.d("2026-11-01")
        let hint = today.adding(days: -10)
        let forecast = predictor.forecast(logs: [], today: today, lastPeriodStartHint: hint)
        #expect(forecast.nextPeriod?.periodStart == hint.adding(days: 28))
        #expect(forecast.status.cycleDay == 11)
        #expect(forecast.status.daysUntilNextPeriod == 18)
        #expect(forecast.model.confidence == .low)
    }

    @Test func hintOfTodayMarksTodayAsPeriod() {
        let today = CalendarDay.d("2026-11-01")
        let forecast = predictor.forecast(logs: [], today: today, lastPeriodStartHint: today)
        #expect(forecast.status.phase == .menstruation)
        #expect(forecast.status.cycleDay == 1)
        #expect(forecast.ongoingPeriodRemaining == today...today.adding(days: 4))
        #expect(forecast.markers(on: today).contains(.predictedPeriod))
        #expect(!forecast.markers(on: today.adding(days: -1)).contains(.predictedPeriod))
    }

    @Test func hintFromEarlierMarksOnlyTheRestOfThePeriod() {
        let today = CalendarDay.d("2026-11-01")
        let forecast = predictor.forecast(logs: [], today: today, lastPeriodStartHint: today.adding(days: -2))
        #expect(forecast.ongoingPeriodRemaining == today...today.adding(days: 2))
        #expect(!forecast.markers(on: today.adding(days: -1)).contains(.predictedPeriod))
    }

    @Test func hintIsIgnoredOnceAPeriodIsLogged() {
        let (logs, starts) = history(firstStart: .d("2026-10-10"), cycleLengths: [])
        let forecast = predictor.forecast(logs: logs, today: .d("2026-10-20"), lastPeriodStartHint: .d("2026-10-01"))
        #expect(forecast.currentCycleStart == starts[0])
    }

    @Test func regularCyclesArePredictedExactly() {
        let (logs, starts) = history(firstStart: .d("2026-03-01"), cycleLengths: Array(repeating: 28, count: 6))
        let lastStart = starts.last!
        let forecast = predictor.forecast(logs: logs, today: lastStart.adding(days: 10))

        #expect(abs(forecast.model.cycleLength - 28) < 0.01)
        #expect(forecast.model.cyclesUsed == 6)
        #expect(forecast.model.confidence == .high)
        #expect(forecast.nextPeriod?.periodStart == lastStart.adding(days: 28))
        #expect(forecast.nextPeriod?.uncertainty == 1)
        #expect(forecast.upcoming.count == 6)
        #expect(forecast.upcoming[1].periodStart == lastStart.adding(days: 56))
    }

    @Test func ovulationAndFertileWindowPrecedeThePeriod() throws {
        let (logs, starts) = history(firstStart: .d("2026-03-01"), cycleLengths: Array(repeating: 28, count: 6))
        let forecast = predictor.forecast(logs: logs, today: starts.last!.adding(days: 3))
        let next = try #require(forecast.nextPeriod)

        #expect(next.ovulation == next.periodStart.adding(days: -14))
        #expect(next.fertileWindow == next.ovulation.adding(days: -5)...next.ovulation.adding(days: 1))
        #expect(forecast.markers(on: next.ovulation) == [.ovulation, .fertile])
        #expect(forecast.markers(on: next.periodStart).contains(.predictedPeriod))
        #expect(forecast.markers(on: next.periodStart.adding(days: 4)).contains(.predictedPeriod))
        #expect(forecast.markers(on: next.periodStart.adding(days: 5)).isEmpty)
    }

    @Test func learningFollowsAChangeInCycleLength() {
        let lengths = Array(repeating: 28, count: 6) + Array(repeating: 32, count: 6)
        let (logs, starts) = history(firstStart: .d("2025-06-01"), cycleLengths: lengths)
        let forecast = predictor.forecast(logs: logs, today: starts.last!.adding(days: 2))

        #expect(forecast.model.cycleLength > 30.5)
        #expect(forecast.model.cycleLength < 32)
        #expect(forecast.nextPeriod?.periodStart == starts.last!.adding(days: 31))
    }

    @Test func recentCyclesWeighMoreThanOldOnes() {
        let (logs, starts) = history(firstStart: .d("2026-01-01"), cycleLengths: [26, 26, 26, 30, 30, 30])
        let forecast = predictor.forecast(logs: logs, today: starts.last!.adding(days: 1))
        #expect(forecast.model.cycleLength > 28)
    }

    @Test func outliersAreIgnored() {
        let (logs, starts) = history(firstStart: .d("2026-01-01"), cycleLengths: [28, 28, 29, 28, 56, 28, 27, 28])
        let forecast = predictor.forecast(logs: logs, today: starts.last!.adding(days: 1))

        #expect(forecast.model.excludedCycleStarts == [starts[4]])
        #expect(forecast.model.cyclesUsed == 7)
        #expect(abs(forecast.model.cycleLength - 28) < 0.5)
    }

    @Test func implausibleCyclesAreIgnored() {
        let (logs, starts) = history(firstStart: .d("2026-01-01"), cycleLengths: [28, 90, 28])
        let forecast = predictor.forecast(logs: logs, today: starts.last!.adding(days: 1))
        #expect(forecast.model.excludedCycleStarts == [starts[1]])
        #expect(forecast.model.cyclesUsed == 2)
    }

    @Test func periodLengthIsLearned() {
        let (logs, starts) = history(firstStart: .d("2026-01-01"), cycleLengths: Array(repeating: 28, count: 6), periodLength: 3)
        let forecast = predictor.forecast(logs: logs, today: starts.last!.adding(days: 10))
        #expect(Int(forecast.model.periodLength.rounded()) == 3)
        #expect(forecast.nextPeriod?.periodLength == 3)
    }

    @Test func lutealPhaseIsLearnedFromEggWhiteDischarge() throws {
        var (logs, starts) = history(firstStart: .d("2026-01-01"), cycleLengths: Array(repeating: 30, count: 6))
        for start in starts.dropLast() {
            // Peak discharge on cycle day 19 → 12 days before the next period.
            logs.append(DayLog(day: start.adding(days: 18), discharge: .eggWhite))
        }
        let forecast = predictor.forecast(logs: logs, today: starts.last!.adding(days: 3))
        let next = try #require(forecast.nextPeriod)

        #expect(forecast.model.lutealObservations == 6)
        #expect(Int(forecast.model.lutealLength.rounded()) == 12)
        #expect(next.ovulation == next.periodStart.adding(days: -12))
    }

    @Test func observedOvulationInCurrentCycleMovesTheNextPeriod() {
        var (logs, starts) = history(firstStart: .d("2026-01-01"), cycleLengths: Array(repeating: 28, count: 6))
        let marker = starts.last!.adding(days: 18)
        logs.append(DayLog(day: marker, discharge: .eggWhite))

        let forecast = predictor.forecast(logs: logs, today: marker.adding(days: 2))
        #expect(forecast.nextPeriod?.ovulation == marker)
        #expect(forecast.nextPeriod?.periodStart == marker.adding(days: 14))
    }

    @Test func runningPeriodIsDetected() {
        let start = CalendarDay.d("2026-10-30")
        let logs = [
            DayLog(day: start, flow: .heavy),
            DayLog(day: start.adding(days: 1), flow: .heavy),
        ]
        let forecast = predictor.forecast(logs: logs, today: start.adding(days: 1))

        #expect(forecast.status.phase == .menstruation)
        #expect(forecast.status.cycleDay == 2)
        #expect(forecast.ongoingPeriodRemaining == start.adding(days: 2)...start.adding(days: 4))
        #expect(forecast.markers(on: start.adding(days: 3)).contains(.predictedPeriod))
    }

    @Test func latePeriodIsReported() throws {
        let (logs, starts) = history(firstStart: .d("2026-03-01"), cycleLengths: Array(repeating: 28, count: 6))
        let expected = starts.last!.adding(days: 28)
        let today = expected.adding(days: 3)
        let forecast = predictor.forecast(logs: logs, today: today)

        #expect(forecast.status.phase == .late)
        #expect(forecast.status.daysLate == 3)
        #expect(forecast.status.cycleDay == 32)
        let next = try #require(forecast.nextPeriod)
        #expect(next.periodStart == today)
    }

    @Test func expectedTodayIsNotLate() {
        let (logs, starts) = history(firstStart: .d("2026-03-01"), cycleLengths: Array(repeating: 28, count: 6))
        let today = starts.last!.adding(days: 28)
        let forecast = predictor.forecast(logs: logs, today: today)
        #expect(forecast.status.daysLate == 0)
        #expect(forecast.status.daysUntilNextPeriod == 0)
    }

    @Test(arguments: [
        (1, CyclePhase.menstruation),
        (4, CyclePhase.follicular),
        (8, CyclePhase.follicular),
        (9, CyclePhase.fertile),
        (14, CyclePhase.ovulation),
        (15, CyclePhase.fertile),
        (16, CyclePhase.luteal),
    ])
    func phases(dayOffset: Int, expected: CyclePhase) {
        // Short 3-day periods, so the follicular phase starts early.
        let (logs, starts) = history(firstStart: .d("2026-03-01"), cycleLengths: Array(repeating: 28, count: 6), periodLength: 3)
        let today = starts.last!.adding(days: dayOffset)
        let forecast = predictor.forecast(logs: logs, today: today)
        #expect(forecast.status.phase == expected)
    }

    @Test func futureLogsAreIgnored() {
        let (logs, starts) = history(firstStart: .d("2026-03-01"), cycleLengths: [28, 28])
        let forecast = predictor.forecast(logs: logs, today: starts[1].adding(days: 5))
        #expect(forecast.currentCycleStart == starts[1])
    }

    @Test func uncertaintyGrowsWithDistance() {
        let (logs, starts) = history(firstStart: .d("2026-01-01"), cycleLengths: [24, 33, 26, 35, 25, 32])
        let forecast = predictor.forecast(logs: logs, today: starts.last!.adding(days: 1))
        #expect(forecast.upcoming.last!.uncertainty >= forecast.upcoming.first!.uncertainty)
        #expect(forecast.upcoming.first!.uncertainty >= 2)
        #expect(forecast.model.confidence == .medium)
    }

    @Test func customPriorsAreUsedWithoutData() {
        let predictor = CyclePredictor(priors: CyclePriors(cycleLength: 32, periodLength: 6))
        let hint = CalendarDay.d("2026-10-20")
        let forecast = predictor.forecast(logs: [], today: .d("2026-11-01"), lastPeriodStartHint: hint)
        #expect(forecast.nextPeriod?.periodStart == hint.adding(days: 32))
        #expect(forecast.nextPeriod?.periodLength == 6)
    }
}
