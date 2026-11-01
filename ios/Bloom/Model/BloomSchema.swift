import Foundation
import SwiftData

/// Version 1 of the on-device database.
///
/// New fields or models get a new `VersionedSchema` plus a stage in `BloomMigrationPlan`,
/// so existing data always migrates instead of being lost.
enum BloomSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [DayEntry.self] }

    /// Everything logged for one calendar day.
    @Model
    final class DayEntry {
        #Unique<DayEntry>([\.day])
        #Index<DayEntry>([\.day])

        /// The calendar day as `yyyy-MM-dd`, independent of time zones.
        var day: String
        /// Enum values are stored as raw strings, so that values added by a newer
        /// app version never make existing data unreadable.
        var flowRaw: String?
        var symptomsRaw: [String]
        var dischargeRaw: String?
        /// JSON-encoded `[SexualActivity]`.
        var sexualActivitiesData: Data?
        var note: String
        var updatedAt: Date

        init(day: String) {
            self.day = day
            self.flowRaw = nil
            self.symptomsRaw = []
            self.dischargeRaw = nil
            self.sexualActivitiesData = nil
            self.note = ""
            self.updatedAt = .now
        }
    }
}

typealias DayEntry = BloomSchemaV1.DayEntry

enum BloomMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [BloomSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum BloomStore {
    /// The app's database. Local only: no CloudKit, no app group.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: BloomSchemaV1.self)
        let configuration = ModelConfiguration(
            "Bloom",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: BloomMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
