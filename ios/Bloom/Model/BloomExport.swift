import SwiftUI
import UniformTypeIdentifiers
import BloomKit

/// The JSON export format. Readable by humans and other apps.
struct BloomExport: Codable {
    var format = "bloom-export"
    var version = 1
    var exportedAt: Date
    var days: [DayLog]
}

struct ExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    var data: Data

    init(logs: [DayLog]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        data = try encoder.encode(BloomExport(exportedAt: .now, days: logs))
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
