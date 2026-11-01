import Foundation

/// Starting assumptions used before (and while) personal data is learned.
public struct CyclePriors: Hashable, Sendable {
    public var cycleLength: Double
    public var periodLength: Double
    public var lutealLength: Double

    public init(cycleLength: Double = 28, periodLength: Double = 5, lutealLength: Double = 14) {
        self.cycleLength = cycleLength
        self.periodLength = periodLength
        self.lutealLength = lutealLength
    }

    public static let `default` = CyclePriors()
}

public enum PredictionConfidence: String, Hashable, Sendable, Comparable {
    case low
    case medium
    case high

    private var rank: Int {
        switch self {
        case .low: 0
        case .medium: 1
        case .high: 2
        }
    }

    public static func < (lhs: PredictionConfidence, rhs: PredictionConfidence) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// What bloom has learned about a person's cycle.
public struct LearnedCycleModel: Hashable, Sendable {
    /// Estimated cycle length in days.
    public let cycleLength: Double
    /// Estimated standard deviation of the cycle length in days.
    public let cycleLengthDeviation: Double
    /// Estimated period length in days.
    public let periodLength: Double
    /// Estimated luteal phase (ovulation to next period) in days.
    public let lutealLength: Double
    /// Number of completed cycles that were used for the estimate.
    public let cyclesUsed: Int
    /// Starts of completed cycles that were ignored (implausible length or outlier).
    public let excludedCycleStarts: Set<CalendarDay>
    /// Number of cycles with an ovulation marker that fed the luteal estimate.
    public let lutealObservations: Int
    public let confidence: PredictionConfidence
}

/// Learns cycle parameters from history.
///
/// Each parameter is a recency-weighted mean: the newest cycle has weight 1, older cycles
/// decay by `recencyDecay` per cycle. The prior acts like `priorWeight` pseudo-cycles that
/// are older than all real ones, so it dominates with no data and fades as history grows.
public struct CycleLearner: Sendable {
    public var priors: CyclePriors
    /// Only the newest cycles are considered.
    public var maxCycles = 12
    public var recencyDecay = 0.8
    public var priorWeight = 2.0
    /// Cycle lengths outside this range are almost always missed logs.
    public var plausibleCycleLengths = 15...60
    /// Typical cycle variability assumed before data exists.
    public var priorCycleDeviation = 3.0

    public init(priors: CyclePriors = .default) {
        self.priors = priors
    }

    public func learn(from cycles: [Cycle], today: CalendarDay) -> LearnedCycleModel {
        let completed = Array(cycles.filter { !$0.isCurrent }.suffix(maxCycles))

        // Cycle length: drop implausible values, then robust outliers.
        var used = completed.filter { plausibleCycleLengths.contains($0.length ?? 0) }
        if used.count >= 4 {
            let lengths = used.compactMap(\.length).map(Double.init)
            let median = Statistics.median(lengths)
            let mad = Statistics.median(lengths.map { abs($0 - median) })
            let threshold = max(3 * 1.4826 * mad, 7)
            used = used.filter { abs(Double($0.length ?? 0) - median) <= threshold }
        }
        let usedStarts = Set(used.map(\.start))
        let excluded = Set(completed.map(\.start)).subtracting(usedStarts)

        let cycleEstimate = estimate(
            used.compactMap(\.length).map(Double.init),
            prior: priors.cycleLength,
            priorDeviation: priorCycleDeviation
        )

        // Period length: only periods that are certainly over.
        let finishedPeriods = cycles.map(\.period)
            .filter { today.days(since: $0.end) > PeriodDetector.maxGapDays }
            .suffix(maxCycles)
        let periodEstimate = estimate(
            finishedPeriods.map { Double($0.length) },
            prior: priors.periodLength,
            priorDeviation: 1
        )

        // Luteal phase: from egg-white discharge markers in completed cycles.
        let lutealLengths = completed
            .compactMap(\.lutealLength)
            .filter { (9...18).contains($0) }
            .map(Double.init)
        let lutealEstimate = estimate(lutealLengths, prior: priors.lutealLength, priorDeviation: 2)

        let confidence: PredictionConfidence
        if used.count < 2 {
            confidence = .low
        } else if used.count >= 6, cycleEstimate.deviation <= 3 {
            confidence = .high
        } else {
            confidence = .medium
        }

        return LearnedCycleModel(
            cycleLength: cycleEstimate.mean,
            cycleLengthDeviation: cycleEstimate.deviation,
            periodLength: min(max(periodEstimate.mean, 2), 10),
            lutealLength: min(max(lutealEstimate.mean, 10), 16),
            cyclesUsed: used.count,
            excludedCycleStarts: excluded,
            lutealObservations: lutealLengths.count,
            confidence: confidence
        )
    }

    /// Recency-weighted mean and deviation of `observations` (oldest first), shrunk towards `prior`.
    func estimate(_ observations: [Double], prior: Double, priorDeviation: Double) -> (mean: Double, deviation: Double) {
        let count = observations.count
        let weights = (0..<count).map { pow(recencyDecay, Double(count - 1 - $0)) }
        // The prior behaves like pseudo-observations older than every real one.
        let priorWeight = priorWeight * pow(recencyDecay, Double(count))
        let varianceWeight = pow(recencyDecay, Double(count))

        let weightSum = weights.reduce(0, +)
        let weightedSum = zip(weights, observations).reduce(0) { $0 + $1.0 * $1.1 }
        let mean = (priorWeight * prior + weightedSum) / (priorWeight + weightSum)

        let squaredDeviation = zip(weights, observations).reduce(0) { $0 + $1.0 * pow($1.1 - mean, 2) }
        let variance = (varianceWeight * priorDeviation * priorDeviation + squaredDeviation) / (varianceWeight + weightSum)
        return (mean, variance.squareRoot())
    }
}

enum Statistics {
    static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}
