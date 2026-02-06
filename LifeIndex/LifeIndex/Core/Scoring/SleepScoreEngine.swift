import Foundation

/// Sleep Score Engine - Aligned with Apple Health methodology
///
/// Apple's Sleep Score uses three components:
/// - Sleep Duration (50 points max) - Primary factor
/// - Bedtime Consistency (30 points max) - We approximate with sleep quality metrics
/// - Interruptions (20 points max) - Based on awake time during sleep
///
/// Since we don't track bedtime consistency, we use sleep stage quality as an alternative.
struct SleepScoreEngine {

    // MARK: - Score Weights (aligned with Apple)

    static let durationWeight: Double = 0.50   // 50 points max
    static let qualityWeight: Double = 0.30    // 30 points max (substitutes for bedtime consistency)
    static let interruptionsWeight: Double = 0.20  // 20 points max

    // MARK: - Duration Targets

    /// Apple uses ~7h 50m as optimal. We use 7-8 hours as ideal range.
    static let idealSleepMinutes: ClosedRange<Double> = 420...480  // 7-8 hours
    static let acceptableSleepMinutes: ClosedRange<Double> = 360...540  // 6-9 hours

    // MARK: - Calculate Score

    /// Calculates sleep score (0-100) similar to Apple Health methodology.
    ///
    /// - Parameters:
    ///   - sleepMinutes: Total minutes asleep (excluding awake time)
    ///   - stages: Optional sleep stage breakdown for quality metrics
    /// - Returns: Score from 0-100, or nil if no data available
    static func calculateScore(
        sleepMinutes: Double?,
        stages: SleepStages? = nil
    ) -> Int? {
        guard let minutes = sleepMinutes, minutes > 0 else { return nil }

        var totalScore: Double = 0
        var totalWeight: Double = 0

        // 1. Duration Score (50% weight)
        let durationScore = calculateDurationScore(minutes: minutes)
        totalScore += durationScore * durationWeight
        totalWeight += durationWeight

        // 2. Quality Score (30% weight) - Based on deep sleep percentage
        if let stages = stages, stages.hasStageData {
            let qualityScore = calculateQualityScore(stages: stages)
            totalScore += qualityScore * qualityWeight
            totalWeight += qualityWeight

            // 3. Interruptions Score (20% weight) - Based on awake time
            let interruptionsScore = calculateInterruptionsScore(stages: stages)
            totalScore += interruptionsScore * interruptionsWeight
            totalWeight += interruptionsWeight
        } else {
            // Without stage data, duration is the only factor
            // Don't add quality/interruptions to total weight
        }

        guard totalWeight > 0 else { return nil }

        let normalized = (totalScore / totalWeight) * 100
        return min(100, max(0, Int(normalized.rounded())))
    }

    // MARK: - Duration Score

    /// Calculates duration component (0.0 to 1.0).
    /// Apple's approach: full points at ~7h 50m, non-linear deduction for less sleep.
    private static func calculateDurationScore(minutes: Double) -> Double {
        // Optimal: 7-8 hours = full score
        if idealSleepMinutes.contains(minutes) {
            return 1.0
        }

        // Above optimal: no penalty (Apple doesn't penalize oversleeping)
        if minutes > idealSleepMinutes.upperBound {
            return 1.0
        }

        // Below optimal: progressive penalty (non-linear like Apple)
        // Apple deducts ~6 points for 1 hour less, ~20+ for 2 hours less
        let deficit = idealSleepMinutes.lowerBound - minutes
        let deficitHours = deficit / 60

        // Non-linear penalty: penalty increases as deficit grows
        // 1 hour = ~12% penalty, 2 hours = ~40% penalty, 3 hours = ~70% penalty
        let penalty = pow(deficitHours * 0.35, 1.3)
        return max(0, 1.0 - penalty)
    }

    // MARK: - Quality Score (proxy for bedtime consistency)

