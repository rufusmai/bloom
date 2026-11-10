import SwiftUI
import BloomKit

struct MonthGridView: View {
    let month: CalendarDay
    let today: CalendarDay
    let logsByDay: [CalendarDay: DayLog]
    let forecast: CycleForecast
    let onSelect: (CalendarDay) -> Void

    @Environment(\.calendar) private var calendar

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.title3.weight(.semibold))
                .padding(.leading, 6)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear
                        .frame(height: 1)
                        .accessibilityHidden(true)
                }
                ForEach(days) { day in
                    Button {
                        onSelect(day)
                    } label: {
                        DayCellView(
                            day: day,
                            log: logsByDay[day],
                            markers: forecast.markers(on: day),
                            isToday: day == today,
                            isFuture: day > today
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(day > today)
                }
            }
        }
    }

    private var leadingBlanks: Int {
        (month.weekday - calendar.firstWeekday + 7) % 7
    }

    private var days: [CalendarDay] {
        (0..<month.numberOfDaysInMonth).map { month.adding(days: $0) }
    }
}

struct DayCellView: View {
    let day: CalendarDay
    let log: DayLog?
    let markers: DayMarkers
    let isToday: Bool
    let isFuture: Bool

    private var loggedFlow: FlowIntensity? {
        guard let flow = log?.flow, flow.countsAsPeriod else { return nil }
        return flow
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(day.day, format: .number)
                .font(.body.weight(isToday ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(textColor)
                .frame(width: 38, height: 38)
                .background { cellBackground }
                .overlay {
                    if isToday {
                        Circle()
                            .stroke(Color.primary.opacity(0.8), lineWidth: 1.5)
                            .padding(-3)
                    }
                }
            indicators
                .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var cellBackground: some View {
        if let loggedFlow {
            Circle().fill(BloomColor.period.opacity(loggedFlow.fillOpacity))
        } else if markers.contains(.predictedPeriod) {
            Circle().strokeBorder(BloomColor.period, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
        } else if markers.contains(.ovulation) {
            Circle()
                .fill(BloomColor.fertile.opacity(0.2))
                .overlay(Circle().strokeBorder(BloomColor.ovulation, lineWidth: 2))
        } else if markers.contains(.fertile) {
            Circle().fill(BloomColor.fertile.opacity(0.2))
        }
    }

    private var indicators: some View {
        HStack(spacing: 3) {
            if log?.flow == .spotting {
                Circle().fill(BloomColor.period).frame(width: 5, height: 5)
            }
            if let log, !log.sexualActivities.isEmpty {
                Image(systemName: "heart.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(BloomColor.accent)
            }
            if let log, !log.symptoms.isEmpty || log.discharge != nil || log.hasNote {
                Circle().fill(Color.secondary).frame(width: 5, height: 5)
            }
        }
    }

    private var textColor: Color {
        if loggedFlow != nil { return .white }
        if isFuture { return .secondary }
        return .primary
    }

    private var accessibilityText: String {
        var parts = [day.formatted(.dateTime.weekday(.wide).day().month(.wide))]
        if isToday { parts.append(String(localized: "Today")) }
        if let flow = log?.flow { parts.append(String(localized: flow.title)) }
        if markers.contains(.predictedPeriod) { parts.append(String(localized: "Predicted period")) }
        if markers.contains(.ovulation) { parts.append(String(localized: "Ovulation")) }
        if markers.contains(.fertile) { parts.append(String(localized: "Fertile")) }
        if let log, !log.sexualActivities.isEmpty { parts.append(String(localized: "Sex")) }
        if let log, !log.symptoms.isEmpty { parts.append(String(localized: "Symptoms")) }
        if log?.discharge != nil { parts.append(String(localized: "Discharge")) }
        if let log, log.hasNote { parts.append(String(localized: "Note")) }
        return parts.joined(separator: ", ")
    }
}
