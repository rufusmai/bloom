import Foundation
import Testing
import BloomKit
@testable import Bloom

struct FormattingTests {
    private let today = CalendarDay(year: 2026, month: 11, day: 25)

    @Test func dayLogTitleLeavesOutTheCurrentYear() {
        let title = CalendarDay(year: 2026, month: 3, day: 14).dayLogTitle(today: today)
        #expect(!title.contains("2026"))
        #expect(title.contains("14"))
    }

    @Test func dayLogTitleNamesAnotherYear() {
        let title = CalendarDay(year: 2025, month: 11, day: 25).dayLogTitle(today: today)
        #expect(title.contains("2025"))
        #expect(title.contains("25"))
    }
}
