import SwiftUI
import Combine
import HealthKit
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var lifeIndexScore: Int = 0
    @Published var scoreLabel: String = "—"
    @Published var isLoading = true
    @Published var hasData = false
    @Published var showingYesterdayData = false

    // Score explanation (Phase 3)
    @Published var scoreExplanation: String = ""
    @Published var topContributor: ScoreContributor?
    @Published var weakestArea: ScoreContributor?

    // Score breakdown per metric (0.0 - 1.0)
    @Published var scoreBreakdown: [(type: HealthMetricType, score: Double, value: Double)] = []

    // Activity ring data
    @Published var stepsValue: Double = 0
    @Published var stepsGoal: Double = 10000
    @Published var caloriesValue: Double = 0
    @Published var caloriesGoal: Double = 500
    @Published var workoutMinutesValue: Double = 0
    @Published var workoutMinutesGoal: Double = 30

    // Apple Activity Summary (Phase 6)
    @Published var activitySummary: HKActivitySummaryWrapper?

    // Heart section
    @Published var heartRate: Double?
    @Published var restingHeartRate: Double?
    @Published var hrv: Double?
    @Published var bloodOxygen: Double?

    // Sleep section
    @Published var sleepMinutes: Double?

    // Wellness
    @Published var mindfulMinutes: Double?

    // Recovery
    @Published var recoveryScore: Int?
    @Published var recoveryLabel: String = "—"

    // Weekly trends
    @Published var weeklyData: [DailyHealthSummary] = []

    // Historical scores (7-day)
    @Published var weeklyScores: [(date: Date, score: Int)] = []
    @Published var yesterdayScore: Int?
    @Published var weeklyAverageScore: Int?

    // Recent workouts
    @Published var recentWorkouts: [WorkoutData] = []

    // Insights (Phase 4 — priority-based)
    @Published var insights: [HealthInsight] = []

    // AI Health Summary (Phase 7)
    @Published var aiShortSummary: String?
    @Published var aiDetailedSummary: String?
    @Published var isGeneratingDetailed = false
    @Published var supportsAI = false

    private var healthKitManager: HealthKitManager?
    private var lastLoadedAt: Date?
    private var isLoadInProgress = false
    private let cacheInterval: TimeInterval = 300 // 5 minutes

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
        default: return "Good Night"
        }
    }

    var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }

    func configure(with manager: HealthKitManager) {
        self.healthKitManager = manager
    }

    func loadData(forceRefresh: Bool = false) async {
        guard let manager = healthKitManager else {
            print("[LifeIndex] No healthKitManager configured")
            return
        }

        // Skip if already loading (prevent concurrent loads)
        if isLoadInProgress {
            print("[LifeIndex] Load already in progress, skipping")
            return
        }

        // Skip if data was loaded recently (cache still fresh)
        if !forceRefresh, let lastLoaded = lastLoadedAt,
           Date().timeIntervalSince(lastLoaded) < cacheInterval {
            print("[LifeIndex] Data is fresh (loaded \(Int(Date().timeIntervalSince(lastLoaded)))s ago), skipping reload")
            return
        }

        isLoadInProgress = true
        isLoading = true

        // Ensure authorization before fetching
        if !manager.isAuthorized {
            do {
                try await manager.requestAuthorization()
            } catch {
                print("[LifeIndex] Authorization error: \(error)")
            }
        }

        await manager.fetchTodaySummary()
        await manager.fetchWeeklyData()
        await manager.fetchRecentWorkouts()

        var summary = manager.todaySummary

        // If today has no metrics (common with Garmin — data syncs with delay),
        // fall back to the most recent day that has data
        showingYesterdayData = false
        if summary.metrics.isEmpty {
            if let recentDay = manager.weeklyData.last(where: { !$0.metrics.isEmpty }) {
                summary = recentDay
                showingYesterdayData = true
                print("[LifeIndex] Today empty, using data from \(recentDay.date.shortDayName)")
            }
        }

        // Score (time-aware: cumulative targets scale by time of day)
        let now = Date()
        lifeIndexScore = LifeIndexScoreEngine.calculateScore(from: summary, timeAware: !showingYesterdayData, at: now)
        scoreLabel = LifeIndexScoreEngine.label(for: lifeIndexScore, at: now)

        // Score breakdown (time-aware for today, absolute for yesterday)
        buildScoreBreakdown(from: summary, timeAware: !showingYesterdayData)

        // Score explanation + contributors (Phase 3)
        buildScoreExplanation()

        // Activity
        stepsValue = summary.metrics[.steps] ?? 0
        caloriesValue = summary.metrics[.activeCalories] ?? 0
        workoutMinutesValue = summary.metrics[.workoutMinutes] ?? 0

        // Apple Activity Summary (Phase 6)
        await fetchActivitySummary(manager: manager)

        // Heart
        heartRate = summary.metrics[.heartRate]
        restingHeartRate = summary.metrics[.restingHeartRate]
        hrv = summary.metrics[.heartRateVariability]
        bloodOxygen = summary.metrics[.bloodOxygen]

        // Sleep
        sleepMinutes = summary.metrics[.sleepDuration]

        // Wellness
        mindfulMinutes = summary.metrics[.mindfulMinutes]

        // Recovery
        let recScore = RecoveryScoreEngine.calculateScore(
            hrv: hrv, restingHeartRate: restingHeartRate, sleepMinutes: sleepMinutes
        )
        recoveryScore = recScore
        recoveryLabel = recScore.map { RecoveryScoreEngine.label(for: $0) } ?? "—"

        // Weekly
        weeklyData = manager.weeklyData

        // Historical scores (calculate final score for each day, no time scaling)
        weeklyScores = manager.weeklyData.compactMap { day in
            guard !day.metrics.isEmpty else { return nil }
            let score = LifeIndexScoreEngine.calculateFinalScore(from: day)
            return (date: day.date, score: score)
        }
        // Yesterday's score
        let calendar = Calendar.current
        yesterdayScore = weeklyScores
            .first(where: { calendar.isDateInYesterday($0.date) })
            .map { $0.score }
        // Weekly average
        if !weeklyScores.isEmpty {
            weeklyAverageScore = weeklyScores.reduce(0) { $0 + $1.score } / weeklyScores.count
        } else {
            weeklyAverageScore = nil
        }

        // Workouts
        recentWorkouts = Array(manager.recentWorkouts.prefix(3))

        // Check has data
        hasData = !summary.metrics.isEmpty || !recentWorkouts.isEmpty || weeklyData.contains { !$0.metrics.isEmpty }

        // Insights (Phase 4 — priority-based)
        buildPriorityInsights(from: summary, weekly: manager.weeklyData)

        // AI Summary (Phase 7)
        checkAISupport()
        await generateShortSummary(from: summary)

        isLoading = false
        isLoadInProgress = false
        lastLoadedAt = Date()
    }

    // MARK: - Phase 3: Score Explanation

    private func buildScoreExplanation() {
        scoreExplanation = explanationText(for: lifeIndexScore)

        guard !scoreBreakdown.isEmpty else {
            topContributor = nil
            weakestArea = nil
            return
        }

        let sorted = scoreBreakdown.sorted { $0.score > $1.score }
        if let best = sorted.first {
            topContributor = ScoreContributor(
                name: best.type.displayName,
                percentage: best.score * 100
            )
        }
        if let worst = sorted.last, sorted.count > 1 {
            weakestArea = ScoreContributor(
                name: worst.type.displayName,
                percentage: worst.score * 100
            )
        }
    }

    private func explanationText(for score: Int) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let isMorning = hour < 12

        switch score {
        case 90...100:
            return "Outstanding day. All your metrics are in excellent shape."
        case 80..<90:
            return "Most metrics are on track. A small push could get you to Excellent."
        case 70..<80:
            return "Solid effort today. Focus on your weaker areas to level up."
        case 60..<70:
            return isMorning
                ? "Your day is shaping up. Sleep and vitals look decent — keep building."
                : "A decent day, but a couple areas could use a boost."
        case 40..<60:
            return isMorning
                ? "Still early — your sleep and vitals set the foundation. Activity will build through the day."
                : "Some metrics are off today. Prioritize what you can still control."
        case 20..<40:
            return isMorning
                ? "Your day is just getting started. Focus on what's ahead, not what's missing yet."
                : "Your body may need extra care today. Rest and recover."
        default:
            return isMorning
                ? "Good morning — your score will build as the day progresses."
                : "Take it easy. Focus on the basics: sleep, hydration, movement."
        }
    }

    // MARK: - Phase 3: Score Breakdown

    private func buildScoreBreakdown(from summary: DailyHealthSummary, timeAware: Bool = true) {
        let factor = timeAware ? LifeIndexScoreEngine.dayProgressFactor() : 1.0

        scoreBreakdown = HealthMetricType.allCases.compactMap { type in
            guard let value = summary.metrics[type],
                  let target = LifeIndexScoreEngine.targets[type] else { return nil }
            let effectiveTarget = LifeIndexScoreEngine.scaledTarget(for: type, target: target, factor: factor)
            let score = LifeIndexScoreEngine.scoreMetric(value: value, target: effectiveTarget, type: type)
            return (type: type, score: score, value: value)
        }
    }

    // MARK: - Phase 4: Priority-Based Insights

    private func buildPriorityInsights(from summary: DailyHealthSummary, weekly: [DailyHealthSummary]) {
        var candidates: [(insight: HealthInsight, priority: Int)] = []

        // --- Sleep insights ---
        if let sleep = summary.metrics[.sleepDuration] {
            let hours = Int(sleep / 60)
            let mins = Int(sleep) % 60
            if sleep < 360 {
                candidates.append((
                    HealthInsight(icon: "exclamationmark.triangle.fill",
                                  text: "Only \(hours)h \(mins)m of sleep. This significantly impacts recovery and focus.",
                                  color: .red, priority: 90),
                    90
                ))
            } else if sleep < 420 {
                candidates.append((
                    HealthInsight(icon: "moon.zzz.fill",
                                  text: "You slept \(hours)h \(mins)m — under the 7hr minimum. Aim for 7+ tonight.",
                                  color: .orange, priority: 60),
                    60
                ))
            } else if sleep <= 540 {
                candidates.append((
                    HealthInsight(icon: "checkmark.circle.fill",
                                  text: "Great sleep — \(hours)h \(mins)m is in the ideal 7-9hr range.",
                                  color: .green, priority: 20),
                    20
                ))
            } else {
                candidates.append((
                    HealthInsight(icon: "bed.double.fill",
                                  text: "You slept \(hours)h \(mins)m — a bit over the 9hr mark.",
                                  color: Theme.sleep, priority: 30),
                    30
                ))
            }
        }

        // --- Steps insights ---
        if let steps = summary.metrics[.steps] {
            if steps < 5000 && steps > 0 {
                let pct = Int((steps / 10000) * 100)
                candidates.append((
                    HealthInsight(icon: "figure.walk",
                                  text: "Only \(Int(steps)) steps (\(pct)%). Try to get moving — every step counts.",
                                  color: .orange, priority: 75),
                    75
                ))
            } else if steps >= 5000 && steps < 10000 {
                let remaining = Int(10000 - steps)
                let pct = Int((steps / 10000) * 100)
                candidates.append((
                    HealthInsight(icon: "figure.walk",
                                  text: "\(pct)% to your 10k goal. \(remaining) steps to go!",
                                  color: Theme.steps, priority: 50),
                    50
                ))
            } else if steps >= 10000 && steps < 15000 {
                candidates.append((
                    HealthInsight(icon: "star.fill",
                                  text: "\(Int(steps)) steps — 10k goal smashed!",
                                  color: .green, priority: 20),
                    20
                ))
            } else if steps >= 15000 {
                candidates.append((
                    HealthInsight(icon: "star.circle.fill",
                                  text: "\(Int(steps)) steps — exceptional day!",
                                  color: .green, priority: 15),
                    15
                ))
            }
        }

        // --- Resting HR insights ---
        if let rhr = summary.metrics[.restingHeartRate] {
            if rhr > 80 {
                candidates.append((
                    HealthInsight(icon: "heart.circle",
                                  text: "Resting HR \(Int(rhr)) bpm — elevated. Stay hydrated and manage stress.",
                                  color: .orange, priority: 85),
                    85
                ))
            } else if rhr <= 55 {
                candidates.append((
                    HealthInsight(icon: "heart.circle",
                                  text: "Resting HR \(Int(rhr)) bpm — strong cardiovascular fitness.",
                                  color: Theme.heartRate, priority: 25),
                    25
                ))
            } else if rhr <= 65 {
                candidates.append((
                    HealthInsight(icon: "heart.circle",
                                  text: "Resting HR \(Int(rhr)) bpm — healthy range.",
                                  color: Theme.heartRate, priority: 30),
                    30
                ))
            }
        }

        // --- Compound insight: poor sleep + elevated HR ---
        if let sleep = summary.metrics[.sleepDuration],
           let rhr = summary.metrics[.restingHeartRate],
           sleep < 420 && rhr > 70 {
            candidates.append((
                HealthInsight(icon: "exclamationmark.circle.fill",
                              text: "Poor sleep combined with elevated heart rate. Your body may need extra recovery today.",
                              color: .red, priority: 95),
                95
            ))
        }

        // --- Recovery insight ---
        if let recovery = recoveryScore, recovery < 40 {
            candidates.append((
                HealthInsight(icon: "arrow.counterclockwise.circle.fill",
                              text: "Recovery score is \(recovery)/100. Consider a lighter workout or rest day.",
                              color: .orange, priority: 88),
                88
            ))
        }

        // --- Weekly step trend ---
        let weeklySteps = weekly.compactMap { $0.metrics[.steps] }
        if weeklySteps.count >= 5 {
            let recentHalf = Array(weeklySteps.suffix(3))
            let olderHalf = Array(weeklySteps.prefix(weeklySteps.count - 3))
            let recentAvg = recentHalf.reduce(0, +) / Double(recentHalf.count)
            let olderAvg = olderHalf.reduce(0, +) / Double(olderHalf.count)

            if recentAvg < olderAvg * 0.8 {
                candidates.append((
                    HealthInsight(icon: "chart.line.downtrend.xyaxis",
                                  text: "Step count declining this week. Your recent avg (\(Int(recentAvg))) is below your earlier avg (\(Int(olderAvg))).",
                                  color: .orange, priority: 65),
                    65
                ))
            } else if weeklySteps.count >= 3 {
                let avg = weeklySteps.reduce(0, +) / Double(weeklySteps.count)
                candidates.append((
                    HealthInsight(icon: "chart.line.uptrend.xyaxis",
                                  text: "7-day step avg: \(Int(avg)). Consistency is key.",
                                  color: Theme.activity, priority: 15),
                    15
                ))
            }
        } else if weeklySteps.count >= 3 {
            let avg = weeklySteps.reduce(0, +) / Double(weeklySteps.count)
            candidates.append((
                HealthInsight(icon: "chart.line.uptrend.xyaxis",
                              text: "7-day step avg: \(Int(avg)). Consistency is key.",
                              color: Theme.activity, priority: 15),
                15
            ))
        }

        // Sort by priority (highest first) and take top 4
        let sorted = candidates.sorted { $0.priority > $1.priority }
        insights = Array(sorted.prefix(4).map { $0.insight })
    }

    // MARK: - Phase 6: Apple Activity Summary

    private func fetchActivitySummary(manager: HealthKitManager) async {
        let summary = await Self.fetchActivitySummaryOffMain(healthStore: manager.healthStore)
        self.activitySummary = summary
    }

    nonisolated private static func fetchActivitySummaryOffMain(healthStore: HKHealthStore) async -> HKActivitySummaryWrapper? {
        let calendar = Calendar.current
        let now = Date()
        var dateComponents = calendar.dateComponents([.year, .month, .day, .era], from: now)
        dateComponents.calendar = calendar

        let predicate = HKQuery.predicateForActivitySummary(with: dateComponents)

        return await withCheckedContinuation { continuation in
            let query = HKActivitySummaryQuery(predicate: predicate) { _, summaries, error in
                if let error {
                    print("[LifeIndex] Activity summary error: \(error.localizedDescription)")
                }
                if let summary = summaries?.first {
                    continuation.resume(returning: HKActivitySummaryWrapper(summary: summary))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Phase 7: AI Health Summary

    private func checkAISupport() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            // Check if the model is actually available on this device
            let availability = SystemLanguageModel.default.availability
            supportsAI = (availability == .available)
            if !supportsAI {
                print("[LifeIndex] Foundation Models not available on this device (status: \(availability))")
            }
            return
        }
        #endif
        supportsAI = false
    }

    private func generateShortSummary(from summary: DailyHealthSummary) async {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), supportsAI {
            let prompt = buildShortPrompt()
            do {
                let text = try await generateWithFoundationModels(prompt: prompt)
                if !text.isEmpty {
                    aiShortSummary = text
                    return
                }
            } catch {
                print("[LifeIndex] Foundation Models (short) error: \(error.localizedDescription)")
                supportsAI = false // Don't retry if model fails
            }
        }
        #endif

        // Fallback: static short summary
        aiShortSummary = buildStaticShortSummary()
    }

    func generateDetailedSummary() async {
        guard aiDetailedSummary == nil else { return }
        isGeneratingDetailed = true

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), supportsAI {
            let prompt = buildDetailedPrompt()
            do {
                let text = try await generateWithFoundationModels(prompt: prompt)
                if !text.isEmpty {
                    aiDetailedSummary = text
                    isGeneratingDetailed = false
                    return
                }
            } catch {
                print("[LifeIndex] Foundation Models (detailed) error: \(error.localizedDescription)")
                supportsAI = false
            }
        }
        #endif

        // Fallback: static detailed summary
        aiDetailedSummary = buildStaticDetailedSummary()
        isGeneratingDetailed = false
    }

    // MARK: - AI Prompts

    private var currentTimeContext: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let timeString = formatter.string(from: Date())
        let hour = Calendar.current.component(.hour, from: Date())

        let period: String
        switch hour {
        case 5..<10: period = "early morning"
        case 10..<12: period = "late morning"
        case 12..<14: period = "midday"
        case 14..<17: period = "afternoon"
        case 17..<21: period = "evening"
        default: period = "night"
        }

        return "Current time: \(timeString) (\(period))"
    }

    private var timeOfDayRules: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 10 {
            return """
            TIME RULES: It is early morning. The user just started their day. \
            Do NOT comment negatively on low steps, active calories, or workout minutes — these metrics are not meaningful yet. \
            Focus on sleep quality, recovery status, and resting heart rate. \
            Frame the day positively as "ahead of you" not "behind."
            """
        } else if hour < 14 {
            return """
            TIME RULES: It is midday. Steps and activity are becoming relevant but may still be building. \
            Comment on progress so far. Sleep data is complete and fair game.
            """
        } else if hour < 18 {
            return """
            TIME RULES: It is afternoon. All metrics are fair to comment on. \
            Note what's been accomplished and what's still achievable today.
            """
        } else {
            return """
            TIME RULES: It is evening. The day is mostly done. \
            Summarize the day's performance. Suggest wind-down or sleep preparation if relevant.
            """
        }
    }

    private func buildMetricsContext() -> String {
        var lines: [String] = []
        lines.append(currentTimeContext)
        lines.append("LifeIndex Score: \(lifeIndexScore)/100 (\(scoreLabel))")

        for item in scoreBreakdown {
            let pct = Int(item.score * 100)
            let formatted = HealthDataPoint(type: item.type, value: item.value, date: .now).formattedValue
            lines.append("- \(item.type.displayName): \(formatted) \(item.type.unit) (\(pct)% of ideal)")
        }

        if let recovery = recoveryScore {
            lines.append("- Recovery: \(recovery)/100 (\(recoveryLabel))")
        }

        if let sleep = sleepMinutes {
            let h = Int(sleep) / 60, m = Int(sleep) % 60
            lines.append("- Sleep: \(h)h \(m)m")
        }

        return lines.joined(separator: "\n")
    }

    private func buildShortPrompt() -> String {
        """
        You are a concise health dashboard on a mobile app. Write exactly 2 sentences.
        Sentence 1: State the score and the single biggest factor (best or worst metric).
        Sentence 2: One specific, actionable suggestion based on the data.

        Rules:
        - No motivational filler ("great job", "keep it up", "every step counts", "remember that")
        - No hedging ("while", "however", "it's worth noting", "it's wonderful to see")
        - Use the user's actual numbers
        - Maximum 40 words total
        \(timeOfDayRules)

        \(buildMetricsContext())
        """
    }

    private func buildDetailedPrompt() -> String {
        """
        You are a health dashboard on a mobile app. Write exactly 3 short sections using this format:

        What's working: [1 sentence — strongest metric with the actual number and why it matters]
        Needs attention: [1 sentence — weakest metric with the actual number and a specific suggestion]
        Try this: [1 sentence — one concrete, specific action for today, not generic advice]

        Rules:
        - Maximum 60 words total across all 3 sections
        - Use the user's actual numbers, not vague references
        - No motivational filler or phrases like "it's great to see" or "remember that"
        - Be specific: "a 15-minute walk after lunch" not "try to be more active"
        \(timeOfDayRules)

        \(buildMetricsContext())
        """
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func generateWithFoundationModels(prompt: String) async throws -> String {
        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt)
        return response.content
    }
    #endif

    // MARK: - Static Fallbacks

    private func buildStaticShortSummary() -> String {
        guard !scoreBreakdown.isEmpty else { return "" }

        let hour = Calendar.current.component(.hour, from: Date())
        var parts: [String] = []

        if let top = topContributor {
            parts.append("Score \(lifeIndexScore) — \(top.name) leads at \(Int(top.percentage))%.")
        } else {
            parts.append("Your LifeIndex is \(lifeIndexScore) (\(scoreLabel)).")
        }

        if hour < 10, let weak = weakestArea, LifeIndexScoreEngine.cumulativeMetrics.contains(where: { $0.displayName == weak.name }) {
            // Morning: don't scold about cumulative metrics
            parts.append("Your day is just getting started.")
        } else if let weak = weakestArea, weak.percentage < 70 {
            parts.append("\(weak.name) at \(Int(weak.percentage))% has the most room to improve.")
        }

        return parts.joined(separator: " ")
    }

    private func buildStaticDetailedSummary() -> String {
        guard !scoreBreakdown.isEmpty else { return "" }

        var sections: [String] = []

        // What's working
        if let top = topContributor {
            let topMetric = scoreBreakdown.first { $0.type.displayName == top.name }
            let formatted = topMetric.map { HealthDataPoint(type: $0.type, value: $0.value, date: .now).formattedValue } ?? ""
            sections.append("What's working: \(top.name) at \(formatted) — scoring \(Int(top.percentage))% of ideal.")
        }

        // Needs attention
        if let weak = weakestArea, weak.percentage < 70 {
            let weakMetric = scoreBreakdown.first { $0.type.displayName == weak.name }
            let formatted = weakMetric.map { HealthDataPoint(type: $0.type, value: $0.value, date: .now).formattedValue } ?? ""
            sections.append("Needs attention: \(weak.name) at \(formatted) (\(Int(weak.percentage))%).")
        }

        // Try this
        if let weak = weakestArea {
            let hour = Calendar.current.component(.hour, from: Date())
            if weak.name == "Sleep" || weak.name == "Mindfulness" {
                if hour >= 18 {
                    sections.append("Try this: Start winding down 30 minutes earlier tonight.")
                } else {
                    sections.append("Try this: Set a bedtime reminder for tonight.")
                }
            } else if weak.name == "Steps" || weak.name == "Active Calories" {
                if hour < 14 {
                    sections.append("Try this: A 15-minute walk after lunch.")
                } else {
                    sections.append("Try this: A short evening walk to close the gap.")
                }
            } else {
                sections.append("Try this: Focus on \(weak.name) for a quick score boost.")
            }
        }

        return sections.joined(separator: "\n")
    }
}

// MARK: - Supporting Types

struct Highlight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let progress: Double?
    let color: Color
}

struct HealthInsight: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
    let color: Color
    let priority: Int

    init(icon: String, text: String, color: Color, priority: Int = 0) {
        self.icon = icon
        self.text = text
        self.color = color
        self.priority = priority
    }
}
