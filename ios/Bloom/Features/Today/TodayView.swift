import SwiftUI
import BloomKit

struct TodayView: View {
    @Environment(\.cycleState) private var cycle
    @State private var loggingDay: CalendarDay?
    @State private var showsSettings = false

    private var status: CycleStatus { cycle.forecast.status }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    CycleRingView(forecast: cycle.forecast)
                        .frame(width: 240, height: 240)
                        .padding(.top, 8)

                    VStack(spacing: 6) {
                        Text(status.headline)
                            .font(.title2.weight(.semibold))
                            .multilineTextAlignment(.center)
                        if status.phase != .unknown {
                            Text(status.phase.title)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        loggingDay = cycle.today
                    } label: {
                        Label(logButtonTitle, systemImage: "plus")
                            .font(.headline)
                            .padding(.horizontal, 8)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)

                    if let next = cycle.forecast.nextPeriod {
                        PredictionSummary(next: next, model: cycle.forecast.model)
                    }

                    Text("bloom is not a contraceptive and does not replace medical advice.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding()
            }
            .background(BloomColor.groupedBackground)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") {
                        showsSettings = true
                    }
                }
            }
            .sheet(item: $loggingDay) { day in
                DayLogView(day: day)
            }
            .sheet(isPresented: $showsSettings) {
                SettingsView()
            }
        }
    }

    private var logButtonTitle: LocalizedStringKey {
        cycle.logsByDay[cycle.today] == nil ? "Log today" : "Edit today"
    }
}

/// Cards for the next period, ovulation and fertile window.
private struct PredictionSummary: View {
    let next: PredictedCycle
    let model: LearnedCycleModel

    var body: some View {
        VStack(spacing: 12) {
            InfoCard(
                title: "Next period",
                value: next.periodStart.mediumTitle,
                detail: "± \(next.uncertainty) days",
                systemImage: "drop.fill",
                tint: BloomColor.period
            )
            HStack(spacing: 12) {
                InfoCard(
                    title: "Ovulation",
                    value: next.ovulation.shortTitle,
                    systemImage: "sparkle",
                    tint: BloomColor.ovulation
                )
                InfoCard(
                    title: "Fertile window",
                    value: "\(next.fertileWindow.lowerBound.formatted(.dateTime.day().month(.abbreviated))) – \(next.fertileWindow.upperBound.formatted(.dateTime.day().month(.abbreviated)))",
                    systemImage: "leaf.fill",
                    tint: BloomColor.fertile
                )
            }
            HStack(spacing: 4) {
                if model.cyclesUsed == 0 {
                    Text("Based on your settings")
                } else {
                    Text("Based on \(model.cyclesUsed) cycles")
                }
                Text(verbatim: "·")
                Text(model.confidence.title)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    TodayView()
        .environment(\.cycleState, PreviewData.cycleState)
        .modelContainer(PreviewData.container)
}
