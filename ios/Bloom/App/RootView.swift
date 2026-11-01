import Combine
import SwiftData
import SwiftUI
import BloomKit

enum AppTab: Hashable {
    case today
    case calendar
    case history
}

struct RootView: View {
    @Query(sort: \DayEntry.day) private var entries: [DayEntry]

    @AppStorage(SettingsKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @AppStorage(SettingsKey.typicalCycleLength) private var typicalCycleLength = 28
    @AppStorage(SettingsKey.typicalPeriodLength) private var typicalPeriodLength = 5
    @AppStorage(SettingsKey.lastPeriodStartHint) private var lastPeriodStartHint = ""

    @State private var today = CalendarDay.today()
    @State private var selection = AppTab.today
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $selection) {
            Tab("Today", systemImage: "camera.macro", value: AppTab.today) {
                TodayView()
            }
            Tab("Calendar", systemImage: "calendar", value: AppTab.calendar) {
                CalendarView()
            }
            Tab("History", systemImage: "chart.bar.xaxis", value: AppTab.history) {
                HistoryView()
            }
        }
        .tint(BloomColor.accent)
        .environment(\.cycleState, cycleState)
        .fullScreenCover(isPresented: showsOnboarding) {
            OnboardingView()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { today = .today() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
            today = .today()
        }
    }

    private var cycleState: CycleState {
        CycleState(
            logs: entries.compactMap(\.dayLog),
            today: today,
            priors: CyclePriors(
                cycleLength: Double(typicalCycleLength),
                periodLength: Double(typicalPeriodLength)
            ),
            lastPeriodStartHint: CalendarDay(lastPeriodStartHint)
        )
    }

    private var showsOnboarding: Binding<Bool> {
        Binding(
            get: { !hasCompletedOnboarding },
            set: { isPresented in hasCompletedOnboarding = !isPresented }
        )
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewData.container)
}
