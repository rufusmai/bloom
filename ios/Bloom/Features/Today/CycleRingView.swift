import SwiftUI
import BloomKit

/// A ring showing the current cycle: period, fertile window and today's position.
struct CycleRingView: View {
    let forecast: CycleForecast

    private let lineWidth: CGFloat = 18

    var body: some View {
        let geometry = RingGeometry(forecast: forecast)
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: lineWidth)

            if let geometry {
                arc(geometry.fertile, color: BloomColor.fertile.opacity(0.75))
                arc(geometry.period, color: BloomColor.period)
                todayMarker(at: geometry.today)
            }

            VStack(spacing: 2) {
                if let cycleDay = forecast.status.cycleDay {
                    Text("Cycle day")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(cycleDay, format: .number)
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                } else {
                    // Decorative: the headline below already says to log a period.
                    Image(systemName: "camera.macro")
                        .font(.system(size: 56))
                        .foregroundStyle(BloomColor.accent)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(lineWidth / 2)
        .accessibilityElement(children: .combine)
    }

    private func arc(_ range: ClosedRange<Double>, color: Color) -> some View {
        Circle()
            .trim(from: range.lowerBound, to: range.upperBound)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }

    private func todayMarker(at fraction: Double) -> some View {
        GeometryReader { proxy in
            let radius = min(proxy.size.width, proxy.size.height) / 2
            let angle = Angle.degrees(fraction * 360 - 90)
            Circle()
                .fill(Color.primary)
                .overlay(Circle().stroke(BloomColor.groupedBackground, lineWidth: 3))
                .frame(width: lineWidth + 4, height: lineWidth + 4)
                .position(
                    x: proxy.size.width / 2 + radius * cos(angle.radians),
                    y: proxy.size.height / 2 + radius * sin(angle.radians)
                )
        }
    }
}

/// Positions on the ring as fractions (0…1) of the current cycle.
private struct RingGeometry {
    let period: ClosedRange<Double>
    let fertile: ClosedRange<Double>
    let today: Double

    init?(forecast: CycleForecast) {
        guard let start = forecast.currentCycleStart,
              let next = forecast.nextPeriod,
              let cycleDay = forecast.status.cycleDay
        else { return nil }

        let total = Double(max(next.periodStart.days(since: start), cycleDay, 1))
        func fraction(_ day: CalendarDay) -> Double {
            min(max(Double(day.days(since: start)) / total, 0), 1)
        }

        let periodEnd = max(
            forecast.ongoingPeriodRemaining?.upperBound ?? start,
            forecast.cycles.last(where: { $0.start == start })?.period.end ?? start
        )
        period = 0...max(fraction(periodEnd.adding(days: 1)), 0.01)
        let fertileStart = fraction(next.fertileWindow.lowerBound)
        fertile = fertileStart...max(fraction(next.fertileWindow.upperBound.adding(days: 1)), fertileStart)
        today = min((Double(cycleDay) - 0.5) / total, 1)
    }
}

#Preview {
    CycleRingView(forecast: PreviewData.cycleState.forecast)
        .frame(width: 240, height: 240)
}