    /// Calculates quality component based on sleep stage distribution.
    /// Optimal deep sleep is ~12-20% of total sleep.
    private static func calculateQualityScore(stages: SleepStages) -> Double {
        guard stages.totalAsleepMinutes > 0 else { return 0.5 }

        // Deep sleep quality (target: 12-20% of sleep)
        let deepPercent = stages.deepMinutes / stages.totalAsleepMinutes
        let deepScore: Double
        if deepPercent >= 0.12 && deepPercent <= 0.20 {
            deepScore = 1.0
        } else if deepPercent > 0.20 {
            deepScore = 0.95  // Slightly too much deep sleep is fine
        } else {
            // Less than 12% deep sleep
            deepScore = max(0.4, deepPercent / 0.12)
        }

        // REM sleep quality (target: 15-25% of sleep)
        let remPercent = stages.remMinutes / stages.totalAsleepMinutes
        let remScore: Double
        if remPercent >= 0.15 && remPercent <= 0.25 {
            remScore = 1.0
        } else if remPercent > 0.25 {
            remScore = 0.95
        } else {
            remScore = max(0.4, remPercent / 0.15)
        }

        // Combined quality score (weight deep sleep slightly more)
        return (deepScore * 0.6) + (remScore * 0.4)
    }

    // MARK: - Interruptions Score

    /// Calculates interruptions component based on awake time.
    /// Full score if minimal awakenings, reduced for frequent interruptions.
    private static func calculateInterruptionsScore(stages: SleepStages) -> Double {
        guard stages.totalMinutes > 0 else { return 1.0 }

        // Calculate awake percentage
        let awakePercent = stages.awakeMinutes / stages.totalMinutes

        // Optimal: less than 5% awake time = full score
        // 5-10% = slight reduction
        // 10-15% = moderate reduction
        // >15% = significant reduction
        if awakePercent <= 0.05 {
            return 1.0
        } else if awakePercent <= 0.10 {
            return 0.90
        } else if awakePercent <= 0.15 {
            return 0.75
        } else if awakePercent <= 0.20 {
            return 0.60
        } else {
            return max(0.3, 1.0 - awakePercent)
        }
    }

    // MARK: - Score Labels (matching Apple's ranges)

    /// Returns a label for the sleep score.
    /// Apple uses: Very High (96-100), High (81-95), OK (61-80), Low (41-60), Very Low (0-40)
    static func label(for score: Int) -> String {
        switch score {
        case 96...100: return "scoreLabel.excellent".localized      // Apple: "Very High"
        case 81..<96: return "scoreLabel.great".localized           // Apple: "High"
        case 61..<81: return "scoreLabel.good".localized            // Apple: "OK"
        case 41..<61: return "metricStatus.fair".localized          // Apple: "Low"
        default: return "score.poor".localized                      // Apple: "Very Low"
        }
    }

    /// Returns a localized label key for the sleep score.
    static func labelKey(for score: Int) -> String {
        switch score {
        case 96...100: return "sleep.excellent"
        case 81..<96: return "sleep.great"
        case 61..<81: return "sleep.good"
        case 41..<61: return "sleep.fair"
        default: return "sleep.poor"
        }
    }

    // MARK: - Sleep Duration Insights

    /// Returns an insight message based on sleep duration.
    static func durationInsight(minutes: Double) -> String {
        let hours = minutes / 60
        if hours >= 7 && hours <= 9 {
            return "sleep.insight.healthy".localized
        } else if hours > 9 {
            return "sleep.insight.long".localized
        } else if hours >= 6 {
            return "sleep.insight.needMore".localized
        } else {
            return "sleep.insight.aim".localized
        }
    }

    // MARK: - Quality Insights

    /// Returns an insight based on sleep stages.
    static func qualityInsight(stages: SleepStages) -> String? {
        guard stages.hasStageData else { return nil }

        let deepPercent = Int((stages.deepMinutes / stages.totalAsleepMinutes) * 100)
        let awakePercent = stages.awakePercent

        if deepPercent >= 12 && awakePercent <= 10 {
            return "sleep.insight.greatQuality".localized
        } else if deepPercent < 10 {
            return "sleep.insight.improveDeep".localized
        } else if awakePercent > 15 {
            return "sleep.insight.awakenings".localized
        }
        return nil
    }
}
