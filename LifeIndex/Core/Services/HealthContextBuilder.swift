import Foundation
import SwiftUI

// MARK: - Enhanced Health Context for AI

/// Comprehensive health context for LLM consumption
/// Phase 1: Structured data + computed insights
struct EnhancedHealthContext {
    // User Profile
    let userProfile: UserHealthProfile

    // Today's Snapshot
    let todaySnapshot: DaySnapshot

    // Weekly Data
    let weeklyData: WeeklyHealthData

    // Pre-computed Trends & Insights
    let trends: HealthTrends

    // Recent AI Insights (stored)
    let recentInsights: [String]

    // Mood & Wellness
    let moodData: MoodContext

    // Nutrition
    let nutritionData: NutritionContext
}

// MARK: - Supporting Structures

struct UserHealthProfile: Codable {
    let age: Int
    let weightKg: Double
    let heightCm: Double
    let gender: String  // "male", "female", "other"
    let activityLevel: String  // "sedentary", "light", "moderate", "active", "veryActive"
    let goal: String  // "loseWeight", "maintain", "gainWeight"
    let dailyCalorieGoal: Int

    var bmi: Double {
        let heightM = heightCm / 100
        return weightKg / (heightM * heightM)
    }

    var bmiCategory: String {
        switch bmi {
        case ..<18.5: return "underweight"
        case 18.5..<25: return "normal"
        case 25..<30: return "overweight"
        default: return "obese"
        }
    }
}

struct DaySnapshot {
    let date: Date
    let lifeIndexScore: Int
    let scoreLabel: String
    let metrics: [String: MetricValue]
    let sleepStages: SleepStageBreakdown?
    let recoveryScore: Int?
}

struct MetricValue {
    let value: Double
    let unit: String
    let status: MetricStatus  // "low", "normal", "high", "excellent"
    let percentOfGoal: Double?  // For goal-based metrics

    var formatted: String {
        if unit == "h:m" {
            let hours = Int(value) / 60
            let mins = Int(value) % 60
            return "\(hours)h \(mins)m"
        }
        return "\(Int(value)) \(unit)"
    }
}

enum MetricStatus: String, Codable {
    case low, belowTarget, normal, good, excellent

    var emoji: String {
        switch self {
        case .low: return "🔴"
        case .belowTarget: return "🟠"
        case .normal: return "🟡"
        case .good: return "🟢"
        case .excellent: return "⭐"
        }
    }
}

struct SleepStageBreakdown {
    let awakeMinutes: Double
    let remMinutes: Double
    let coreMinutes: Double
    let deepMinutes: Double

    var totalSleepMinutes: Double {
        remMinutes + coreMinutes + deepMinutes
    }

    var deepSleepPercent: Int {
        guard totalSleepMinutes > 0 else { return 0 }
        return Int((deepMinutes / totalSleepMinutes) * 100)
    }

    var remSleepPercent: Int {
        guard totalSleepMinutes > 0 else { return 0 }
        return Int((remMinutes / totalSleepMinutes) * 100)
    }
}

struct WeeklyHealthData {
    let dailyScores: [(date: Date, score: Int)]
    let averageScore: Int
    let metricRanges: [String: MetricRange]
    let dailySummaries: [DaySummary]
}

struct MetricRange {
    let min: Double
    let max: Double
    let average: Double
    let unit: String

    var formatted: String {
        "\(Int(min)) / \(Int(average)) / \(Int(max)) \(unit)"
    }
}

struct DaySummary {
    let date: Date
    let score: Int
    let keyMetrics: [String: Double]  // Flattened for easy access
}

struct HealthTrends {
    let scoreChange: TrendDirection
    let sleepTrend: TrendDirection
    let activityTrend: TrendDirection
    let hrvTrend: TrendDirection
    let insights: [TrendInsight]
}

enum TrendDirection: String, Codable {
    case improving, stable, declining, insufficient

