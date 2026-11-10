import Testing
@testable import BloomKit

@Suite("DayLog")
struct DayLogTests {
    @Test(arguments: ["", " ", "\n", " \t\n "])
    func blankNoteIsNoNote(_ note: String) {
        let log = DayLog(day: .d("2026-11-01"), note: note)
        #expect(!log.hasNote)
        #expect(log.isEmpty)
    }

    @Test func blankNoteNextToOtherDataIsNoNote() {
        let log = DayLog(day: .d("2026-11-01"), discharge: .creamy, note: "  \n")
        #expect(!log.hasNote)
        #expect(!log.isEmpty)
    }

    @Test(arguments: ["Headache", "  tired \n"])
    func noteWithTextCounts(_ note: String) {
        let log = DayLog(day: .d("2026-11-01"), note: note)
        #expect(log.hasNote)
        #expect(!log.isEmpty)
    }
}
