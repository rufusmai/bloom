import SwiftUI
import BloomKit

/// Everything the UI needs to know about the cycle, derived from the logged days.
/// Computed once in `RootView` and passed down through the environment.
struct CycleState {
    var today: CalendarDay
    var logsByDay: [CalendarDay: DayLog]
    var forecast: CycleForecast

    init(logs: [DayLog], today: CalendarDay, priors: CyclePriors, lastPeriodStartHint: CalendarDay?) {
        self.today = today
        self.logsByDay = Dictionary(logs.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })
        self.forecast = CyclePredictor(priors: priors)
            .forecast(logs: logs, today: today, lastPeriodStartHint: lastPeriodStartHint)
    }

    static let empty = CycleState(logs: [], today: .today(), priors: .default, lastPeriodStartHint: nil)
}

extension EnvironmentValues {
    @Entry var cycleState: CycleState = .empty
}

enum SettingsKey {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let typicalCycleLength = "typicalCycleLength"
    static let typicalPeriodLength = "typicalPeriodLength"
    /// ISO day from onboarding, used until the first period is logged.
    static let lastPeriodStartHint = "lastPeriodStartHint"
}