    var description: String {
        switch self {
        case .improving: return "improving ↑"
        case .stable: return "stable →"
        case .declining: return "declining ↓"
        case .insufficient: return "not enough data"
        }
    }
}

struct TrendInsight {
    let category: String  // "sleep", "activity", "heart", "recovery"
    let message: String
    let priority: Int  // 1 = high, 2 = medium, 3 = low
}

struct MoodContext {
    let todayMood: Int?  // 1-5
    let todayNote: String?
    let weeklyAverage: Double?
    let moodTrend: TrendDirection
    let recentEntries: [(date: Date, mood: Int, note: String?)]
}

struct NutritionContext {
    let todayCalories: Int
    let todayProtein: Double
    let todayCarbs: Double
    let todayFat: Double
    let calorieGoal: Int
    let percentOfGoal: Int
    let recentMeals: [String]  // Last 3 meal names
}

// MARK: - Health Context Builder

class HealthContextBuilder {

    static let shared = HealthContextBuilder()

    private init() {}

    // MARK: - Build Context from Dashboard Data

    func buildContext(
        todaySummary: DailyHealthSummary,
        weeklyData: [DailyHealthSummary],
        weeklyScores: [(date: Date, score: Int)],
        lifeIndexScore: Int,
        scoreLabel: String,
        recoveryScore: Int?,
        moodLogs: [MoodLog],
        foodLogs: [FoodLog],
        insights: [String]
    ) -> EnhancedHealthContext {

        let userProfile = buildUserProfile()
        let todaySnapshot = buildTodaySnapshot(
            from: todaySummary,
            score: lifeIndexScore,
            label: scoreLabel,
            recoveryScore: recoveryScore
        )
        let weeklyHealthData = buildWeeklyData(from: weeklyData, scores: weeklyScores)
        let trends = computeTrends(from: weeklyData, scores: weeklyScores)
        let moodData = buildMoodContext(from: moodLogs)
        let nutritionData = buildNutritionContext(from: foodLogs)

        return EnhancedHealthContext(
            userProfile: userProfile,
            todaySnapshot: todaySnapshot,
            weeklyData: weeklyHealthData,
            trends: trends,
            recentInsights: insights,
            moodData: moodData,
            nutritionData: nutritionData
        )
    }

    // MARK: - User Profile

    private func buildUserProfile() -> UserHealthProfile {
        let defaults = UserDefaults.standard

        let genderInt = defaults.integer(forKey: "userGender")
        let gender = genderInt == 0 ? "male" : "female"

        let activityLevelInt = defaults.integer(forKey: "userActivityLevel")
        let activityLevels = ["sedentary", "light", "moderate", "active", "veryActive"]
        let activityLevel = activityLevels[min(activityLevelInt, activityLevels.count - 1)]

        let goalInt = defaults.integer(forKey: "userGoalType")
        let goals = ["loseWeight", "maintain", "gainWeight"]
        let goal = goals[min(goalInt, goals.count - 1)]

        return UserHealthProfile(
            age: defaults.integer(forKey: "userAge") > 0 ? defaults.integer(forKey: "userAge") : 25,
            weightKg: defaults.double(forKey: "userWeightKg") > 0 ? defaults.double(forKey: "userWeightKg") : 70,
            heightCm: defaults.double(forKey: "userHeightCm") > 0 ? defaults.double(forKey: "userHeightCm") : 170,
            gender: gender,
            activityLevel: activityLevel,
            goal: goal,
            dailyCalorieGoal: defaults.integer(forKey: "dailyCalorieGoal") > 0 ? defaults.integer(forKey: "dailyCalorieGoal") : 2000
        )
    }

    // MARK: - Today Snapshot

