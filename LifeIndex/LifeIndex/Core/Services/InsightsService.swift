import Foundation
import SwiftUI
import Combine

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Insight Types

enum InsightType: String, Codable, CaseIterable {
    case morning      // Morning report - summarizes yesterday + today's goals
    case midday       // Midday check-in - progress so far
    case evening      // Evening wrap-up - day summary + sleep prep
    case realtime     // Real-time insight based on current data
    case weekly       // Weekly summary insight

    var displayName: String {
        switch self {
        case .morning: return "Morning Report"
        case .midday: return "Midday Check-in"
        case .evening: return "Evening Summary"
        case .realtime: return "Today's Insight"
        case .weekly: return "Weekly Summary"
        }
    }

    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .midday: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .realtime: return "sparkles"
        case .weekly: return "calendar"
        }
    }
}

// MARK: - Insights Service

@MainActor
class InsightsService: ObservableObject {
    static let shared = InsightsService()

    @Published var todayInsight: AIInsight?
    @Published var morningReport: AIInsight?
    @Published var isGenerating = false
    @Published var supportsAI = false
    @Published var insightHistory: [AIInsight] = []

    private let coreData = CoreDataStack.shared

    private init() {
        loadTodayInsights()
        loadInsightHistory()
        checkAISupport()
    }

    // MARK: - AI Support Check

