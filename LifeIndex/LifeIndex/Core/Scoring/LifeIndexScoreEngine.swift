import Foundation

struct LifeIndexScoreEngine {

    // MARK: - Score Weights (total = 1.0)
    static let weights: [HealthMetricType: Double] = [
        .steps: 0.15,
        .heartRate: 0.10,
        .heartRateVariability: 0.15,
        .restingHeartRate: 0.10,
        .bloodOxygen: 0.10,
        .activeCalories: 0.10,
        .sleepDuration: 0.20,
        .mindfulMinutes: 0.05,
        .workoutMinutes: 0.05
    ]

    // MARK: - Ideal Ranges / Targets

    static let targets: [HealthMetricType: ClosedRange<Double>] = [
        .steps: 8000...12000,
        .heartRate: 60...100,
        .heartRateVariability: 30...80,
        .restingHeartRate: 50...70,
        .bloodOxygen: 0.95...1.0,
        .activeCalories: 300...600,
        .sleepDuration: 420...540,
        .mindfulMinutes: 5...30,
        .workoutMinutes: 20...60
    ]

    // Metrics that accumulate throughout the day and should be scaled by time
    static let cumulativeMetrics: Set<HealthMetricType> = [
        .steps, .activeCalories, .workoutMinutes, .mindfulMinutes
    ]

    // MARK: - Time-of-Day Scale Factor

    /// Returns a 0.0–1.0 factor representing how much of the waking day has passed.
    /// Assumes waking hours are 6 AM to 11 PM (17 hours).
    /// Before 6 AM returns a small baseline; after 11 PM returns 1.0.
    static func dayProgressFactor(at date: Date = .now) -> Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let totalMinutes = Double(hour * 60 + minute)

        let wakeMinute: Double = 6 * 60    // 6:00 AM
        let sleepMinute: Double = 23 * 60   // 11:00 PM
        let wakingWindow = sleepMinute - wakeMinute // 17 hours = 1020 min

        if totalMinutes <= wakeMinute { return 0.05 } // minimal baseline pre-wake
        if totalMinutes >= sleepMinute { return 1.0 }

        return max(0.1, (totalMinutes - wakeMinute) / wakingWindow)
    }

    /// Scales a cumulative metric target range by the day progress factor.
    /// e.g., at 8 AM (~12% of day), step target 8000–12000 becomes ~960–1440.
    static func scaledTarget(for type: HealthMetricType, target: ClosedRange<Double>, factor: Double) -> ClosedRange<Double> {
        guard cumulativeMetrics.contains(type) else { return target }
        let scaledLower = target.lowerBound * factor
        let scaledUpper = target.upperBound * factor
        return scaledLower...max(scaledLower, scaledUpper)
    }

    // MARK: - Calculate Overall Score

    /// Calculate score with optional time-aware scaling for cumulative metrics.
    /// When `timeAware` is true (default), step/calorie/workout targets scale by time of day.
    static func calculateScore(from summary: DailyHealthSummary, timeAware: Bool = true, at date: Date = .now) -> Int {
        let factor = timeAware ? dayProgressFactor(at: date) : 1.0
        var totalScore: Double = 0
        var totalWeight: Double = 0

        for (metricType, weight) in weights {
            guard let value = summary.metrics[metricType],
                  let target = targets[metricType] else {
                continue
            }

            let effectiveTarget = scaledTarget(for: metricType, target: target, factor: factor)
            let metricScore = scoreMetric(value: value, target: effectiveTarget, type: metricType)
            totalScore += metricScore * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else { return 0 }

        let normalized = (totalScore / totalWeight) * 100
        return min(100, max(0, Int(normalized.rounded())))
    }

    /// Calculate score without time awareness (for historical daily scores).
    static func calculateFinalScore(from summary: DailyHealthSummary) -> Int {
        calculateScore(from: summary, timeAware: false)
    }

    // MARK: - Score Individual Metric

    static func scoreMetric(value: Double, target: ClosedRange<Double>, type: HealthMetricType) -> Double {
        if target.contains(value) {
            return 1.0
        }

        let rangeSpan = target.upperBound - target.lowerBound
        guard rangeSpan > 0 else { return 1.0 }

        let distance: Double
        if value < target.lowerBound {
            distance = target.lowerBound - value
        } else {
            distance = value - target.upperBound
        }

        let normalizedDistance = distance / rangeSpan
        let score = exp(-normalizedDistance)

        return max(0, min(1, score))
    }

    // MARK: - Score Label

    static func label(for score: Int) -> String {
        switch score {
        case 90...100: return "Excellent"
        case 75..<90: return "Great"
        case 60..<75: return "Good"
        case 40..<60: return "Building Up"
        case 20..<40: return "Room to Grow"
        default: return "Just Starting"
        }
    }

    /// Time-aware label that softens messaging in the morning.
    static func label(for score: Int, at date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)

        // Before noon, use gentler labels for low scores
        if hour < 12 {
            switch score {
            case 90...100: return "Excellent"
            case 75..<90: return "Great"
            case 60..<75: return "Good"
            case 40..<60: return "Building Up"
            default: return "Getting Started"
            }
        }

        return label(for: score)
    }
}