    private func buildTodaySnapshot(
        from summary: DailyHealthSummary,
        score: Int,
        label: String,
        recoveryScore: Int?
    ) -> DaySnapshot {
        var metrics: [String: MetricValue] = [:]

        for (type, value) in summary.metrics {
            let (unit, status) = metricInfo(for: type, value: value)
            metrics[type.displayName] = MetricValue(
                value: value,
                unit: unit,
                status: status,
                percentOfGoal: percentOfGoal(for: type, value: value)
            )
        }

        var sleepStages: SleepStageBreakdown? = nil
        if let stages = summary.sleepStages {
            sleepStages = SleepStageBreakdown(
                awakeMinutes: stages.awakeMinutes,
                remMinutes: stages.remMinutes,
                coreMinutes: stages.coreMinutes,
                deepMinutes: stages.deepMinutes
            )
        }

        return DaySnapshot(
            date: summary.date,
            lifeIndexScore: score,
            scoreLabel: label,
            metrics: metrics,
            sleepStages: sleepStages,
            recoveryScore: recoveryScore
        )
    }

    // MARK: - Weekly Data

    private func buildWeeklyData(
        from weeklyData: [DailyHealthSummary],
        scores: [(date: Date, score: Int)]
    ) -> WeeklyHealthData {

        let avgScore = scores.isEmpty ? 0 : scores.map { $0.score }.reduce(0, +) / scores.count

        // Compute metric ranges
        var metricRanges: [String: MetricRange] = [:]
        var metricValues: [HealthMetricType: [Double]] = [:]

        for day in weeklyData {
            for (type, value) in day.metrics {
                metricValues[type, default: []].append(value)
            }
        }

        for (type, values) in metricValues where !values.isEmpty {
            let (unit, _) = metricInfo(for: type, value: values[0])
            metricRanges[type.displayName] = MetricRange(
                min: values.min() ?? 0,
                max: values.max() ?? 0,
                average: values.reduce(0, +) / Double(values.count),
                unit: unit
            )
        }

        // Build daily summaries
        let dailySummaries = weeklyData.map { day -> DaySummary in
            var keyMetrics: [String: Double] = [:]
            for (type, value) in day.metrics {
                keyMetrics[type.displayName] = value
            }
            return DaySummary(
                date: day.date,
                score: day.lifeIndexScore ?? 0,
                keyMetrics: keyMetrics
            )
        }

        return WeeklyHealthData(
            dailyScores: scores,
            averageScore: avgScore,
            metricRanges: metricRanges,
            dailySummaries: dailySummaries
        )
    }

    // MARK: - Trend Analysis

    private func computeTrends(
        from weeklyData: [DailyHealthSummary],
        scores: [(date: Date, score: Int)]
    ) -> HealthTrends {
        var insights: [TrendInsight] = []

        // Score trend (compare first half vs second half of week)
        let scoreTrend = computeScoreTrend(scores)
        if scoreTrend == .declining {
            insights.append(TrendInsight(
                category: "score",
                message: "Your LifeIndex score has been declining over the past few days",
                priority: 1
            ))
        }

        // Sleep trend
        let sleepValues = weeklyData.compactMap { $0.metrics[.sleepDuration] }
        let sleepTrend = computeMetricTrend(sleepValues)
        if sleepTrend == .declining && sleepValues.last ?? 0 < 420 {  // < 7 hours
            insights.append(TrendInsight(
                category: "sleep",
                message: "Sleep duration trending down - aim for 7-9 hours",
                priority: 1
            ))
        }

        // Activity trend (steps)
        let stepValues = weeklyData.compactMap { $0.metrics[.steps] }
        let activityTrend = computeMetricTrend(stepValues)

        // HRV trend (higher is better)
        let hrvValues = weeklyData.compactMap { $0.metrics[.heartRateVariability] }
        let hrvTrend = computeMetricTrend(hrvValues)
        if hrvTrend == .declining {
            insights.append(TrendInsight(
                category: "heart",
                message: "HRV trending down - consider rest and stress management",
                priority: 2
            ))
        }

        // Compare today to weekly average
        if let todaySleep = weeklyData.first?.metrics[.sleepDuration],
           let avgSleep = sleepValues.isEmpty ? nil : sleepValues.reduce(0, +) / Double(sleepValues.count) {
            let diff = ((todaySleep - avgSleep) / avgSleep) * 100
            if abs(diff) > 15 {
                let direction = diff > 0 ? "above" : "below"
                insights.append(TrendInsight(
                    category: "sleep",
                    message: "Last night's sleep was \(abs(Int(diff)))% \(direction) your weekly average",
                    priority: 2
                ))
            }
        }

        // Sort insights by priority
        let sortedInsights = insights.sorted { $0.priority < $1.priority }

        return HealthTrends(
            scoreChange: scoreTrend,
            sleepTrend: sleepTrend,
            activityTrend: activityTrend,
            hrvTrend: hrvTrend,
            insights: Array(sortedInsights.prefix(5))
        )
    }

