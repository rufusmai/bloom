import SwiftUI
import BloomKit

struct CalendarView: View {
    @Environment(\.cycleState) private var cycle
    @State private var loggingDay: CalendarDay?

    /// From the first logged month (at least one year back) to one year ahead.
    private var months: [CalendarDay] {
        let current = cycle.today.firstOfMonth
        let firstLogged = cycle.logsByDay.keys.min()?.firstOfMonth ?? current
        var month = min(firstLogged, current.adding(months: -12))
        let last = current.adding(months: 12)
        var result: [CalendarDay] = []
        while month <= last {
            result.append(month)
            month = month.adding(months: 1)
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    WeekdayHeader()
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    Divider()
                    ScrollView {
                        LazyVStack(spacing: 32) {
                            ForEach(months) { month in
                                MonthGridView(
                                    month: month,
                                    today: cycle.today,
                                    logsByDay: cycle.logsByDay,
                                    forecast: cycle.forecast,
                                    onSelect: { loggingDay = $0 }
                                )
                                .id(month)
                            }
                        }
                        .padding()
                    }
                    .onAppear {
                        proxy.scrollTo(cycle.today.firstOfMonth, anchor: .top)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    CalendarLegend()
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(.bar)
                }
                .navigationTitle("Calendar")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Today") {
                            withAnimation {
                                proxy.scrollTo(cycle.today.firstOfMonth, anchor: .top)
                            }
                        }
                    }
                }
            }
            .sheet(item: $loggingDay) { day in
                DayLogView(day: day)
            }
        }
    }
}

private struct WeekdayHeader: View {
    @Environment(\.calendar) private var calendar

    var body: some View {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        let ordered = Array(symbols[first...] + symbols[..<first])
        HStack(spacing: 0) {
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct CalendarLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            item("Period") {
                Circle().fill(BloomColor.period)
            }
            item("Predicted") {
                Circle().strokeBorder(BloomColor.period, style: StrokeStyle(lineWidth: 1.5, dash: [2, 2]))
            }
            item("Fertile") {
                Circle().fill(BloomColor.fertile.opacity(0.25))
            }
            item("Ovulation") {
                Circle().strokeBorder(BloomColor.ovulation, lineWidth: 2)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func item(_ title: LocalizedStringKey, @ViewBuilder symbol: () -> some View) -> some View {
        HStack(spacing: 4) {
            symbol().frame(width: 12, height: 12)
            Text(title)
        }
    }
}

#Preview {
    CalendarView()
        .environment(\.cycleState, PreviewData.cycleState)
        .modelContainer(PreviewData.container)
}