    private func checkAISupport() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            supportsAI = true
        }
        #endif
    }

    // MARK: - Load from Core Data

    private func loadTodayInsights() {
        let today = Date()
        let insightType = currentInsightType()

        // Load today's main insight
        todayInsight = coreData.fetchAIInsight(for: today, type: insightType)

        // Load morning report if in morning
        if insightType == .morning || Calendar.current.component(.hour, from: today) < 12 {
            morningReport = coreData.fetchAIInsight(for: today, type: .morning)
        }
    }

    func loadInsightHistory() {
        insightHistory = coreData.fetchRecentAIInsights(limit: 30)
    }

    // MARK: - Auto-generate Today's Insight

    /// Auto-generates insight for today if not already generated
    func autoGenerateTodayInsight(
        score: Int,
        scoreLabel: String,
        scoreBreakdown: [(type: HealthMetricType, value: Double, score: Double)],
        sleepMinutes: Double?,
        sleepStages: SleepStages?,
        recoveryScore: Int?,
        steps: Double?,
        activeCalories: Double?,
        restingHR: Double?
    ) async {
        let insightType = currentInsightType()

        // Check if we already have today's insight of this type
        if let existing = coreData.fetchAIInsight(for: Date(), type: insightType) {
            todayInsight = existing
            return
        }

        // Generate new insight
        isGenerating = true

        let context = buildMetricsContext(
            score: score,
            scoreLabel: scoreLabel,
            scoreBreakdown: scoreBreakdown,
            sleepMinutes: sleepMinutes,
            sleepStages: sleepStages,
            recoveryScore: recoveryScore,
            steps: steps,
            activeCalories: activeCalories,
            restingHR: restingHR
        )

        let metrics = StoredMetrics(
            sleepMinutes: sleepMinutes,
            steps: steps,
            activeCalories: activeCalories,
            restingHeartRate: restingHR,
            recoveryScore: recoveryScore,
            deepSleepPercent: sleepStages?.deepPercent,
            remSleepPercent: sleepStages?.remPercent
        )

        let prompt = buildInsightPrompt(type: insightType, context: context)

        var shortText = ""
        var detailedText: String?

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), supportsAI {
            do {
                shortText = try await generateWithAI(prompt: prompt)
                if !shortText.isEmpty {
                    let detailedPrompt = buildDetailedPrompt(type: insightType, context: context)
                    detailedText = try await generateWithAI(prompt: detailedPrompt)
                }
            } catch {
                debugLog("[LifeIndex] AI insight generation failed: \(error)")
            }
        }
        #endif

        // Fallback to static insight
        if shortText.isEmpty {
            shortText = buildStaticInsight(
                type: insightType,
                score: score,
                scoreLabel: scoreLabel,
                scoreBreakdown: scoreBreakdown,
                sleepMinutes: sleepMinutes,
                steps: steps,
                recoveryScore: recoveryScore
            )
        }

        // Save to Core Data
        let insight = coreData.saveAIInsight(
            date: Date(),
            type: insightType,
            shortText: shortText,
            detailedText: detailedText,
            score: score,
            metrics: metrics
        )

        todayInsight = insight
        isGenerating = false
        loadInsightHistory()
    }

    /// Generate morning report (summarizes yesterday + encourages today)
    func autoGenerateMorningReport(
        yesterdayScore: Int?,
        yesterdayScoreLabel: String?,
        yesterdaySleep: Double?,
        yesterdaySteps: Double?,
        todayGoals: [String]
    ) async {
        // Check if we already have today's morning report
        if let existing = coreData.fetchAIInsight(for: Date(), type: .morning) {
            morningReport = existing
            return
        }

        isGenerating = true

        let context = buildMorningContext(
            yesterdayScore: yesterdayScore,
            yesterdayScoreLabel: yesterdayScoreLabel,
            yesterdaySleep: yesterdaySleep,
            yesterdaySteps: yesterdaySteps,
            todayGoals: todayGoals
        )

        let prompt = buildMorningReportPrompt(context: context)

        var shortText = ""
        var detailedText: String?

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), supportsAI {
            do {
                shortText = try await generateWithAI(prompt: prompt)
                if !shortText.isEmpty {
                    let detailedPrompt = buildDetailedMorningPrompt(context: context)
                    detailedText = try await generateWithAI(prompt: detailedPrompt)
                }
            } catch {
                debugLog("[LifeIndex] AI morning report generation failed: \(error)")
            }
        }
        #endif

        // Fallback
        if shortText.isEmpty {
            shortText = buildStaticMorningReport(
                yesterdayScore: yesterdayScore,
                yesterdayScoreLabel: yesterdayScoreLabel,
                yesterdaySleep: yesterdaySleep,
                yesterdaySteps: yesterdaySteps
            )
        }

        let metrics = StoredMetrics(
            sleepMinutes: yesterdaySleep,
            steps: yesterdaySteps
        )

        let insight = coreData.saveAIInsight(
            date: Date(),
            type: .morning,
            shortText: shortText,
            detailedText: detailedText,
            score: yesterdayScore ?? 0,
            metrics: metrics
        )

        morningReport = insight
        isGenerating = false
        loadInsightHistory()
    }

    // MARK: - Weekly Summary

    func generateWeeklySummary() async -> AIInsight? {
        let weeklyInsights = coreData.fetchAIInsightsForWeek(endingOn: Date())

        guard !weeklyInsights.isEmpty else { return nil }

        // Check if we already have this week's summary
        if let existing = coreData.fetchAIInsight(for: Date(), type: .weekly) {
            return existing
        }

        isGenerating = true

        let context = buildWeeklyContext(insights: weeklyInsights)
        let prompt = buildWeeklySummaryPrompt(context: context)

        var shortText = ""
        var detailedText: String?

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), supportsAI {
            do {
                shortText = try await generateWithAI(prompt: prompt)
                if !shortText.isEmpty {
                    let detailedPrompt = buildDetailedWeeklyPrompt(context: context)
                    detailedText = try await generateWithAI(prompt: detailedPrompt)
                }
            } catch {
                debugLog("[LifeIndex] AI weekly summary generation failed: \(error)")
            }
        }
        #endif

        // Fallback
        if shortText.isEmpty {
            shortText = buildStaticWeeklySummary(insights: weeklyInsights)
        }

        // Calculate average score
        let avgScore = weeklyInsights.isEmpty ? 0 : weeklyInsights.reduce(0) { $0 + Int($1.score) } / weeklyInsights.count

        let insight = coreData.saveAIInsight(
            date: Date(),
            type: .weekly,
            shortText: shortText,
            detailedText: detailedText,
            score: avgScore
        )

        isGenerating = false
        loadInsightHistory()
        return insight
    }

    // MARK: - Fetch Historical Insights

    func getInsight(for date: Date, type: InsightType) -> AIInsight? {
        return coreData.fetchAIInsight(for: date, type: type)
    }

    func getInsights(for date: Date) -> [AIInsight] {
        return coreData.fetchAIInsights(for: date)
    }

    // MARK: - AI Generation

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func generateWithAI(prompt: String) async throws -> String {
        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt)
        return response.content
    }
    #endif

    // MARK: - Helpers

    private func currentInsightType() -> InsightType {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return .morning
        case 11..<16: return .midday
        case 16..<22: return .evening
        default: return .realtime
        }
    }

    private func buildMetricsContext(
        score: Int,
        scoreLabel: String,
        scoreBreakdown: [(type: HealthMetricType, value: Double, score: Double)],
        sleepMinutes: Double?,
        sleepStages: SleepStages?,
        recoveryScore: Int?,
        steps: Double?,
        activeCalories: Double?,
        restingHR: Double?
    ) -> String {
        var lines: [String] = []

        // Time context
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let timeString = formatter.string(from: Date())
        lines.append("Current time: \(timeString)")

        // Score
        lines.append("LifeIndex Score: \(score)/100 (\(scoreLabel))")

        // Metrics
        if let sleep = sleepMinutes {
            let h = Int(sleep) / 60
            let m = Int(sleep) % 60
            lines.append("Sleep: \(h)h \(m)m")

            if let stages = sleepStages, stages.hasStageData {
                lines.append("  - Deep sleep: \(stages.deepPercent)%")
                lines.append("  - REM sleep: \(stages.remPercent)%")
            }
        }

        if let s = steps {
            lines.append("Steps: \(Int(s))")
        }

        if let cal = activeCalories {
            lines.append("Active calories: \(Int(cal))")
        }

        if let rhr = restingHR {
            lines.append("Resting heart rate: \(Int(rhr)) bpm")
        }

        if let recovery = recoveryScore {
            lines.append("Recovery score: \(recovery)/100")
        }

        return lines.joined(separator: "\n")
    }

    private func buildMorningContext(
        yesterdayScore: Int?,
        yesterdayScoreLabel: String?,
        yesterdaySleep: Double?,
        yesterdaySteps: Double?,
        todayGoals: [String]
    ) -> String {
        var lines: [String] = []

        lines.append("This is a MORNING report to start the user's day.")

        if let score = yesterdayScore, let label = yesterdayScoreLabel {
            lines.append("Yesterday's LifeIndex: \(score)/100 (\(label))")
        }

        if let sleep = yesterdaySleep {
            let h = Int(sleep) / 60
            let m = Int(sleep) % 60
            lines.append("Last night's sleep: \(h)h \(m)m")
        }

        if let steps = yesterdaySteps {
            lines.append("Yesterday's steps: \(Int(steps))")
        }

        if !todayGoals.isEmpty {
            lines.append("Today's goals: \(todayGoals.joined(separator: ", "))")
        }

        return lines.joined(separator: "\n")
    }

    private func buildWeeklyContext(insights: [AIInsight]) -> String {
        var lines: [String] = []

        lines.append("This is a WEEKLY summary of the user's health data.")

        let scores = insights.map { Int($0.score) }
        if !scores.isEmpty {
            let avg = scores.reduce(0, +) / scores.count
            let min = scores.min() ?? 0
            let max = scores.max() ?? 0
            lines.append("Weekly LifeIndex: Average \(avg), Range \(min)-\(max)")
        }

        // Aggregate metrics
        var totalSleep: Double = 0
        var totalSteps: Double = 0
        var sleepCount = 0
        var stepsCount = 0

        for insight in insights {
            if let metrics = insight.metrics {
                if let sleep = metrics.sleepMinutes {
                    totalSleep += sleep
                    sleepCount += 1
                }
                if let steps = metrics.steps {
                    totalSteps += steps
                    stepsCount += 1
                }
            }
        }

        if sleepCount > 0 {
            let avgSleepHours = (totalSleep / Double(sleepCount)) / 60.0
            lines.append("Average sleep: \(String(format: "%.1f", avgSleepHours)) hours/night")
        }

        if stepsCount > 0 {
            let avgSteps = Int(totalSteps / Double(stepsCount))
            lines.append("Average steps: \(avgSteps)/day")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Prompts

    private func buildInsightPrompt(type: InsightType, context: String) -> String {
        let timeRules: String
        switch type {
        case .morning:
            timeRules = "It's morning. Focus on sleep quality and set a positive tone for the day. Don't criticize low steps/calories yet."
        case .midday:
            timeRules = "It's midday. Check progress so far. Encourage if on track, suggest catch-up if behind."
        case .evening:
            timeRules = "It's evening. Summarize the day. Suggest winding down and preparing for quality sleep."
        case .realtime, .weekly:
            timeRules = "Give a current snapshot of health status."
        }

        return """
        You are a friendly, encouraging health coach in a mobile app. Write exactly 2 sentences.

        Sentence 1: Acknowledge the user's current status with their actual numbers.
        Sentence 2: Give ONE specific, actionable suggestion that feels achievable.

        Tone:
        - Warm and supportive, like a caring friend
        - Celebrate small wins ("Nice work on the 7 hours of sleep!")
        - Frame challenges positively ("You've got time to add some movement")
        - Be specific with numbers, not vague

        Time context: \(timeRules)

        Maximum 35 words total.

        User's data:
        \(context)
        """
    }

    private func buildDetailedPrompt(type: InsightType, context: String) -> String {
        """
        You are a friendly health coach. Write 3 short sections:

        ✨ Highlight: [1 sentence - best metric with the number and genuine praise]
        💪 Focus area: [1 sentence - area to improve with a specific, doable suggestion]
        🎯 Today's tip: [1 sentence - one concrete action for today]

        Be warm and encouraging. Use the user's actual numbers. Maximum 50 words total.

        User's data:
        \(context)
        """
    }

    private func buildMorningReportPrompt(context: String) -> String {
        """
        You are a friendly morning wellness coach. Write a brief, encouraging morning message (2 sentences).

        Sentence 1: Quick summary of how yesterday went OR how they slept (use actual numbers).
        Sentence 2: One encouraging, specific thing to focus on today.

        Tone: Warm, positive, like a supportive friend starting the day with you.
        Maximum 30 words.

        \(context)
        """
    }

    private func buildDetailedMorningPrompt(context: String) -> String {
        """
        You are a friendly morning wellness coach. Create a brief morning briefing:

        🌅 Good morning! [1 sentence - acknowledge yesterday or sleep quality]
        📊 Yesterday: [1 sentence - key highlight from yesterday]
        🎯 Today: [1 sentence - one achievable goal or focus]

        Be warm, encouraging, and specific. Maximum 45 words total.

        \(context)
        """
    }

    private func buildWeeklySummaryPrompt(context: String) -> String {
        """
        You are a friendly health coach. Write a brief weekly summary (2 sentences).

        Sentence 1: Acknowledge their week's effort with specific numbers (average score, sleep, steps).
        Sentence 2: One encouraging observation about their consistency or progress.

        Tone: Celebratory and motivating. Acknowledge effort regardless of numbers.
        Maximum 35 words.

        \(context)
        """
    }

    private func buildDetailedWeeklyPrompt(context: String) -> String {
        """
        You are a friendly health coach. Create a weekly health summary:

        📊 Week Overview: [1 sentence - average score and how the week went]
        ⭐ Best Day: [1 sentence - highlight what made it good]
        📈 Trend: [1 sentence - note improvement or consistency]
        🎯 Next Week: [1 sentence - one focus area for coming week]

        Be warm, encouraging, and specific. Maximum 60 words total.

        \(context)
        """
    }

    // MARK: - Static Fallbacks

    private func buildStaticInsight(
        type: InsightType,
        score: Int,
        scoreLabel: String,
        scoreBreakdown: [(type: HealthMetricType, value: Double, score: Double)],
        sleepMinutes: Double?,
        steps: Double?,
        recoveryScore: Int?
    ) -> String {
        // Find best and worst metrics
        let sorted = scoreBreakdown.sorted { $0.score > $1.score }
        _ = sorted.first
        _ = sorted.last

        switch type {
        case .morning:
            if let sleep = sleepMinutes {
                let h = Int(sleep) / 60
                if sleep >= 420 {
                    return "Great sleep last night - \(h)+ hours! You're starting the day well-rested. Let's make it a good one."
                } else {
                    return "You got \(h) hours of sleep. A bit less than ideal, but that's okay. Take it easy and stay hydrated today."
                }
            }
            return "Good morning! Your LifeIndex is \(score). Let's build on that today."

        case .midday:
            if let s = steps, s > 5000 {
                return "Nice progress - \(Int(s)) steps so far! Keep moving and you'll hit your goal."
            } else if let s = steps {
                return "You're at \(Int(s)) steps. A short walk after lunch could boost your energy and step count."
            }
            return "Midday check: score is \(score). Plenty of day left to keep it going!"

        case .evening:
            if score >= 80 {
                return "Excellent day! Your LifeIndex hit \(score). Wind down with some relaxation - you've earned it."
            } else if score >= 60 {
                return "Solid day with a score of \(score). Time to relax and prepare for quality sleep tonight."
            } else {
                return "Your score is \(score) today. Tomorrow's a fresh start. Focus on getting good sleep tonight."
            }

        case .realtime:
            return "Your LifeIndex is \(score) (\(scoreLabel))."

        case .weekly:
            return "Your weekly average score is \(score). Keep up the consistent effort!"
        }
    }

    private func buildStaticMorningReport(
        yesterdayScore: Int?,
        yesterdayScoreLabel: String?,
        yesterdaySleep: Double?,
        yesterdaySteps: Double?
    ) -> String {
        var parts: [String] = []

        if let sleep = yesterdaySleep {
            let h = Int(sleep) / 60
            if sleep >= 420 {
                parts.append("Great sleep last night - \(h)+ hours!")
            } else {
                parts.append("You got \(h) hours of sleep.")
            }
        }

        if let score = yesterdayScore {
            if score >= 80 {
                parts.append("Yesterday was excellent (\(score)).")
            } else if score >= 60 {
                parts.append("Yesterday's score was \(score).")
            } else {
                parts.append("Yesterday was \(score) - today's a new opportunity!")
            }
        }

        parts.append("Make today great!")

        return parts.joined(separator: " ")
    }

    private func buildStaticWeeklySummary(insights: [AIInsight]) -> String {
        let scores = insights.map { Int($0.score) }
        guard !scores.isEmpty else {
            return "Track your health this week to see your weekly summary!"
        }

        let avg = scores.reduce(0, +) / scores.count
        let daysTracked = insights.count

        if avg >= 70 {
            return "Great week! You averaged \(avg) across \(daysTracked) days. Keep up the momentum!"
        } else if avg >= 50 {
            return "Solid effort this week with an average of \(avg). Small improvements add up!"
        } else {
            return "You tracked \(daysTracked) days this week. Every day of tracking is progress!"
        }
    }

    // MARK: - Notification Insights

    /// Get insight text appropriate for the current time (for notifications)
    func getNotificationInsight(
        score: Int,
        sleepMinutes: Double?,
        steps: Double?,
        recoveryScore: Int?
    ) -> String {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 7..<10:
            // Morning notification
            if let sleep = sleepMinutes {
                let h = Int(sleep) / 60
                if sleep >= 420 {
                    return "Good morning! You got \(h) hours of sleep. Ready to make today great?"
                } else {
                    return "Morning! \(h) hours of sleep last night. Take it easy and stay hydrated today."
                }
            }
            return "Good morning! Your LifeIndex is ready. Start your day with intention."

        case 12..<14:
            // Midday notification
            if let s = steps {
                if s >= 5000 {
                    return "Midday check: \(Int(s)) steps! You're on track. Keep moving!"
                } else {
                    return "Midday reminder: \(Int(s)) steps so far. A short walk could boost your energy!"
                }
            }
            return "Midday check-in: How's your energy? Take a stretch break if you can."

        case 19..<22:
            // Evening notification
            if score >= 80 {
                return "Evening wrap-up: Great day with \(score)! Time to wind down."
            } else if score >= 60 {
                return "Today's score: \(score). Not bad! Prioritize good sleep tonight."
            } else {
                return "Today was \(score). Tomorrow's fresh. Get some rest!"
            }

        default:
            return "Your LifeIndex score is \(score). Keep taking care of yourself!"
        }
    }
}
