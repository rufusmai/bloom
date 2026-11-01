import Foundation
import SwiftData
import Testing
import BloomKit
@testable import Bloom

@MainActor
struct DayEntryTests {
    private let day = CalendarDay(year: 2026, month: 10, day: 31)

    /// Stored once per test, so the activity IDs stay stable within a test.
    private let fullLog = DayLog(
        day: CalendarDay(year: 2026, month: 10, day: 31),
        flow: .heavy,
        symptoms: [.cramps, .breastTenderness],
        discharge: .eggWhite,
        sexualActivities: [SexualActivity(protection: .unprotected), SexualActivity(protection: .protected)],
        note: "Felt tired"
    )

    @Test func mappingRoundTrip() {
        let entry = DayEntry(log: fullLog)
        #expect(entry.day == "2026-10-31")
        #expect(entry.dayLog == fullLog)
    }

    @Test func unknownStoredValuesAreIgnored() {
        let entry = DayEntry(day: "2026-10-31")
        entry.flowRaw = "superHeavy"
        entry.symptomsRaw = ["cramps", "somethingNew"]
        entry.dischargeRaw = "mystery"
        let log = entry.dayLog
        #expect(log?.flow == nil)
        #expect(log?.symptoms == [.cramps])
        #expect(log?.discharge == nil)
    }

    @Test func storeKeepsOneEntryPerDay() throws {
        let container = try BloomStore.makeContainer(inMemory: true)
        let store = DayLogStore(context: container.mainContext)

        try store.save(DayLog(day: day, flow: .light))
        try store.save(DayLog(day: day, flow: .heavy, symptoms: [.cramps]))

        let entries = try container.mainContext.fetch(FetchDescriptor<DayEntry>())
        #expect(entries.count == 1)
        #expect(try store.log(for: day).flow == .heavy)
        #expect(try store.log(for: day).symptoms == [.cramps])
    }

    @Test func savingAnEmptyLogDeletesTheEntry() throws {
        let container = try BloomStore.makeContainer(inMemory: true)
        let store = DayLogStore(context: container.mainContext)

        try store.save(fullLog)
        try store.save(DayLog(day: day))

        #expect(try container.mainContext.fetchCount(FetchDescriptor<DayEntry>()) == 0)
    }

    @Test func deleteAllRemovesEverything() throws {
        let container = try BloomStore.makeContainer(inMemory: true)
        let store = DayLogStore(context: container.mainContext)
        for log in PreviewData.sampleLogs(today: day) {
            try store.save(log)
        }
        #expect(try !store.allLogs().isEmpty)

        try store.deleteAll()
        #expect(try store.allLogs().isEmpty)
    }

    @Test func exportContainsAllDays() throws {
        let document = try ExportDocument(logs: [fullLog])
        let json = try #require(JSONSerialization.jsonObject(with: document.data) as? [String: Any])
        #expect(json["format"] as? String == "bloom-export")
        #expect((json["days"] as? [Any])?.count == 1)
    }

    @Test func sampleDataGivesAConfidentForecast() {
        let state = CycleState(
            logs: PreviewData.sampleLogs(today: day),
            today: day,
            priors: .default,
            lastPeriodStartHint: nil
        )
        #expect(state.forecast.status.cycleDay == 10)
        #expect(state.forecast.model.cyclesUsed == 6)
        #expect(state.forecast.model.confidence == .high)
    }
}
