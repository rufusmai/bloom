import Testing
@testable import BloomKit

@Suite("PeriodDetector")
struct PeriodDetectorTests {
    @Test func groupsConsecutiveBleedingDays() {
        let logs = (0..<5).map { DayLog(day: CalendarDay.d("2026-10-01").adding(days: $0), flow: .medium) }
        let periods = PeriodDetector.detectPeriods(in: logs)
        #expect(periods == [DetectedPeriod(start: .d("2026-10-01"), end: .d("2026-10-05"))])
        #expect(periods.first?.length == 5)
    }

    @Test func mergesShortGapsInsideAPeriod() {
        let logs = [
            DayLog(day: .d("2026-10-01"), flow: .heavy),
            DayLog(day: .d("2026-10-02"), flow: .medium),
            // 10-03 and 10-04 forgotten
            DayLog(day: .d("2026-10-05"), flow: .light),
        ]
        #expect(PeriodDetector.detectPeriods(in: logs) == [DetectedPeriod(start: .d("2026-10-01"), end: .d("2026-10-05"))])
    }

    @Test func spottingNeverStartsAPeriod() {
        let logs = [
            DayLog(day: .d("2026-09-28"), flow: .spotting),
            DayLog(day: .d("2026-09-29"), flow: .spotting),
            DayLog(day: .d("2026-10-01"), flow: .medium),
            DayLog(day: .d("2026-10-02"), flow: .medium),
            DayLog(day: .d("2026-10-15"), flow: .spotting),
        ]
        #expect(PeriodDetector.detectPeriods(in: logs) == [DetectedPeriod(start: .d("2026-10-01"), end: .d("2026-10-02"))])
        #expect(PeriodDetector.detectPeriods(in: [DayLog(day: .d("2026-10-01"), flow: .spotting)]).isEmpty)
    }

    @Test func intermenstrualBleedingIsNotANewPeriod() {
        let logs = [
            DayLog(day: .d("2026-10-01"), flow: .medium),
            DayLog(day: .d("2026-10-02"), flow: .medium),
            DayLog(day: .d("2026-10-12"), flow: .light), // 11 days after start
            DayLog(day: .d("2026-10-29"), flow: .medium),
        ]
        let periods = PeriodDetector.detectPeriods(in: logs)
        #expect(periods.map(\.start) == [.d("2026-10-01"), .d("2026-10-29")])
    }

    @Test func orderOfLogsDoesNotMatter() {
        let (logs, starts) = history(firstStart: .d("2026-01-01"), cycleLengths: [28, 30])
        #expect(PeriodDetector.detectPeriods(in: logs.reversed()).map(\.start) == starts)
    }

    @Test func cyclesCarryLengthAndOvulationMarker() {
        var (logs, starts) = history(firstStart: .d("2026-01-01"), cycleLengths: [30])
        logs.append(DayLog(day: starts[0].adding(days: 14), discharge: .eggWhite))
        logs.append(DayLog(day: starts[0].adding(days: 16), discharge: .eggWhite))
        logs.append(DayLog(day: starts[0].adding(days: 18), discharge: .creamy))

        let cycles = CycleHistory.cycles(from: PeriodDetector.detectPeriods(in: logs), logs: logs)
        #expect(cycles.count == 2)
        #expect(cycles[0].length == 30)
        #expect(cycles[0].ovulationMarker == starts[0].adding(days: 16))
        #expect(cycles[0].lutealLength == 14)
        #expect(cycles[1].isCurrent)
    }
}