    private func computeScoreTrend(_ scores: [(date: Date, score: Int)]) -> TrendDirection {
        guard scores.count >= 4 else { return .insufficient }

        let sorted = scores.sorted { $0.date < $1.date }
        let midpoint = sorted.count / 2
        let firstHalf = sorted.prefix(midpoint).map { $0.score }
        let secondHalf = sorted.suffix(midpoint).map { $0.score }

        let firstAvg = Double(firstHalf.reduce(0, +)) / Double(firstHalf.count)
        let secondAvg = Double(secondHalf.reduce(0, +)) / Double(secondHalf.count)

        let change = secondAvg - firstAvg
        if change > 5 { return .improving }
        if change < -5 { return .declining }
        return .stable
    }

    private func computeMetricTrend(_ values: [Double]) -> TrendDirection {
        guard values.count >= 3 else { return .insufficient }

        let midpoint = values.count / 2
        let firstAvg = values.prefix(midpoint).reduce(0, +) / Double(midpoint)
        let secondAvg = values.suffix(midpoint).reduce(0, +) / Double(midpoint)

        let percentChange = ((secondAvg - firstAvg) / firstAvg) * 100
        if percentChange > 10 { return .improving }
        if percentChange < -10 { return .declining }
        return .stable
    }

    // MARK: - Mood Context

    private func buildMoodContext(from moodLogs: [MoodLog]) -> MoodContext {
        let today = Calendar.current.startOfDay(for: Date())
        let todayLogs = moodLogs.filter { Calendar.current.isDate($0.date ?? Date.distantPast, inSameDayAs: today) }
        let todayMood = todayLogs.first.map { Int($0.mood) }
        let todayNote = todayLogs.first?.note

        let weekLogs = moodLogs.filter { log in
            guard let date = log.date else { return false }
            return date > Calendar.current.date(byAdding: .day, value: -7, to: today)!
        }

        let weeklyAverage: Double? = weekLogs.isEmpty ? nil : Double(weekLogs.map { Int($0.mood) }.reduce(0, +)) / Double(weekLogs.count)

        let recentEntries = weekLogs.prefix(5).map { log in
            (date: log.date ?? Date(), mood: Int(log.mood), note: log.note)
        }

        let moodValues = weekLogs.map { Double($0.mood) }
        let moodTrend = computeMetricTrend(moodValues)

        return MoodContext(
            todayMood: todayMood,
            todayNote: todayNote,
            weeklyAverage: weeklyAverage,
            moodTrend: moodTrend,
            recentEntries: recentEntries
        )
    }

    // MARK: - Nutrition Context

