import Foundation
import SwiftData
import BloomKit

/// Sample data for SwiftUI previews and the debug "Load sample data" action.
@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        do {
            let container = try BloomStore.makeContainer(inMemory: true)
            let store = DayLogStore(context: container.mainContext)
            for log in sampleLogs(today: .today()) {
                try store.save(log)
            }
            return container
        } catch {
            fatalError("Could not create preview container: \(error)")
        }
    }()

    static var cycleState: CycleState {
        CycleState(logs: sampleLogs(today: .today()), today: .today(), priors: .default, lastPeriodStartHint: nil)
    }

    /// Six completed cycles of 27–30 days. The current cycle started 9 days ago.
    static func sampleLogs(today: CalendarDay) -> [DayLog] {
        let cycleLengths = [29, 27, 30, 28, 29, 28]
        var starts = [today.adding(days: -9)]
        for length in cycleLengths.reversed() {
            starts.insert(starts[0].adding(days: -length), at: 0)
        }

        var logs: [CalendarDay: DayLog] = [:]
        func update(_ day: CalendarDay, _ change: (inout DayLog) -> Void) {
            var log = logs[day] ?? DayLog(day: day)
            change(&log)
            logs[day] = log
        }

        let flows: [FlowIntensity] = [.medium, .heavy, .medium, .light, .light]
        for (index, start) in starts.enumerated() {
            for (offset, flow) in flows.enumerated() {
                update(start.adding(days: offset)) { log in
                    log.flow = flow
                    if offset < 2 { log.symptoms.insert(.cramps) }
                }
            }
            update(start.adding(days: -2)) { $0.symptoms.formUnion([.breastTenderness, .moodSwings]) }

            if index < cycleLengths.count {
                let nextStart = start.adding(days: cycleLengths[index])
                update(nextStart.adding(days: -15)) { $0.discharge = .eggWhite }
                update(nextStart.adding(days: -14)) { $0.discharge = .eggWhite }
                update(nextStart.adding(days: -11)) { $0.discharge = .creamy }
                update(start.adding(days: 11)) { $0.sexualActivities.append(SexualActivity(protection: .protected)) }
            }
        }
        return logs.values.filter { $0.day <= today }.sorted { $0.day < $1.day }
    }
}
