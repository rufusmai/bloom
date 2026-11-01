import Foundation
import SwiftData
import BloomKit

/// Reads and writes `DayLog`s. Exactly one `DayEntry` exists per logged day.
/// Days without any data have no entry at all.
@MainActor
struct DayLogStore {
    let context: ModelContext

    func entry(for day: CalendarDay) throws -> DayEntry? {
        let key = day.isoString
        var descriptor = FetchDescriptor<DayEntry>(predicate: #Predicate { $0.day == key })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func log(for day: CalendarDay) throws -> DayLog {
        try entry(for: day)?.dayLog ?? DayLog(day: day)
    }

    func allLogs() throws -> [DayLog] {
        let descriptor = FetchDescriptor<DayEntry>(sortBy: [SortDescriptor(\.day)])
        return try context.fetch(descriptor).compactMap(\.dayLog)
    }

    /// Inserts, updates or – if `log` is empty – deletes the entry for `log.day`.
    func save(_ log: DayLog) throws {
        if let existing = try entry(for: log.day) {
            if log.isEmpty {
                context.delete(existing)
            } else {
                existing.apply(log)
            }
        } else if !log.isEmpty {
            context.insert(DayEntry(log: log))
        }
        try context.save()
    }

    func deleteAll() throws {
        try context.delete(model: DayEntry.self)
        try context.save()
    }
}
