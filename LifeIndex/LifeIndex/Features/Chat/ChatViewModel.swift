import SwiftUI
import Combine
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isGenerating: Bool = false
    @Published var currentSession: ChatSession
    @Published var sessions: [ChatSession] = []
    @Published var supportsAI: Bool = false
    @Published var aiUnavailableReason: String? = nil
    @Published var followUpQuestions: [SuggestedQuestion] = []
    @Published var streamingContent: String = ""
    @Published var isReady: Bool = false

    // Track message IDs that should show typing animation
    @Published var animatingMessageIds: Set<UUID> = []

    // Health context from DashboardViewModel - published so view updates
    @Published var healthContext: HealthContext?

    private let persistence = ChatPersistence.shared

    // Foundation Models session for conversation context
    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private var languageModelSession: LanguageModelSession?
    #endif

    init() {
        self.currentSession = ChatSession()
        loadSessions()
        checkAISupport()
    }

    // MARK: - AI Support Check

    private func checkAISupport() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                supportsAI = true
                aiUnavailableReason = nil
                initializeLanguageModelSession()
            case .unavailable(let reason):
                supportsAI = false
                aiUnavailableReason = unavailableReasonMessage(reason)
            @unknown default:
                supportsAI = false
                aiUnavailableReason = "AI is not available on this device."
            }
            return
        }
        #endif
        supportsAI = false
        aiUnavailableReason = "Requires iOS 26 or later with Apple Intelligence."
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func unavailableReasonMessage(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence. Requires A17 Pro, M1, or newer chip."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is not enabled. Please enable it in Settings > Apple Intelligence & Siri."
        case .modelNotReady:
            return "The AI model is still downloading. Please try again later."
        @unknown default:
            return "AI is temporarily unavailable."
        }
    }

    @available(iOS 26.0, *)
    private func initializeLanguageModelSession() {
        let healthContextString = buildHealthContextString()

        languageModelSession = LanguageModelSession {
            """
            You are a friendly wellness coach in a personal health tracking app. Users ask about their fitness data, sleep, steps, heart rate, and general wellness tips. All questions are health and fitness related.

            RESPONSE STYLE:
            - 2-3 sentences max, be brief and encouraging
            - Reference the user's actual health numbers when relevant
            - Give practical, actionable wellness tips
            - For medical concerns, suggest consulting a doctor

            USER'S HEALTH METRICS:
            \(healthContextString)
            """
        }
    }

    @available(iOS 26.0, *)
    private func refreshSessionWithUpdatedContext() {
        // Reinitialize session with updated health context
        initializeLanguageModelSession()
    }
    #endif

    // MARK: - Session Management

    func loadSessions() {
        sessions = persistence.loadSessions().sorted { $0.startDate > $1.startDate }
    }

    func startNewSession() {
        // Save current session if it has messages
        if !currentSession.messages.isEmpty {
            persistence.saveSession(currentSession)
        }
        currentSession = ChatSession()
        messages = []
        followUpQuestions = []
        streamingContent = ""

        // Reset the language model session for fresh context
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), supportsAI {
            initializeLanguageModelSession()
        }
        #endif

        loadSessions()
    }

    func loadSession(_ session: ChatSession) {
        // Save current session first
        if !currentSession.messages.isEmpty {
            persistence.saveSession(currentSession)
        }
        currentSession = session
        messages = session.messages
        followUpQuestions = [] // Clear follow-ups when loading a session
    }

    func deleteSession(_ session: ChatSession) {
        persistence.deleteSession(session.id)
        loadSessions()
    }

    func clearAllHistory() {
        persistence.clearAllSessions()
        sessions = []
        // Start fresh
        currentSession = ChatSession()
        messages = []
        followUpQuestions = []
        streamingContent = ""

        // Reset the language model session
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), supportsAI {
            initializeLanguageModelSession()
        }
        #endif
    }

    // Update health context and refresh AI session
    func updateHealthContext(_ context: HealthContext?) {
        healthContext = context

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), supportsAI {
            refreshSessionWithUpdatedContext()
        }
        #endif

        // Mark as ready after context is set
        if !isReady {
            isReady = true
        }
    }

    // MARK: - Send Message

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Add user message
        let userMessage = ChatMessage(content: text, isUser: true)
        messages.append(userMessage)
        currentSession.messages.append(userMessage)
        inputText = ""

        // Generate title from first message
        if currentSession.title.isEmpty {
            currentSession.title = String(text.prefix(40))
        }

        // Add typing indicator
        let typingMessage = ChatMessage(content: "", isUser: false, isTyping: true)
        messages.append(typingMessage)
        isGenerating = true

        // Generate response
        let response = await generateResponse(for: text)

        // Remove typing indicator and add response
        messages.removeAll { $0.isTyping }
        let aiMessage = ChatMessage(content: response, isUser: false)
        // Mark this message for typing animation
        animatingMessageIds.insert(aiMessage.id)
        messages.append(aiMessage)
        currentSession.messages.append(aiMessage)

        isGenerating = false

        // Generate follow-up questions based on the response
        followUpQuestions = generateFollowUpQuestions(for: text, response: response)

        // Save session
        persistence.saveSession(currentSession)
        loadSessions()
    }

    func sendSuggestedQuestion(_ question: String) async {
        inputText = question
        await sendMessage()
    }

    func markAnimationComplete(for messageId: UUID) {
        animatingMessageIds.remove(messageId)
    }

    // MARK: - Response Generation

    private func generateResponse(for query: String) async -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), supportsAI {
            return await generateWithFoundationModels(query: query)
        }
        #endif

        // Fallback to rule-based responses
        return generateFallbackResponse(for: query)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func generateWithFoundationModels(query: String) async -> String {
        // Ensure session exists and has updated health context
        if languageModelSession == nil {
            initializeLanguageModelSession()
        }

        guard let session = languageModelSession else {
            return generateFallbackResponse(for: query)
        }

        do {
            // Use respond for synchronous response
            let response = try await session.respond(to: query)
            return response.content
        } catch {
            debugLog("[HealthAI] Foundation Models error: \(error.localizedDescription)")
            return generateFallbackResponse(for: query)
        }
    }
    #endif

    private func buildHealthContextString() -> String {
        guard let context = healthContext else {
            return "No health data available at this time."
        }

        var lines: [String] = []

        // Today's data
        lines.append("=== TODAY'S DATA ===")
        lines.append("LifeIndex Score: \(context.lifeIndexScore)/100 (\(context.scoreLabel))")

        if let steps = context.steps {
            lines.append("Steps today: \(Int(steps))")
        }
        if let calories = context.activeCalories {
            lines.append("Active calories: \(Int(calories)) kcal")
        }
        if let hr = context.heartRate {
            lines.append("Current heart rate: \(Int(hr)) bpm")
        }
        if let rhr = context.restingHeartRate {
            lines.append("Resting heart rate: \(Int(rhr)) bpm")
        }
        if let hrv = context.hrv {
            lines.append("HRV: \(Int(hrv)) ms")
        }
        if let sleep = context.sleepMinutes {
            let hours = Int(sleep) / 60
            let mins = Int(sleep) % 60
            lines.append("Sleep last night: \(hours)h \(mins)m")
        }
        if let recovery = context.recoveryScore {
            lines.append("Recovery score: \(recovery)/100")
        }
        if let workout = context.workoutMinutes {
            lines.append("Workout time today: \(Int(workout)) minutes")
        }

        // Mood data
        if let mood = context.todayMood {
            let moodLabels = ["Bad", "Low", "Okay", "Good", "Great"]
            let moodLabel = moodLabels[mood - 1]
            lines.append("Today's mood: \(mood)/5 (\(moodLabel))")
            if let note = context.todayMoodNote, !note.isEmpty {
                lines.append("Mood note: \"\(note)\"")
            }
        }
        if let moodAvg = context.weeklyMoodAverage {
            lines.append("7-day average mood: \(String(format: "%.1f", moodAvg))/5")
        }

        // Weekly summary
        if let avg = context.weeklyAverageScore {
            lines.append("\n=== WEEKLY SUMMARY ===")
            lines.append("7-day average score: \(avg)/100")
        }

        // Historical daily scores (last 7 days)
        if !context.weeklyScores.isEmpty {
            lines.append("\n=== DAILY SCORES (Last 7 days) ===")
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEE, MMM d"

            for entry in context.weeklyScores.sorted(by: { $0.date > $1.date }) {
                let dateStr = dateFormatter.string(from: entry.date)
                lines.append("\(dateStr): \(entry.score)/100")
            }
        }

        // Historical daily details
        if !context.historicalDays.isEmpty {
            lines.append("\n=== DAILY DETAILS (Last 7 days) ===")
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEE, MMM d"

            for day in context.historicalDays.sorted(by: { $0.date > $1.date }) {
                var dayLines: [String] = []
                let dateStr = dateFormatter.string(from: day.date)
                dayLines.append("\(dateStr):")

                // Extract metrics from the day
                for (type, value) in day.metrics {
                    switch type {
                    case .steps:
                        dayLines.append("  Steps: \(Int(value))")
                    case .activeCalories:
                        dayLines.append("  Active Calories: \(Int(value)) kcal")
                    case .sleepDuration:
                        let totalMins = Int(value)
                        let hours = totalMins / 60
                        let mins = totalMins % 60
                        dayLines.append("  Sleep: \(hours)h \(mins)m")
                    case .restingHeartRate:
                        dayLines.append("  Resting HR: \(Int(value)) bpm")
                    case .heartRateVariability:
                        dayLines.append("  HRV: \(Int(value)) ms")
                    case .heartRate:
                        dayLines.append("  Heart Rate: \(Int(value)) bpm")
                    case .workoutMinutes:
                        dayLines.append("  Workout: \(Int(value)) min")
                    case .mindfulMinutes:
                        dayLines.append("  Mindfulness: \(Int(value)) min")
                    case .bloodOxygen:
                        dayLines.append("  Blood Oxygen: \(Int(value))%")
                    }
                }

                // Add LifeIndex score if available
                if let score = day.lifeIndexScore {
                    dayLines.append("  LifeIndex: \(score)/100")
                }

                lines.append(contentsOf: dayLines)
            }
        }

        // Calculate metric ranges (min, max, average) from historical data
        if !context.historicalDays.isEmpty {
            lines.append("\n=== 7-DAY METRIC RANGES (Min / Avg / Max) ===")

            // Collect values for each metric type
            var stepValues: [Double] = []
            var calorieValues: [Double] = []
            var sleepValues: [Double] = []
            var restingHRValues: [Double] = []
            var hrvValues: [Double] = []
            var workoutValues: [Double] = []
            var heartRateValues: [Double] = []
            var mindfulValues: [Double] = []
            var bloodOxygenValues: [Double] = []

            for day in context.historicalDays {
                for (type, value) in day.metrics {
                    switch type {
                    case .steps:
                        stepValues.append(value)
                    case .activeCalories:
                        calorieValues.append(value)
                    case .sleepDuration:
                        sleepValues.append(value)
                    case .restingHeartRate:
                        restingHRValues.append(value)
                    case .heartRateVariability:
                        hrvValues.append(value)
                    case .workoutMinutes:
                        workoutValues.append(value)
                    case .heartRate:
                        heartRateValues.append(value)
                    case .mindfulMinutes:
                        mindfulValues.append(value)
                    case .bloodOxygen:
                        bloodOxygenValues.append(value)
                    }
                }
            }

            // Helper to format range string
            func formatRange(_ values: [Double], unit: String, divideBy: Double = 1) -> String? {
                guard !values.isEmpty else { return nil }
                let min = values.min()! / divideBy
                let max = values.max()! / divideBy
                let avg = values.reduce(0, +) / Double(values.count) / divideBy
                return String(format: "%.0f / %.0f / %.0f %@", min, avg, max, unit)
            }

            // Helper for sleep (hours and minutes)
            func formatSleepRange(_ values: [Double]) -> String? {
                guard !values.isEmpty else { return nil }
                let minMins = Int(values.min()!)
                let maxMins = Int(values.max()!)
                let avgMins = Int(values.reduce(0, +) / Double(values.count))

                func formatHM(_ mins: Int) -> String {
                    let h = mins / 60
                    let m = mins % 60
                    return "\(h)h\(m)m"
                }

                return "\(formatHM(minMins)) / \(formatHM(avgMins)) / \(formatHM(maxMins))"
            }

            // Add each metric range
            if let range = formatRange(stepValues, unit: "steps") {
                lines.append("Steps: \(range)")
            }
            if let range = formatRange(calorieValues, unit: "kcal") {
                lines.append("Active Calories: \(range)")
            }
            if let range = formatSleepRange(sleepValues) {
                lines.append("Sleep Duration: \(range)")
            }
            if let range = formatRange(restingHRValues, unit: "bpm") {
                lines.append("Resting Heart Rate: \(range)")
            }
            if let range = formatRange(hrvValues, unit: "ms") {
                lines.append("HRV: \(range)")
            }
            if let range = formatRange(workoutValues, unit: "min") {
                lines.append("Workout Time: \(range)")
            }
            if let range = formatRange(heartRateValues, unit: "bpm") {
                lines.append("Average Heart Rate: \(range)")
            }
            if let range = formatRange(mindfulValues, unit: "min") {
                lines.append("Mindfulness: \(range)")
            }
            if let range = formatRange(bloodOxygenValues, unit: "%") {
                lines.append("Blood Oxygen: \(range)")
            }

            // Add LifeIndex score range
            let scoreValues = context.historicalDays.compactMap { $0.lifeIndexScore }
            if !scoreValues.isEmpty {
                let minScore = scoreValues.min()!
                let maxScore = scoreValues.max()!
                let avgScore = scoreValues.reduce(0, +) / scoreValues.count
                lines.append("LifeIndex Score: \(minScore) / \(avgScore) / \(maxScore)")
            }
        }

        // Add insights
        if !context.insights.isEmpty {
            lines.append("\n=== RECENT INSIGHTS ===")
            for insight in context.insights.prefix(3) {
                lines.append("- \(insight)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func generateFallbackResponse(for query: String) -> String {
        let lowercased = query.lowercased()

        // Sleep-related queries
        if lowercased.contains("sleep") || lowercased.contains("tired") || lowercased.contains("rest") {
            if let sleep = healthContext?.sleepMinutes {
                let hours = Int(sleep) / 60
                if hours < 7 {
                    return "Based on your data, you got \(hours) hours of sleep last night, which is below the recommended 7-9 hours. Try setting a consistent bedtime and limiting screen time before bed to improve your sleep quality."
                } else {
                    return "You got \(hours) hours of sleep last night, which is in the healthy range! Maintaining this consistent sleep schedule will help your energy levels and recovery."
                }
            }
            return "I don't have your sleep data yet. Make sure your sleep tracking is enabled and synced."
        }

        // Activity-related queries
        if lowercased.contains("step") || lowercased.contains("walk") || lowercased.contains("active") || lowercased.contains("exercise") {
            if let steps = healthContext?.steps {
                let stepsInt = Int(steps)
                if stepsInt < 5000 {
                    return "You're at \(stepsInt) steps so far today. A short walk after lunch or taking stairs instead of the elevator can help you reach your goal!"
                } else if stepsInt < 10000 {
                    return "Nice progress! You're at \(stepsInt) steps. Just \(10000 - stepsInt) more to hit 10k. Keep moving!"
                } else {
                    return "Excellent! You've hit \(stepsInt) steps today - that's above the 10k goal! Your activity level is great."
                }
            }
            return "I don't have your step data yet. Make sure HealthKit permissions are enabled."
        }

        // Heart-related queries
        if lowercased.contains("heart") || lowercased.contains("pulse") || lowercased.contains("hrv") {
            var response = ""
            if let rhr = healthContext?.restingHeartRate {
                let rhrInt = Int(rhr)
                if rhrInt < 60 {
                    response = "Your resting heart rate is \(rhrInt) bpm, which indicates excellent cardiovascular fitness."
                } else if rhrInt <= 70 {
                    response = "Your resting heart rate is \(rhrInt) bpm, which is in the healthy normal range."
                } else {
                    response = "Your resting heart rate is \(rhrInt) bpm. Stress, caffeine, or lack of sleep can elevate it. Focus on relaxation and recovery."
                }
            }
            if let hrv = healthContext?.hrv {
                response += " Your HRV is \(Int(hrv)) ms, which reflects your body's recovery state."
            }
            return response.isEmpty ? "I don't have your heart data available right now." : response
        }

        // Recovery queries
        if lowercased.contains("recover") || lowercased.contains("ready") || lowercased.contains("workout") {
            if let recovery = healthContext?.recoveryScore {
                if recovery >= 80 {
                    return "Your recovery score is \(recovery)/100 - you're well-rested and ready for an intense workout!"
                } else if recovery >= 60 {
                    return "Your recovery score is \(recovery)/100. You can exercise, but consider a moderate intensity workout."
                } else {
                    return "Your recovery score is \(recovery)/100, which is on the lower side. Consider a rest day or light activity like yoga."
                }
            }
            return "I need more data to assess your recovery status. Make sure HRV and sleep tracking are enabled."
        }

        // Historical/trend queries
        if lowercased.contains("week") || lowercased.contains("days") || lowercased.contains("trend") ||
           lowercased.contains("history") || lowercased.contains("average") || lowercased.contains("past") {
            if let context = healthContext, !context.weeklyScores.isEmpty {
                var response = ""

                // Weekly average
                if let avg = context.weeklyAverageScore {
                    response = "Over the last 7 days, your average LifeIndex score was \(avg)/100. "
                }

                // Find best and worst days
                let sortedScores = context.weeklyScores.sorted { $0.score > $1.score }
                if let best = sortedScores.first, let worst = sortedScores.last {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "EEEE"
                    let bestDay = dateFormatter.string(from: best.date)
                    let worstDay = dateFormatter.string(from: worst.date)
                    response += "Your best day was \(bestDay) with \(best.score)/100, and your lowest was \(worstDay) with \(worst.score)/100. "
                }

                // Calculate trend
                let scores = context.weeklyScores.sorted { $0.date < $1.date }.map { $0.score }
                if scores.count >= 3 {
                    let firstHalf = scores.prefix(scores.count / 2).reduce(0, +) / max(scores.count / 2, 1)
                    let secondHalf = scores.suffix(scores.count / 2).reduce(0, +) / max(scores.count / 2, 1)
                    if secondHalf > firstHalf + 5 {
                        response += "You're trending upward - keep up the good habits!"
                    } else if secondHalf < firstHalf - 5 {
                        response += "Your scores have dipped recently - consider focusing on sleep and recovery."
                    } else {
                        response += "Your scores have been fairly consistent."
                    }
                }

                return response.isEmpty ? "I have your 7-day data available. Your weekly average is \(context.weeklyAverageScore ?? 0)/100." : response
            }
            return "I only have 7 days of historical data available. Ask me about your weekly trends or how specific metrics changed over the past week."
        }

        // Score queries
        if lowercased.contains("score") || lowercased.contains("lifeindex") || lowercased.contains("health") {
            if let context = healthContext {
                var response = "Your LifeIndex score is \(context.lifeIndexScore)/100 (\(context.scoreLabel)). "
                if let avg = context.weeklyAverageScore {
                    if context.lifeIndexScore > avg {
                        response += "That's above your 7-day average of \(avg)! "
                    } else if context.lifeIndexScore < avg {
                        response += "That's below your 7-day average of \(avg). "
                    } else {
                        response += "That matches your 7-day average. "
                    }
                }
                response += "This score combines your sleep, activity, heart health, and recovery data."
                return response
            }
        }

        // General greeting
        if lowercased.contains("hello") || lowercased.contains("hi") || lowercased.contains("hey") {
            return "Hello! I'm your health assistant. I can help you understand your health data, answer questions about sleep, activity, heart health, and recovery. I also have access to your last 7 days of data - ask me about trends!"
        }

        // Default response
        return "I can help you with questions about your sleep, activity, heart health, recovery, and weekly trends. Try asking 'How was my week?' or 'Show my sleep trends'."
    }

    // MARK: - Follow-up Questions Generation

    private func generateFollowUpQuestions(for query: String, response: String) -> [SuggestedQuestion] {
        let lowercasedQuery = query.lowercased()
        let lowercasedResponse = response.lowercased()
        var questions: [SuggestedQuestion] = []

        // Data-driven questions based on actual health metrics
        let context = healthContext

        // Sleep-related follow-ups with actual data
        if lowercasedQuery.contains("sleep") || lowercasedResponse.contains("sleep") {
            if let sleep = context?.sleepMinutes {
                let hours = Int(sleep) / 60
                if hours < 7 {
                    questions.append(SuggestedQuestion(icon: "moon.stars.fill", text: "Why did I only get \(hours)h sleep?", category: .sleep))
                    questions.append(SuggestedQuestion(icon: "bed.double.fill", text: "Tips to sleep longer?", category: .sleep))
                } else {
                    questions.append(SuggestedQuestion(icon: "chart.line.uptrend.xyaxis", text: "How's my sleep this week?", category: .sleep))
                }
            }
            questions.append(SuggestedQuestion(icon: "clock.fill", text: "What's my best bedtime?", category: .sleep))
            questions.append(SuggestedQuestion(icon: "waveform.path.ecg", text: "How does sleep affect my HRV?", category: .sleep))
        }

        // Activity-related follow-ups with actual data
        if lowercasedQuery.contains("step") || lowercasedQuery.contains("walk") || lowercasedQuery.contains("active") ||
           lowercasedQuery.contains("calorie") || lowercasedResponse.contains("step") || lowercasedResponse.contains("calorie") {
            if let steps = context?.steps {
                let stepsInt = Int(steps)
                if stepsInt < 10000 {
                    let remaining = 10000 - stepsInt
                    questions.append(SuggestedQuestion(icon: "figure.walk", text: "How to get \(remaining) more steps?", category: .activity))
                }
                questions.append(SuggestedQuestion(icon: "chart.bar.fill", text: "Compare my steps this week", category: .activity))
            }
            if let calories = context?.activeCalories {
                questions.append(SuggestedQuestion(icon: "flame.fill", text: "I burned \(Int(calories)) kcal - is that good?", category: .activity))
            }
            questions.append(SuggestedQuestion(icon: "figure.run", text: "Best time to exercise?", category: .activity))
        }

        // Heart-related follow-ups with actual data
        if lowercasedQuery.contains("heart") || lowercasedQuery.contains("hrv") || lowercasedQuery.contains("pulse") ||
           lowercasedResponse.contains("heart") || lowercasedResponse.contains("hrv") {
            if let hrv = context?.hrv {
                let hrvInt = Int(hrv)
                if hrvInt < 40 {
                    questions.append(SuggestedQuestion(icon: "waveform.path.ecg", text: "Why is my HRV low at \(hrvInt)ms?", category: .heart))
                } else {
                    questions.append(SuggestedQuestion(icon: "chart.line.uptrend.xyaxis", text: "HRV trend this week?", category: .heart))
                }
            }
            if let rhr = context?.restingHeartRate {
                questions.append(SuggestedQuestion(icon: "heart.circle.fill", text: "Is \(Int(rhr)) bpm resting HR normal?", category: .heart))
            }
            questions.append(SuggestedQuestion(icon: "lungs.fill", text: "Breathing exercises for heart health?", category: .heart))
        }

        // Recovery/workout follow-ups with actual data
        if lowercasedQuery.contains("recover") || lowercasedQuery.contains("workout") || lowercasedQuery.contains("exercise") ||
           lowercasedQuery.contains("ready") || lowercasedResponse.contains("recover") || lowercasedResponse.contains("workout") {
            if let recovery = context?.recoveryScore {
                if recovery >= 80 {
                    questions.append(SuggestedQuestion(icon: "figure.strengthtraining.traditional", text: "Best workout for \(recovery)% recovery?", category: .recovery))
                } else if recovery < 60 {
                    questions.append(SuggestedQuestion(icon: "bed.double.fill", text: "How to boost my \(recovery)% recovery?", category: .recovery))
                }
            }
            if let workout = context?.workoutMinutes, workout > 0 {
                questions.append(SuggestedQuestion(icon: "timer", text: "Is \(Int(workout)) min workout enough?", category: .recovery))
            }
            questions.append(SuggestedQuestion(icon: "arrow.counterclockwise", text: "Should I rest tomorrow?", category: .recovery))
        }

        // Score/LifeIndex follow-ups with actual data
        if lowercasedQuery.contains("score") || lowercasedQuery.contains("lifeindex") || lowercasedQuery.contains("index") ||
           lowercasedResponse.contains("score") || lowercasedResponse.contains("lifeindex") {
            if let ctx = context {
                if let avg = ctx.weeklyAverageScore {
                    if ctx.lifeIndexScore > avg {
                        questions.append(SuggestedQuestion(icon: "arrow.up.right", text: "Why am I above my \(avg) avg?", category: .general))
                    } else if ctx.lifeIndexScore < avg {
                        questions.append(SuggestedQuestion(icon: "arrow.down.right", text: "Why am I below my \(avg) avg?", category: .general))
                    }
                }
                questions.append(SuggestedQuestion(icon: "chart.line.uptrend.xyaxis", text: "Show my 7-day score trend", category: .general))
                questions.append(SuggestedQuestion(icon: "lightbulb.fill", text: "What can I improve today?", category: .general))
            }
        }

        // Trend/history follow-ups
        if lowercasedQuery.contains("week") || lowercasedQuery.contains("trend") || lowercasedQuery.contains("history") ||
           lowercasedQuery.contains("average") || lowercasedQuery.contains("compare") {
            questions.append(SuggestedQuestion(icon: "calendar", text: "What was my best day?", category: .general))
            questions.append(SuggestedQuestion(icon: "chart.bar.fill", text: "Compare all my metrics", category: .general))
            questions.append(SuggestedQuestion(icon: "arrow.triangle.2.circlepath", text: "Am I improving overall?", category: .general))
        }

        // If no specific topic matched, add smart general follow-ups based on current data
        if questions.isEmpty {
            // Add data-driven suggestions
            if let ctx = context {
                // Suggest based on what needs attention
                if let sleep = ctx.sleepMinutes, sleep < 420 {
                    questions.append(SuggestedQuestion(icon: "moon.zzz.fill", text: "Why was my sleep only \(Int(sleep)/60)h?", category: .sleep))
                }
                if let recovery = ctx.recoveryScore, recovery < 70 {
                    questions.append(SuggestedQuestion(icon: "battery.25percent", text: "How to improve my \(recovery)% recovery?", category: .recovery))
                }
                if let steps = ctx.steps, steps < 5000 {
                    questions.append(SuggestedQuestion(icon: "figure.walk", text: "Quick ways to get more steps?", category: .activity))
                }
            }

            // Add general exploration questions
            questions.append(SuggestedQuestion(icon: "sparkles", text: "Give me health insights", category: .general))
            questions.append(SuggestedQuestion(icon: "chart.line.uptrend.xyaxis", text: "How was my week overall?", category: .general))
            questions.append(SuggestedQuestion(icon: "heart.text.square", text: "What's my health summary?", category: .general))
        }

        // Remove duplicates and return first 3
        var seen = Set<String>()
        let unique = questions.filter { seen.insert($0.text).inserted }
        return Array(unique.prefix(3))
    }

    // MARK: - Suggested Questions (Initial Welcome Screen)

    var suggestedQuestions: [SuggestedQuestion] {
        var questions: [SuggestedQuestion] = []
        let ctx = healthContext

        // Personalized questions based on current health data
        if let ctx = ctx {
            // Sleep-based suggestions with actual numbers
            if let sleep = ctx.sleepMinutes {
                let hours = Int(sleep) / 60
                if hours < 6 {
                    questions.append(SuggestedQuestion(
                        icon: "moon.zzz.fill",
                        text: "Only \(hours)h sleep - how to improve?",
                        category: .sleep
                    ))
                } else if hours < 7 {
                    questions.append(SuggestedQuestion(
                        icon: "moon.fill",
                        text: "Got \(hours)h sleep - is that enough?",
                        category: .sleep
                    ))
                } else {
                    questions.append(SuggestedQuestion(
                        icon: "moon.stars.fill",
                        text: "Great \(hours)h sleep! What helped?",
                        category: .sleep
                    ))
                }
            }

            // Steps-based suggestions with actual numbers
            if let steps = ctx.steps {
                let stepsInt = Int(steps)
                if stepsInt < 3000 {
                    questions.append(SuggestedQuestion(
                        icon: "figure.walk",
                        text: "Only \(stepsInt) steps - quick ways to move?",
                        category: .activity
                    ))
                } else if stepsInt < 8000 {
                    let remaining = 10000 - stepsInt
                    questions.append(SuggestedQuestion(
                        icon: "shoeprints.fill",
                        text: "\(remaining) steps to 10K - tips?",
                        category: .activity
                    ))
                } else {
                    questions.append(SuggestedQuestion(
                        icon: "star.fill",
                        text: "Hit \(stepsInt) steps! What's next?",
                        category: .activity
                    ))
                }
            }

            // Recovery-based suggestions
            if let recovery = ctx.recoveryScore {
                if recovery >= 80 {
                    questions.append(SuggestedQuestion(
                        icon: "bolt.fill",
                        text: "\(recovery)% recovered - what workout?",
                        category: .recovery
                    ))
                } else if recovery < 60 {
                    questions.append(SuggestedQuestion(
                        icon: "battery.25percent",
                        text: "\(recovery)% recovery - should I rest?",
                        category: .recovery
                    ))
                }
            }

            // Score comparison suggestions
            if let avg = ctx.weeklyAverageScore {
                if ctx.lifeIndexScore > avg + 5 {
                    questions.append(SuggestedQuestion(
                        icon: "arrow.up.right.circle.fill",
                        text: "Score up from \(avg) avg - why?",
                        category: .general
                    ))
                } else if ctx.lifeIndexScore < avg - 5 {
                    questions.append(SuggestedQuestion(
                        icon: "arrow.down.right.circle",
                        text: "Below my \(avg) average - what's off?",
                        category: .general
                    ))
                }
            }

            // Heart health suggestions
            if let hrv = ctx.hrv {
                let hrvInt = Int(hrv)
                if hrvInt < 35 {
                    questions.append(SuggestedQuestion(
                        icon: "waveform.path.ecg",
                        text: "HRV is \(hrvInt)ms - is that low?",
                        category: .heart
                    ))
                }
            }
        }

        // Always include some general exploration questions
        questions.append(SuggestedQuestion(
            icon: "sparkles",
            text: "Give me today's health insights",
            category: .general
        ))
        questions.append(SuggestedQuestion(
            icon: "chart.line.uptrend.xyaxis",
            text: "How was my week overall?",
            category: .general
        ))
        questions.append(SuggestedQuestion(
            icon: "heart.text.square.fill",
            text: "Analyze my heart health",
            category: .heart
        ))
        questions.append(SuggestedQuestion(
            icon: "flame.fill",
            text: "Am I ready for a workout?",
            category: .recovery
        ))

        // Remove duplicates and return max 6
        var seen = Set<String>()
        let unique = questions.filter { seen.insert($0.text).inserted }
        return Array(unique.prefix(6))
    }
}

// MARK: - Health Context

struct HealthContext {
    // Today's data
    let lifeIndexScore: Int
    let scoreLabel: String
    let steps: Double?
    let activeCalories: Double?
    let heartRate: Double?
    let restingHeartRate: Double?
    let hrv: Double?
    let sleepMinutes: Double?
    let recoveryScore: Int?
    let workoutMinutes: Double?
    let insights: [String]

    // Mood data
    let todayMood: Int?  // 1-5 scale
    let todayMoodNote: String?
    let weeklyMoodAverage: Double?

    // Historical data (for AI context)
    let weeklyScores: [(date: Date, score: Int)]
    let weeklyAverageScore: Int?
    let historicalDays: [DailyHealthSummary]  // Uses existing DailyHealthSummary from HealthDataTypes
}
