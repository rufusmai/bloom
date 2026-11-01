import SwiftData
import SwiftUI
import BloomKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.cycleState) private var cycle

    @AppStorage(SettingsKey.typicalCycleLength) private var typicalCycleLength = 28
    @AppStorage(SettingsKey.typicalPeriodLength) private var typicalPeriodLength = 5
    @AppStorage(SettingsKey.lastPeriodStartHint) private var lastPeriodStartHint = ""

    @State private var exportDocument: ExportDocument?
    @State private var isExporting = false
    @State private var confirmsDeletion = false
    @State private var errorMessage: String?

    private var store: DayLogStore { DayLogStore(context: modelContext) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $typicalCycleLength, in: 18...45) {
                        LabeledContent("Cycle length") {
                            Text("\(typicalCycleLength) days")
                        }
                    }
                    Stepper(value: $typicalPeriodLength, in: 2...10) {
                        LabeledContent("Period length") {
                            Text("\(typicalPeriodLength) days")
                        }
                    }
                } header: {
                    Text("Your cycle")
                } footer: {
                    Text("bloom starts with these values and replaces them step by step with what it learns from your logs.")
                }

                Section("Privacy") {
                    Label("All data stays on this device. bloom has no account, no cloud and no analytics.", systemImage: "lock.shield")
                }

                Section("Your data") {
                    Button("Export data (JSON)", systemImage: "square.and.arrow.up") {
                        export()
                    }
                    Button("Delete all data", systemImage: "trash", role: .destructive) {
                        confirmsDeletion = true
                    }
                }

                Section("About") {
                    Text("bloom is not a contraceptive and does not replace medical advice. Predictions are estimates and can be wrong.")
                        .font(.subheadline)
                    if let url = URL(string: "https://github.com/rufusmai/bloom") {
                        Link(destination: url) {
                            Label("Source code on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                    }
                    LabeledContent("Version", value: appVersion)
                }

                #if DEBUG
                Section("Developer") {
                    Button("Load sample data", systemImage: "wand.and.stars") {
                        loadSampleData()
                    }
                }
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "bloom-export-\(cycle.today.isoString)"
            ) { result in
                if case .failure(let error) = result {
                    errorMessage = error.localizedDescription
                }
            }
            .confirmationDialog("Delete all data?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
                Button("Delete all data", role: .destructive) {
                    deleteAll()
                }
            } message: {
                Text("This permanently deletes all logged days from this device. It cannot be undone.")
            }
            .alert("Something went wrong", isPresented: showsError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    private var showsError: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func export() {
        do {
            exportDocument = try ExportDocument(logs: store.allLogs())
            isExporting = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteAll() {
        do {
            try store.deleteAll()
            lastPeriodStartHint = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    #if DEBUG
    private func loadSampleData() {
        do {
            for log in PreviewData.sampleLogs(today: cycle.today) {
                try store.save(log)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    #endif
}

#Preview {
    SettingsView()
        .modelContainer(PreviewData.container)
}
