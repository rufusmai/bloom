import SwiftData
import SwiftUI
import BloomKit

/// Logs everything for one day. Changes are saved immediately.
struct DayLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.cycleState) private var cycle

    @State private var day: CalendarDay
    @State private var draft: DayLog
    @State private var persisted: DayLog
    @State private var errorMessage: String?

    init(day: CalendarDay) {
        _day = State(initialValue: day)
        _draft = State(initialValue: DayLog(day: day))
        _persisted = State(initialValue: DayLog(day: day))
    }

    private var store: DayLogStore { DayLogStore(context: modelContext) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SectionCard("Period", systemImage: "drop.fill") {
                        FlowPicker(selection: $draft.flow)
                    }

                    SectionCard("Symptoms", systemImage: "waveform.path.ecg") {
                        FlowLayout(spacing: 8, rowSpacing: 0) {
                            ForEach(Symptom.allCases, id: \.self) { symptom in
                                Chip(symptom.title, isSelected: draft.symptoms.contains(symptom)) {
                                    toggle(symptom)
                                }
                            }
                        }
                    }

                    SectionCard("Discharge", systemImage: "humidity") {
                        FlowLayout(spacing: 8, rowSpacing: 0) {
                            ForEach(DischargeType.allCases, id: \.self) { type in
                                Chip(type.title, isSelected: draft.discharge == type, tint: BloomColor.fertile) {
                                    draft.discharge = draft.discharge == type ? nil : type
                                }
                            }
                        }
                    }

                    SectionCard("Sex", systemImage: "heart.fill") {
                        SexualActivityEditor(activities: $draft.sexualActivities)
                    }

                    SectionCard("Note", systemImage: "note.text") {
                        TextField("Add a note", text: $draft.note, axis: .vertical)
                            .lineLimit(2...6)
                    }
                }
                .padding()
            }
            .background(BloomColor.groupedBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    daySwitcher
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: day) { load() }
            .onChange(of: draft) { _, newValue in save(newValue) }
            .alert("Could not save", isPresented: showsError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var daySwitcher: some View {
        HStack(spacing: 4) {
            Button("Previous day", systemImage: "chevron.left") {
                day = day.adding(days: -1)
            }
            .labelStyle(.iconOnly)

            Text(day.formatted(.dateTime.weekday(.abbreviated).day().month(.wide)))
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(minWidth: 140)

            Button("Next day", systemImage: "chevron.right") {
                day = day.adding(days: 1)
            }
            .labelStyle(.iconOnly)
            .disabled(day >= cycle.today)
        }
    }

    private var showsError: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func toggle(_ symptom: Symptom) {
        if draft.symptoms.contains(symptom) {
            draft.symptoms.remove(symptom)
        } else {
            draft.symptoms.insert(symptom)
        }
    }

    private func load() {
        let log = (try? store.log(for: day)) ?? DayLog(day: day)
        persisted = log
        draft = log
    }

    private func save(_ log: DayLog) {
        guard log.day == day, log != persisted else { return }
        do {
            try store.save(log)
            persisted = log
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Period strength: none, spotting, light, medium, heavy.
struct FlowPicker: View {
    @Binding var selection: FlowIntensity?

    var body: some View {
        HStack(spacing: 8) {
            option(nil)
            ForEach(FlowIntensity.allCases, id: \.self) { flow in
                option(flow)
            }
        }
    }

    private func option(_ flow: FlowIntensity?) -> some View {
        let isSelected = selection == flow
        return Button {
            selection = flow
        } label: {
            VStack(spacing: 6) {
                FlowIcon(flow: flow)
                    .frame(height: 22)
                Text(flow?.title ?? "None")
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? BloomColor.period.opacity(0.18) : BloomColor.chipBackground, in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? BloomColor.period : Color.clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

private struct FlowIcon: View {
    let flow: FlowIntensity?

    var body: some View {
        HStack(spacing: -3) {
            switch flow {
            case nil:
                Image(systemName: "minus.circle")
                    .foregroundStyle(.secondary)
            case .spotting:
                Image(systemName: "drop")
                    .foregroundStyle(BloomColor.period)
            case let flow?:
                ForEach(0..<flow.dropCount, id: \.self) { _ in
                    Image(systemName: "drop.fill")
                }
                .foregroundStyle(BloomColor.period)
            }
        }
        .font(.system(size: 15, weight: .semibold))
        .accessibilityHidden(true)
    }
}

/// Add or remove sexual activities for the day.
private struct SexualActivityEditor: View {
    @Binding var activities: [SexualActivity]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(Protection.allCases, id: \.self) { protection in
                    Button {
                        activities.append(SexualActivity(protection: protection))
                    } label: {
                        Label {
                            Text(protection.title)
                        } icon: {
                            Image(systemName: "plus")
                        }
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(BloomColor.accent)
                    // The logged entries below read "Protected" too; "Add" tells the button apart.
                    // Voice Control keeps the visible word.
                    .accessibilityLabel(Text("Add: \(Text(protection.title))"))
                    .accessibilityInputLabels([Text(protection.title)])
                }
            }

            if activities.isEmpty {
                Text("Nothing logged")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(activities) { activity in
                HStack {
                    Label {
                        Text(activity.protection.title)
                    } icon: {
                        Image(systemName: activity.protection.systemImage)
                            .foregroundStyle(BloomColor.accent)
                    }
                    Spacer()
                    Button {
                        activities.removeAll { $0.id == activity.id }
                    } label: {
                        Label {
                            Text("Remove: \(Text(activity.protection.title))")
                        } icon: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        // The icon alone is about 22 pt. A 44 pt tap area that grows to the
                        // left keeps the icon where it was, at the row's trailing edge.
                        .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                        .contentShape(.rect)
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    DayLogView(day: .today())
        .environment(\.cycleState, PreviewData.cycleState)
        .modelContainer(PreviewData.container)
}