    private func buildNutritionContext(from foodLogs: [FoodLog]) -> NutritionContext {
        let today = Calendar.current.startOfDay(for: Date())
        let todayLogs = foodLogs.filter { Calendar.current.isDate($0.date ?? Date.distantPast, inSameDayAs: today) }

        let totalCalories = todayLogs.map { Int($0.calories) }.reduce(0, +)
        let totalProtein = todayLogs.map { $0.protein }.reduce(0, +)
        let totalCarbs = todayLogs.map { $0.carbs }.reduce(0, +)
        let totalFat = todayLogs.map { $0.fat }.reduce(0, +)

        let calorieGoal = UserDefaults.standard.integer(forKey: "dailyCalorieGoal")
        let goal = calorieGoal > 0 ? calorieGoal : 2000
        let percentOfGoal = goal > 0 ? (totalCalories * 100) / goal : 0

        let recentMeals = todayLogs.prefix(3).compactMap { $0.name }

        return NutritionContext(
            todayCalories: totalCalories,
            todayProtein: totalProtein,
            todayCarbs: totalCarbs,
            todayFat: totalFat,
            calorieGoal: goal,
            percentOfGoal: percentOfGoal,
            recentMeals: recentMeals
        )
    }

    // MARK: - Helpers

    private func metricInfo(for type: HealthMetricType, value: Double) -> (unit: String, status: MetricStatus) {
        switch type {
        case .steps:
            let status: MetricStatus = value >= 10000 ? .excellent : (value >= 7500 ? .good : (value >= 5000 ? .normal : .belowTarget))
            return ("steps", status)
        case .heartRate:
            let status: MetricStatus = (60...100).contains(Int(value)) ? .good : .belowTarget
            return ("bpm", status)
        case .restingHeartRate:
            let status: MetricStatus = value < 60 ? .excellent : (value < 70 ? .good : (value < 80 ? .normal : .belowTarget))
            return ("bpm", status)
        case .heartRateVariability:
            let status: MetricStatus = value > 50 ? .excellent : (value > 30 ? .good : .belowTarget)
            return ("ms", status)
        case .bloodOxygen:
            let status: MetricStatus = value >= 95 ? .good : .belowTarget
            return ("%", status)
        case .activeCalories:
            let status: MetricStatus = value >= 500 ? .excellent : (value >= 300 ? .good : .belowTarget)
            return ("kcal", status)
        case .sleepDuration:
            let hours = value / 60
            let status: MetricStatus = hours >= 7 && hours <= 9 ? .excellent : (hours >= 6 ? .good : .belowTarget)
            return ("h:m", status)
        case .mindfulMinutes:
            let status: MetricStatus = value >= 10 ? .good : .normal
            return ("min", status)
        case .workoutMinutes:
            let status: MetricStatus = value >= 30 ? .excellent : (value >= 15 ? .good : .normal)
            return ("min", status)
        }
    }

    private func percentOfGoal(for type: HealthMetricType, value: Double) -> Double? {
        switch type {
        case .steps: return (value / 10000) * 100
        case .activeCalories: return (value / 500) * 100
        case .sleepDuration: return (value / 480) * 100  // 8 hours = 100%
        case .workoutMinutes: return (value / 30) * 100
        case .mindfulMinutes: return (value / 10) * 100
        default: return nil
        }
    }
}

// MARK: - Context to Prompt String

extension EnhancedHealthContext {

