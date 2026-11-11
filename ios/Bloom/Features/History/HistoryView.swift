import Charts
import SwiftUI
import BloomKit

struct HistoryView: View {
    @Environment(\.cycleState) private var cycle

    private var model: LearnedCycleModel { cycle.forecast.model }
    private var completed: [Cycle] { cycle.forecast.cycles.filter { !$0.isCurrent } }

    var body: some View {
        NavigationStack {
            List {
                if !cycle.forecast.cycles.isEmpty {
                    Section {
                        LearnedSummary(model: model)
                    } header: {
                        Text("What bloom has learned")
                    } footer: {
                        Text("Recent cycles count more. Unusual cycles, for example after a forgotten log, are left out.")
                    }

                    if !completed.isEmpty {
                        Section("Cycle length") {
                            CycleLengthChart(cycles: completed, model: model)
                                .padding(.vertical, 8)
                        }
                    }

                    Section("Cycles") {
                        ForEach(cycle.forecast.cycles.reversed()) { item in
                            CycleRow(
                                cycle: item,
                                today: cycle.today,
                                isExcluded: model.excludedCycleStarts.contains(item.start)
                            )
                        }
                    }
                }
            }
            .overlay {
                if cycle.forecast.cycles.isEmpty {
                    ContentUnavailableView(
                        "No cycles yet",
                        systemImage: "chart.bar.xaxis",
                        description: Text("Log your period in the calendar. Your cycle history appears here.")
                    )
                }
            }
            .navigationTitle("History")
        }
    }
}

private struct LearnedSummary: View {
    let model: LearnedCycleModel

    var body: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 16) {
            GridRow {
                stat("Cycle length", value: "\(Int(model.cycleLength.rounded())) days")
                stat("Variability", value: "± \(Int(model.cycleLengthDeviation.rounded())) days")
            }
            GridRow {
                stat("Period length", value: "\(Int(model.periodLength.rounded())) days")
                stat("Luteal phase", value: "\(Int(model.lutealLength.rounded())) days")
            }
        }
        .padding(.vertical, 4)
    }

    private func stat(_ title: LocalizedStringKey, value: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct CycleLengthChart: View {
    let cycles: [Cycle]
    let model: LearnedCycleModel

    var body: some View {
        let longest = Double(cycles.compactMap(\.length).max() ?? 30)
        Chart {
            ForEach(cycles) { item in
                BarMark(
                    x: .value("Start", item.start.asDate, unit: .day),
                    y: .value("Days", Double(item.length ?? 0)),
                    width: .fixed(12)
                )
                .foregroundStyle(isExcluded(item) ? Color.gray.opacity(0.4) : BloomColor.period)
                .cornerRadius(4)
                .accessibilityLabel(Text(item.start.formatted(.dateTime.day().month(.abbreviated).year())))
                .accessibilityValue(lengthValue(item))
            }
            RuleMark(y: .value("Average", model.cycleLength))
                .foregroundStyle(BloomColor.accent)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
        }
        .chartYScale(domain: 0...max(40, longest + 5))
        .frame(height: 200)
    }

    private func isExcluded(_ item: Cycle) -> Bool {
        model.excludedCycleStarts.contains(item.start)
    }

    /// The grey of a left-out bar is invisible to VoiceOver, so its value says it.
    private func lengthValue(_ item: Cycle) -> Text {
        let length = item.length ?? 0
        return isExcluded(item)
            ? Text("\(length) days, not used for predictions")
            : Text("\(length) days")
    }
}

private struct CycleRow: View {
    let cycle: Cycle
    let today: CalendarDay
    let isExcluded: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(cycle.start.formatted(.dateTime.day().month(.abbreviated).year()))
                    .font(.body.weight(.medium))
                Text("Period: \(cycle.period.length) days")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let length = cycle.length {
                    Text("\(length) days")
                } else {
                    Text("Current · day \(today.days(since: cycle.start) + 1)")
                }
                if isExcluded {
                    Text("Not used for predictions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HistoryView()
        .environment(\.cycleState, PreviewData.cycleState)
}
