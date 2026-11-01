import Foundation
import Testing
@testable import BloomKit

@Suite("CalendarDay")
struct CalendarDayTests {
    @Test func isoRoundTrip() {
        let day = CalendarDay(year: 2026, month: 11, day: 1)
        #expect(day.isoString == "2026-11-01")
        #expect(CalendarDay("2026-11-01") == day)
    }

    @Test(arguments: ["2026-13-01", "2026-02-30", "2026-1-01", "26-01-01", "2026-01-00", "abc", ""])
    func rejectsInvalidISO(_ string: String) {
        #expect(CalendarDay(string) == nil)
    }

    @Test func crossesMonthAndYearBoundaries() {
        #expect(CalendarDay.d("2025-12-31").adding(days: 1) == .d("2026-01-01"))
        #expect(CalendarDay.d("2024-02-28").adding(days: 1) == .d("2024-02-29"))
        #expect(CalendarDay.d("2025-02-28").adding(days: 1) == .d("2025-03-01"))
        #expect(CalendarDay.d("2026-03-01").adding(days: -1) == .d("2026-02-28"))
        #expect(CalendarDay.d("2027-01-01").days(since: .d("2026-01-01")) == 365)
        #expect(CalendarDay.d("2029-01-01").days(since: .d("2028-01-01")) == 366)
    }

    @Test func normalizesOverflow() {
        #expect(CalendarDay(year: 2026, month: 2, day: 30) == .d("2026-03-02"))
        #expect(CalendarDay(year: 2026, month: 13, day: 1) == .d("2027-01-01"))
        #expect(CalendarDay(year: 2026, month: 0, day: 1) == .d("2025-12-01"))
    }

    @Test func ordinalMatchesUnixEpoch() {
        #expect(CalendarDay.d("1970-01-01").ordinal == 0)
        #expect(CalendarDay(ordinal: 20_393) == .d("2025-11-01"))
    }

    @Test func weekday() {
        #expect(CalendarDay.d("2026-11-01").weekday == 1) // Sunday
        #expect(CalendarDay.d("1970-01-01").weekday == 5) // Thursday
        #expect(CalendarDay.d("2026-11-07").weekday == 7) // Saturday
    }

    @Test func monthHelpers() {
        #expect(CalendarDay.d("2024-02-10").numberOfDaysInMonth == 29)
        #expect(CalendarDay.d("2026-11-17").firstOfMonth == .d("2026-11-01"))
        #expect(CalendarDay.d("2026-01-31").adding(months: 1) == .d("2026-02-28"))
        #expect(CalendarDay.d("2026-12-15").adding(months: 2) == .d("2027-02-15"))
    }

    @Test func rangesAreIterable() {
        let range = CalendarDay.d("2026-12-30")...CalendarDay.d("2027-01-02")
        #expect(range.count == 4)
        #expect(Array(range).last == .d("2027-01-02"))
    }

    @Test func codableUsesISOString() throws {
        let data = try JSONEncoder().encode([CalendarDay.d("2026-11-01")])
        #expect(String(decoding: data, as: UTF8.self) == #"["2026-11-01"]"#)
        let decoded = try JSONDecoder().decode([CalendarDay].self, from: data)
        #expect(decoded == [.d("2026-11-01")])
    }

    @Test func bridgesDatesInGivenTimeZone() throws {
        // 2026-11-01 23:30 UTC is already Nov 2 in Berlin.
        let date = Date(timeIntervalSince1970: 1_793_575_800)
        let berlin = try #require(TimeZone(identifier: "Europe/Berlin"))
        let utc = try #require(TimeZone(identifier: "UTC"))
        #expect(CalendarDay(date, timeZone: utc) == .d("2026-11-01"))
        #expect(CalendarDay(date, timeZone: berlin) == .d("2026-11-02"))
        #expect(CalendarDay(CalendarDay.d("2026-03-29").date(in: berlin), timeZone: berlin) == .d("2026-03-29"))
    }
}