    /// Convert to structured text for LLM consumption
    func toPromptContext() -> String {
        var sections: [String] = []

        // User Profile
        sections.append("""
        === USER PROFILE ===
        Age: \(userProfile.age) years
        Gender: \(userProfile.gender)
        BMI: \(String(format: "%.1f", userProfile.bmi)) (\(userProfile.bmiCategory))
        Activity Level: \(userProfile.activityLevel)
        Goal: \(userProfile.goal)
        Daily Calorie Target: \(userProfile.dailyCalorieGoal) kcal
        """)

        // Today's Snapshot
        var todayLines = ["=== TODAY'S DATA ==="]
        todayLines.append("Date: \(formatDate(todaySnapshot.date))")
        todayLines.append("LifeIndex Score: \(todaySnapshot.lifeIndexScore)/100 (\(todaySnapshot.scoreLabel))")

        if let recovery = todaySnapshot.recoveryScore {
            todayLines.append("Recovery Score: \(recovery)/100")
        }

        for (name, metric) in todaySnapshot.metrics.sorted(by: { $0.key < $1.key }) {
            var line = "\(name): \(metric.formatted)"
            if let pct = metric.percentOfGoal {
                line += " (\(Int(pct))% of goal)"
            }
            todayLines.append(line)
        }

        if let stages = todaySnapshot.sleepStages {
            todayLines.append("Sleep Stages: Deep \(stages.deepSleepPercent)%, REM \(stages.remSleepPercent)%")
        }

        sections.append(todayLines.joined(separator: "\n"))

        // Trends & Insights (NEW - this is the key value-add)
        if !trends.insights.isEmpty {
            var trendLines = ["=== TRENDS & INSIGHTS ==="]
            trendLines.append("Score Trend: \(trends.scoreChange.description)")
            trendLines.append("Sleep Trend: \(trends.sleepTrend.description)")
            trendLines.append("Activity Trend: \(trends.activityTrend.description)")
            trendLines.append("HRV Trend: \(trends.hrvTrend.description)")
            trendLines.append("")
            for insight in trends.insights {
                trendLines.append("• [\(insight.category.uppercased())] \(insight.message)")
            }
            sections.append(trendLines.joined(separator: "\n"))
        }

        // Weekly Summary
        var weeklyLines = ["=== WEEKLY SUMMARY (7 days) ==="]
        weeklyLines.append("Average Score: \(weeklyData.averageScore)/100")

        for (name, range) in weeklyData.metricRanges.sorted(by: { $0.key < $1.key }) {
            weeklyLines.append("\(name) (Min/Avg/Max): \(range.formatted)")
        }

        // Daily scores
        weeklyLines.append("")
        weeklyLines.append("Daily Scores:")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, MMM d"
        for entry in weeklyData.dailyScores.sorted(by: { $0.date > $1.date }) {
            weeklyLines.append("  \(dateFormatter.string(from: entry.date)): \(entry.score)/100")
        }

        sections.append(weeklyLines.joined(separator: "\n"))

        // Mood
        if moodData.todayMood != nil || moodData.weeklyAverage != nil {
            var moodLines = ["=== MOOD & WELLNESS ==="]
            if let mood = moodData.todayMood {
                let labels = ["Bad", "Low", "Okay", "Good", "Great"]
                moodLines.append("Today's Mood: \(mood)/5 (\(labels[mood - 1]))")
            }
            if let note = moodData.todayNote, !note.isEmpty {
                moodLines.append("Note: \"\(note)\"")
            }
            if let avg = moodData.weeklyAverage {
                moodLines.append("Weekly Average: \(String(format: "%.1f", avg))/5")
            }
            moodLines.append("Mood Trend: \(moodData.moodTrend.description)")
            sections.append(moodLines.joined(separator: "\n"))
        }

        // Nutrition
        if nutritionData.todayCalories > 0 {
            var nutritionLines = ["=== NUTRITION ==="]
            nutritionLines.append("Calories: \(nutritionData.todayCalories)/\(nutritionData.calorieGoal) kcal (\(nutritionData.percentOfGoal)%)")
            nutritionLines.append("Protein: \(Int(nutritionData.todayProtein))g | Carbs: \(Int(nutritionData.todayCarbs))g | Fat: \(Int(nutritionData.todayFat))g")
            if !nutritionData.recentMeals.isEmpty {
                nutritionLines.append("Recent meals: \(nutritionData.recentMeals.joined(separator: ", "))")
            }
            sections.append(nutritionLines.joined(separator: "\n"))
        }

        // Recent Insights
        if !recentInsights.isEmpty {
            var insightLines = ["=== RECENT INSIGHTS ==="]
            for insight in recentInsights.prefix(3) {
                insightLines.append("• \(insight)")
            }
            sections.append(insightLines.joined(separator: "\n"))
        }

        return sections.joined(separator: "\n\n")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: date)
    }
}
