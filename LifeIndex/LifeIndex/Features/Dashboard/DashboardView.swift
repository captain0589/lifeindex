import SwiftUI
// RecoverySection is defined in Features/Dashboard/RecoverySection.swift
import Charts

struct DashboardView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @ObservedObject var viewModel: DashboardViewModel
    @State private var showFoodLog = false
    @State private var showSettings = false
    @State private var showChat = false
    @State private var nutritionManager: NutritionManager?
    @State private var foodLogViewModel: FoodLogViewModel?
    @State private var isManualRefreshing = false
    @State private var showRefreshSuccess = false

    private var isLateNight: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 0 && hour < 6
    }

    private func buildHealthContext() -> HealthContext {
        // Fetch mood data
        let todayMoodLog = CoreDataStack.shared.fetchTodayMoodLog()
        let weeklyMoodLogs = CoreDataStack.shared.fetchMoodLogsForWeek()
        let weeklyMoodAverage: Double? = weeklyMoodLogs.isEmpty ? nil :
            Double(weeklyMoodLogs.reduce(0) { $0 + Int($1.mood) }) / Double(weeklyMoodLogs.count)

        return HealthContext(
            lifeIndexScore: viewModel.lifeIndexScore,
            scoreLabel: viewModel.scoreLabel,
            steps: viewModel.stepsValue > 0 ? viewModel.stepsValue : nil,
            activeCalories: viewModel.caloriesValue > 0 ? viewModel.caloriesValue : nil,
            heartRate: viewModel.heartRate,
            restingHeartRate: viewModel.restingHeartRate,
            hrv: viewModel.hrv,
            sleepMinutes: viewModel.sleepMinutes,
            recoveryScore: viewModel.recoveryScore,
            workoutMinutes: viewModel.workoutMinutesValue > 0 ? viewModel.workoutMinutesValue : nil,
            insights: viewModel.insights.map { $0.text },
            todayMood: todayMoodLog != nil ? Int(todayMoodLog!.mood) : nil,
            todayMoodNote: todayMoodLog?.note,
            weeklyMoodAverage: weeklyMoodAverage,
            weeklyScores: viewModel.weeklyScores,
            weeklyAverageScore: viewModel.weeklyAverageScore,
            historicalDays: viewModel.weeklyData
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // MARK: - Header
                    HStack {
                        Text(viewModel.greeting)
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                        Spacer()

                        HStack(spacing: Theme.Spacing.md) {
                            // Refresh button
                            Button {
                                Task {
                                    showRefreshSuccess = false
                                    isManualRefreshing = true
                                    await viewModel.loadData(forceRefresh: true)
                                    isManualRefreshing = false
                                    showRefreshSuccess = true

                                    // Hide success indicator after 3 seconds
                                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        showRefreshSuccess = false
                                    }
                                }
                            } label: {
                                if isManualRefreshing || viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.9)))
                                        .scaleEffect(0.8)
                                        .frame(width: 24, height: 24)
                                } else if showRefreshSuccess {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(.green)
                                        .transition(.scale.combined(with: .opacity))
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                            }
                            .disabled(isManualRefreshing || viewModel.isLoading)

                            // Settings button
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    if viewModel.hasData {
                        // Late night hint - show as separate card
                        if isLateNight && viewModel.lifeIndexScore < 30 {
                            LateNightHintCard()
                        }

                        // MARK: - Combined LifeIndex Section (Score + History + Insights)
                        LifeIndexSection(
                            score: viewModel.lifeIndexScore,
                            label: viewModel.scoreLabel,
                            breakdown: viewModel.scoreBreakdown,
                            yesterdayScore: viewModel.yesterdayScore,
                            weeklyScores: viewModel.weeklyScores,
                            weeklyAverage: viewModel.weeklyAverageScore,
                            weeklyData: viewModel.weeklyData,
                            insights: viewModel.insights,
                            aiShortSummary: viewModel.aiShortSummary,
                            aiDetailedSummary: viewModel.aiDetailedSummary,
                            isGeneratingDetailed: viewModel.isGeneratingDetailed,
                            supportsAI: viewModel.supportsAI,
                            insightHistory: viewModel.insightHistory,
                            onRequestDetailed: {
                                Task { await viewModel.generateDetailedSummary() }
                            }
                        )

                        // MARK: - Daily Scores Section
                        if !viewModel.weeklyScores.isEmpty {
                            DailyScoresSection(
                                weeklyScores: viewModel.weeklyScores,
                                weeklyData: viewModel.weeklyData
                            )
                        }

                        // MARK: - Heart Health
                        if viewModel.heartRate != nil || viewModel.restingHeartRate != nil ||
                           viewModel.hrv != nil || viewModel.bloodOxygen != nil {
                            HeartHealthCard(
                                heartRate: viewModel.heartRate,
                                restingHR: viewModel.restingHeartRate,
                                hrv: viewModel.hrv,
                                bloodOxygen: viewModel.bloodOxygen,
                                weeklyData: viewModel.weeklyData
                            )
                        }

                        // MARK: - Recovery (Expanded)
                        if let recovery = viewModel.recoveryScore {
                            RecoverySection(
                                todayScore: recovery,
                                todayLabel: viewModel.recoveryLabel,
                                weeklyData: viewModel.weeklyData
                            )
                        }

                        // MARK: - Mindfulness
                        if let mindful = viewModel.mindfulMinutes {
                            MindfulCard(minutes: mindful, weeklyData: viewModel.weeklyData)
                        }
                    } else if !viewModel.isLoading {
                        EmptyDashboardView()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .background(
                ZStack(alignment: .top) {
                    Theme.background
                    Theme.headerGradient
                        .frame(height: 380)
                        .mask(
                            LinearGradient(
                                colors: [.black, .black, .black.opacity(0.6), .black.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            // Removed toolbar gear icon, now in header row
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
            .refreshable {
                await viewModel.loadData(forceRefresh: true)
            }
            .sheet(isPresented: $showFoodLog, onDismiss: {
                viewModel.loadNutritionData()
            }) {
                if let foodLogVM = foodLogViewModel {
                    FoodLogSheet(viewModel: foodLogVM, isPresented: $showFoodLog)
                }
            }
            .sheet(isPresented: $showChat) {
                HealthAIChatView(healthContextBuilder: { [self] in
                    buildHealthContext()
                })
            }
            .overlay(alignment: .bottomTrailing) {
                FloatingChatButton(showChat: $showChat)
                    .padding(.trailing, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.lg)
            }
        }
        .task {
            viewModel.configure(with: healthKitManager)

            // Initialize nutrition objects
            if nutritionManager == nil {
                let nm = NutritionManager(healthStore: healthKitManager.healthStore)
                nutritionManager = nm
                foodLogViewModel = FoodLogViewModel(nutritionManager: nm)
            }

            await viewModel.loadData()
        }
    }
}

// MARK: - Yesterday Report Sheet

struct YesterdayReportSheet: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    private var yesterdayDate: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    }

    private var yesterdayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: yesterdayDate)
    }

    private var yesterdayData: DailyHealthSummary? {
        viewModel.weeklyData.first { Calendar.current.isDateInYesterday($0.date) }
    }

    private var yesterdayBreakdown: [(type: HealthMetricType, score: Double, value: Double)] {
        guard let data = yesterdayData else { return [] }
        var breakdown: [(type: HealthMetricType, score: Double, value: Double)] = []

        for (type, value) in data.metrics {
            guard let target = LifeIndexScoreEngine.targets[type] else { continue }
            let score = LifeIndexScoreEngine.scoreMetric(value: value, target: target, type: type)
            breakdown.append((type: type, score: score, value: value))
        }

        return breakdown.sorted { $0.score > $1.score }
    }

    /// Get yesterday's insights from stored report or generate fresh
    private var yesterdayInsights: [HealthInsight] {
        // First try to get from stored report
        if let report = viewModel.fetchYesterdayReport(),
           !report.insights.isEmpty {
            return viewModel.storedInsightsToHealthInsights(report.insights)
        }
        // Otherwise generate fresh from weekly data
        return viewModel.generateYesterdayInsights()
    }

    /// Get yesterday's AI summary from stored report
    private var yesterdayAISummary: (short: String?, detailed: String?) {
        if let report = viewModel.fetchYesterdayReport() {
            return (report.aiShortSummary, report.aiDetailedSummary)
        }
        return (nil, nil)
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // Date header
                    Text(yesterdayDateString)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.top, Theme.Spacing.md)

                    // Score ring
                    if let score = viewModel.yesterdayScore {
                        ZStack {
                            Circle()
                                .stroke(scoreColor(score).opacity(0.2), lineWidth: 12)
                                .frame(width: 140, height: 140)

                            Circle()
                                .trim(from: 0, to: CGFloat(score) / 100.0)
                                .stroke(scoreColor(score), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                .frame(width: 140, height: 140)
                                .rotationEffect(.degrees(-90))

                            VStack(spacing: 4) {
                                Text("\(score)")
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundStyle(scoreColor(score))

                                Text(LifeIndexScoreEngine.label(for: score))
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                        }
                    } else {
                        Text("No data available")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                            .padding(.vertical, Theme.Spacing.xl)
                    }

                    // Insights section
                    if !yesterdayInsights.isEmpty || yesterdayAISummary.short != nil {
                        YesterdayInsightsCard(
                            insights: yesterdayInsights,
                            aiShortSummary: yesterdayAISummary.short,
                            aiDetailedSummary: yesterdayAISummary.detailed
                        )
                        .padding(.horizontal)
                    }

                    // Metrics breakdown
                    if !yesterdayBreakdown.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text("Metrics")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .padding(.horizontal)

                            ForEach(yesterdayBreakdown, id: \.type) { item in
                                YesterdayMetricRow(
                                    type: item.type,
                                    value: item.value,
                                    score: item.score
                                )
                            }
                        }
                    }

                    // Summary stats
                    if let data = yesterdayData {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text("Summary")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .padding(.horizontal)

                            HStack(spacing: Theme.Spacing.md) {
                                if let steps = data.metrics[.steps] {
                                    SummaryStatBox(
                                        icon: "figure.walk",
                                        value: "\(Int(steps).formatted())",
                                        label: "Steps",
                                        color: Theme.steps
                                    )
                                }

                                if let sleep = data.metrics[.sleepDuration] {
                                    SummaryStatBox(
                                        icon: "bed.double.fill",
                                        value: String(format: "%.1fh", sleep / 60),
                                        label: "Sleep",
                                        color: Theme.sleep
                                    )
                                }

                                if let calories = data.metrics[.activeCalories] {
                                    SummaryStatBox(
                                        icon: "flame.fill",
                                        value: "\(Int(calories))",
                                        label: "Calories",
                                        color: Theme.calories
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Theme.background)
            .navigationTitle("Yesterday's Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
            }
        }
    }
}

// MARK: - Yesterday Insights Card

private struct YesterdayInsightsCard: View {
    let insights: [HealthInsight]
    var aiShortSummary: String? = nil
    var aiDetailedSummary: String? = nil

    @State private var showingDetailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: Theme.IconSize.sm, weight: .semibold))
                    .foregroundStyle(.purple)
                Text("Insights")
                    .font(.system(.headline, design: .rounded, weight: .bold))
            }
            .padding(.bottom, Theme.Spacing.sm)

            // AI summary at top
            if let summary = aiShortSummary, !summary.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack(alignment: .top, spacing: Theme.Spacing.md) {
                        Image(systemName: "sparkles")
                            .font(.system(size: Theme.IconSize.sm + 1, weight: .semibold))
                            .foregroundStyle(.purple)
                            .frame(width: Theme.IconFrame.sm, alignment: .center)

                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            if showingDetailed, let detailed = aiDetailedSummary {
                                Text(detailed)
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(Theme.primaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(3)

                                Button {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        showingDetailed = false
                                    }
                                } label: {
                                    Text("Show Less")
                                        .font(.system(.caption, design: .rounded, weight: .semibold))
                                        .foregroundStyle(.purple)
                                }
                            } else {
                                Text(summary)
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(Theme.primaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(2)

                                if aiDetailedSummary != nil {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            showingDetailed = true
                                        }
                                    } label: {
                                        Text("View More")
                                            .font(.system(.caption, design: .rounded, weight: .semibold))
                                            .foregroundStyle(.purple)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.sm)

                if !insights.isEmpty {
                    Divider()
                }
            }

            // Standard insights
            ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    Image(systemName: insight.icon)
                        .font(.system(size: Theme.IconSize.sm + 1, weight: .semibold))
                        .foregroundStyle(insight.color)
                        .frame(width: Theme.IconFrame.sm, alignment: .center)

                    Text(insight.text)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, Theme.Spacing.sm)

                if index < insights.count - 1 {
                    Divider()
                }
            }
        }
        .cardStyle()
        .animation(.easeInOut(duration: 0.25), value: showingDetailed)
    }
}

// MARK: - Yesterday Metric Row

private struct YesterdayMetricRow: View {
    let type: HealthMetricType
    let value: Double
    let score: Double

    private var scoreColor: Color {
        switch score {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .yellow
        case 0.4..<0.6: return .orange
        default: return .red
        }
    }

    private var metricColor: Color {
        switch type {
        case .steps: return Theme.steps
        case .heartRate: return Theme.heartRate
        case .heartRateVariability: return Theme.hrv
        case .restingHeartRate: return Theme.heartRate
        case .bloodOxygen: return Theme.bloodOxygen
        case .activeCalories: return Theme.calories
        case .sleepDuration: return Theme.sleep
        case .mindfulMinutes: return Theme.mindfulness
        case .workoutMinutes: return Theme.activity
        }
    }

    private var statusText: String {
        switch score {
        case 0.8...1.0: return "Excellent"
        case 0.6..<0.8: return "Good"
        case 0.4..<0.6: return "Fair"
        default: return "Needs work"
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(metricColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: type.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(metricColor)
            }

            // Name and value
            VStack(alignment: .leading, spacing: 2) {
                Text(type.displayName)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))

                Text(HealthDataPoint(type: type, value: value, date: .now).formattedValue)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer()

            // Score
            VStack(alignment: .trailing, spacing: 2) {
                Text(statusText)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(scoreColor)

                // Progress indicator
                GeometryReader { geo in
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(scoreColor)
                                .frame(width: geo.size.width * score)
                        }
                }
                .frame(width: 50, height: 4)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, Theme.Spacing.sm)
    }
}

// MARK: - Summary Stat Box

private struct SummaryStatBox: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)

            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))

            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Late Night Hint Card

private struct LateNightHintCard: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 24))
                .foregroundStyle(Theme.sleep)

            VStack(alignment: .leading, spacing: 4) {
                Text("It's Late!")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)

                Text("Your daily metrics are still building up. Check back tomorrow morning for a complete picture.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .cardStyle()
    }
}

// MARK: - Score History Sparkline

struct ScoreHistoryCard: View {
    let weeklyScores: [(date: Date, score: Int)]
    let yesterdayScore: Int?
    let weeklyAverage: Int?
    var weeklyData: [DailyHealthSummary] = []

    @State private var selectedDay: String?
    @State private var showDetail = false

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    private var selectedEntry: (date: Date, score: Int)? {
        guard let day = selectedDay else { return nil }
        return weeklyScores.first { $0.date.shortDayName == day }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                SectionHeader(title: "LifeIndex History", icon: "chart.line.uptrend.xyaxis", color: Theme.accentColor)

                Spacer()

                // Show selected day's score
                if let entry = selectedEntry {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(entry.date.shortDayName)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                        Text("\(entry.score)")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(scoreColor(entry.score))
                        Text(LifeIndexScoreEngine.label(for: entry.score))
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .transition(.opacity)
                }
            }

            // Sparkline chart
            Chart(weeklyScores, id: \.date) { entry in
                LineMark(
                    x: .value("Day", entry.date.shortDayName),
                    y: .value("Score", entry.score)
                )
                .foregroundStyle(Theme.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Day", entry.date.shortDayName),
                    y: .value("Score", entry.score)
                )
                .foregroundStyle(selectedDay == entry.date.shortDayName ? scoreColor(entry.score) : scoreColor(entry.score).opacity(0.7))
                .symbolSize(selectedDay == entry.date.shortDayName ? 120 : 60)

                AreaMark(
                    x: .value("Day", entry.date.shortDayName),
                    y: .value("Score", entry.score)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.accentColor.opacity(0.2), Theme.accentColor.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                if selectedDay == entry.date.shortDayName {
                    RuleMark(x: .value("Day", entry.date.shortDayName))
                        .foregroundStyle(Theme.secondaryText.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                }
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text("\(v)")
                                .font(.system(.caption2, design: .rounded))
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .font(.system(.caption2, design: .rounded))
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            guard let plotFrame = proxy.plotFrame else { return }
                            let origin = geo[plotFrame].origin
                            let x = location.x - origin.x
                            if let tappedDay: String = proxy.value(atX: x) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    if selectedDay == tappedDay {
                                        selectedDay = nil
                                    } else {
                                        selectedDay = tappedDay
                                    }
                                }
                            }
                        }
                }
            }
            .frame(height: 160)

            // Yesterday + average summary
            HStack(spacing: Theme.Spacing.lg) {
                if let yesterday = yesterdayScore {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text("Yesterday")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                        Text("\(yesterday)")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(scoreColor(yesterday))
                    }
                }

                if let avg = weeklyAverage {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text("7-day avg")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                        Text("\(avg)")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(scoreColor(avg))
                    }
                }

                Spacer()
            }

            Button {
                showDetail = true
            } label: {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 11))
                    Text("View Score Details")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(Theme.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.sm))
            }
            .buttonStyle(.plain)
        }
        .cardStyle()
        .sheet(isPresented: $showDetail) {
            ScoreHistoryDetailSheet(
                weeklyScores: weeklyScores,
                yesterdayScore: yesterdayScore,
                weeklyAverage: weeklyAverage,
                weeklyData: weeklyData
            )
        }
    }
}

// MARK: - Score History Detail Sheet

struct ScoreHistoryDetailSheet: View {
    let weeklyScores: [(date: Date, score: Int)]
    let yesterdayScore: Int?
    let weeklyAverage: Int?
    var weeklyData: [DailyHealthSummary] = []

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDay: String?
    @State private var selectedDayForDetail: Date?

    private var todayScore: Int? {
        weeklyScores.first(where: { $0.date.isToday })?.score
    }

    private var weeklyMin: Int? {
        weeklyScores.map(\.score).min()
    }

    private var weeklyMax: Int? {
        weeklyScores.map(\.score).max()
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    // Today hero
                    VStack(spacing: Theme.Spacing.sm) {
                        if let today = todayScore {
                            Text("\(today)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(scoreColor(today))
                            Text(LifeIndexScoreEngine.label(for: today))
                                .font(.system(.title3, design: .rounded, weight: .medium))
                                .foregroundStyle(Theme.secondaryText)
                        } else {
                            Text("No data")
                                .font(.system(.title2, design: .rounded, weight: .medium))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        Text("Today's Score")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.lg)

                    // Comparison tiles
                    HStack(spacing: Theme.Spacing.xl) {
                        ComparisonTile(
                            label: "Today",
                            value: todayScore.map { "\($0)" } ?? "—",
                            color: todayScore.map { scoreColor($0) } ?? .gray
                        )
                        ComparisonTile(
                            label: "Yesterday",
                            value: yesterdayScore.map { "\($0)" } ?? "—",
                            color: yesterdayScore.map { scoreColor($0).opacity(0.7) } ?? .gray
                        )
                        ComparisonTile(
                            label: "7-day avg",
                            value: weeklyAverage.map { "\($0)" } ?? "—",
                            color: weeklyAverage.map { scoreColor($0) } ?? .gray
                        )
                    }
                    .padding(.horizontal, Theme.Spacing.sm)

                    // Change indicator
                    if let today = todayScore, let yesterday = yesterdayScore, yesterday > 0 {
                        let change = today - yesterday
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: Theme.IconSize.sm, weight: .semibold))
                                .foregroundStyle(change >= 0 ? .green : .orange)
                            Text(change >= 0 ? "+\(change) from yesterday" : "\(change) from yesterday")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Weekly chart
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        HStack {
                            Label("This Week", systemImage: "chart.bar.fill")
                                .font(.system(.headline, design: .rounded, weight: .semibold))

                            Spacer()

                            if let day = selectedDay,
                               let entry = weeklyScores.first(where: { $0.date.shortDayName == day }) {
                                HStack(spacing: Theme.Spacing.xs) {
                                    Text(day)
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(Theme.secondaryText)
                                    Text("\(entry.score)")
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                        .foregroundStyle(scoreColor(entry.score))
                                }
                            }
                        }

                        Chart(weeklyScores, id: \.date) { entry in
                            BarMark(
                                x: .value("Day", entry.date.shortDayName),
                                y: .value("Score", entry.score)
                            )
                            .foregroundStyle(selectedDay == entry.date.shortDayName ? scoreColor(entry.score) : scoreColor(entry.score).opacity(0.7))
                            .cornerRadius(4)

                            if selectedDay == entry.date.shortDayName {
                                RuleMark(x: .value("Day", entry.date.shortDayName))
                                    .foregroundStyle(Theme.secondaryText.opacity(0.3))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                            }
                        }
                        .chartOverlay { proxy in
                            GeometryReader { geo in
                                Rectangle()
                                    .fill(Color.clear)
                                    .contentShape(Rectangle())
                                    .onTapGesture { location in
                                        guard let plotFrame = proxy.plotFrame else { return }
                                        let origin = geo[plotFrame].origin
                                        let x = location.x - origin.x
                                        if let tappedDay: String = proxy.value(atX: x) {
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                if selectedDay == tappedDay {
                                                    selectedDay = nil
                                                } else {
                                                    selectedDay = tappedDay
                                                }
                                            }
                                        }
                                    }
                            }
                        }
                        .chartYScale(domain: 0...100)
                        .frame(height: 150)
                        .chartYAxis {
                            AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                                AxisValueLabel {
                                    if let v = value.as(Int.self) {
                                        Text("\(v)")
                                            .font(.system(.caption2, design: .rounded))
                                    }
                                }
                            }
                        }
                    }

                    // Weekly stats
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Label("Weekly Stats", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.system(.headline, design: .rounded, weight: .semibold))

                        HStack(spacing: Theme.Spacing.xl) {
                            if let avg = weeklyAverage {
                                StatTile(label: "Average", value: "\(avg)", color: scoreColor(avg))
                            }
                            if let min = weeklyMin {
                                StatTile(label: "Low", value: "\(min)", color: .orange)
                            }
                            if let max = weeklyMax {
                                StatTile(label: "High", value: "\(max)", color: .green)
                            }
                        }
                    }

                    // Daily breakdown
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Label("Daily Scores", systemImage: "list.bullet")
                            .font(.system(.headline, design: .rounded, weight: .semibold))

                        ForEach(weeklyScores.reversed(), id: \.date) { entry in
                            Button {
                                selectedDayForDetail = entry.date
                            } label: {
                                HStack {
                                    Text(entry.date.relativeDescription)
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(Theme.primaryText)
                                        .frame(width: 90, alignment: .leading)

                                    Spacer()

                                    Text("\(entry.score)/100")
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                        .foregroundStyle(scoreColor(entry.score))

                                    Text(LifeIndexScoreEngine.label(for: entry.score))
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(Theme.secondaryText)

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(Theme.tertiaryText)
                                }
                            }
                            .buttonStyle(.plain)

                            if entry.date != weeklyScores.first?.date {
                                Divider()
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Score History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
            }
            .sheet(item: $selectedDayForDetail) { date in
                DayDetailSheet(date: date, weeklyData: weeklyData)
            }
        }
    }

    private func dataFor(date: Date) -> DailyHealthSummary? {
        weeklyData.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
}

// MARK: - Day Detail Sheet (Reusable for any date)

struct DayDetailSheet: View {
    let date: Date
    let weeklyData: [DailyHealthSummary]

    @Environment(\.dismiss) private var dismiss

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    private var dayData: DailyHealthSummary? {
        weeklyData.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var dayScore: Int {
        guard let data = dayData else { return 0 }
        // For today: use time-aware score (consistent with main display)
        // For past days: use final score (full day evaluation)
        if isToday {
            return LifeIndexScoreEngine.calculateScore(from: data, timeAware: true, at: Date())
        } else {
            return LifeIndexScoreEngine.calculateFinalScore(from: data)
        }
    }

    private var dayBreakdown: [(type: HealthMetricType, score: Double, value: Double)] {
        guard let data = dayData else { return [] }
        var breakdown: [(type: HealthMetricType, score: Double, value: Double)] = []

        // For today: scale cumulative targets by time of day
        // For past days: use full targets
        let factor = isToday ? LifeIndexScoreEngine.dayProgressFactor() : 1.0

        for (type, value) in data.metrics {
            guard let target = LifeIndexScoreEngine.targets[type] else { continue }
            let effectiveTarget = LifeIndexScoreEngine.scaledTarget(for: type, target: target, factor: factor)
            let score = LifeIndexScoreEngine.scoreMetric(value: value, target: effectiveTarget, type: type)
            breakdown.append((type: type, score: score, value: value))
        }

        return breakdown.sorted { $0.score > $1.score }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // Date header
                    Text(dateString)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.top, Theme.Spacing.md)

                    // Score ring
                    if dayData != nil {
                        ZStack {
                            Circle()
                                .stroke(scoreColor(dayScore).opacity(0.2), lineWidth: 12)
                                .frame(width: 140, height: 140)

                            Circle()
                                .trim(from: 0, to: CGFloat(dayScore) / 100.0)
                                .stroke(scoreColor(dayScore), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                .frame(width: 140, height: 140)
                                .rotationEffect(.degrees(-90))

                            VStack(spacing: 4) {
                                Text("\(dayScore)")
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundStyle(scoreColor(dayScore))

                                Text(LifeIndexScoreEngine.label(for: dayScore))
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                        }
                    } else {
                        Text("No data available")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                            .padding(.vertical, Theme.Spacing.xl)
                    }

                    // Metrics breakdown
                    if !dayBreakdown.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text("Metrics")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .padding(.horizontal)

                            ForEach(dayBreakdown, id: \.type) { item in
                                DayMetricRow(
                                    type: item.type,
                                    value: item.value,
                                    score: item.score
                                )
                            }
                        }
                    }

                    // Sleep stages if available
                    if let data = dayData, let stages = data.sleepStages, stages.hasStageData {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text("sleep.stages".localized)
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .padding(.horizontal)

                            HStack(spacing: Theme.Spacing.md) {
                                DaySleepStageBox(
                                    label: "sleep.awake".localized,
                                    minutes: stages.awakeMinutes,
                                    percent: stages.awakePercent,
                                    color: .orange
                                )
                                DaySleepStageBox(
                                    label: "sleep.rem".localized,
                                    minutes: stages.remMinutes,
                                    percent: stages.remPercent,
                                    color: .cyan
                                )
                                DaySleepStageBox(
                                    label: "sleep.core".localized,
                                    minutes: stages.coreMinutes,
                                    percent: stages.corePercent,
                                    color: .blue
                                )
                                DaySleepStageBox(
                                    label: "sleep.deep".localized,
                                    minutes: stages.deepMinutes,
                                    percent: stages.deepPercent,
                                    color: .indigo
                                )
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Theme.background)
            .navigationTitle("Day Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done".localized) { dismiss() }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
            }
        }
    }
}

struct DayMetricRow: View {
    let type: HealthMetricType
    let value: Double
    let score: Double

    private var formattedValue: String {
        HealthDataPoint(type: type, value: value, date: .now).formattedValue
    }

    private var percentText: String {
        "\(Int(score * 100))%"
    }

    private var progressColor: Color {
        switch score {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .yellow
        case 0.4..<0.6: return .orange
        default: return .red
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: type.icon)
                .font(.system(size: Theme.IconSize.md, weight: .medium))
                .foregroundStyle(progressColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(type.displayName)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))

                    Spacer()

                    Text(formattedValue)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                    Text(type.unit)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(progressColor.opacity(0.15))
                        Rectangle()
                            .fill(progressColor)
                            .frame(width: geo.size.width * min(score, 1.0))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                .frame(height: 4)

                HStack {
                    Text(percentText)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, Theme.Spacing.sm)
    }
}

struct DaySleepStageBox: View {
    let label: String
    let minutes: Double
    let percent: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(Theme.secondaryText)

            Text("\(percent)%")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(color)

            Text(formatDuration(minutes))
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Theme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatDuration(_ minutes: Double) -> String {
        let h = Int(minutes) / 60
        let m = Int(minutes) % 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m)m"
    }
}

// MARK: - Activity Card

struct ActivityCard: View {
    let steps: Double
    let stepsGoal: Double
    let calories: Double
    let caloriesGoal: Double
    let exercise: Double
    let exerciseGoal: Double
    let activitySummary: HKActivitySummaryWrapper?
    var weeklyData: [DailyHealthSummary] = []

    @State private var showDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            // Tappable header
            Button {
                showDetail = true
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: Theme.IconSize.sm, weight: .semibold))
                        .foregroundStyle(Theme.activity)
                    Text("dashboard.activity".localized)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.primaryText)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(.plain)

            // Tappable rings and legend
            Button {
                showDetail = true
            } label: {
                HStack(spacing: Theme.Spacing.xl) {
                    // Rings
                    if let summary = activitySummary {
                        AppleActivityRingsView(summary: summary)
                            .frame(width: 100, height: 100)
                    } else {
                        ZStack {
                            ActivityRing(progress: min(1.0, steps / stepsGoal), color: Theme.steps, size: 90, lineWidth: 10)
                            ActivityRing(progress: min(1.0, calories / caloriesGoal), color: Theme.calories, size: 66, lineWidth: 10)
                            ActivityRing(progress: min(1.0, exercise / exerciseGoal), color: Theme.activity, size: 42, lineWidth: 10)
                        }
                        .frame(width: 100, height: 100)
                    }

                    // Legend
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        ActivityLegendRow(
                            color: Theme.steps,
                            icon: "figure.walk",
                            label: "activity.steps".localized,
                            value: "\(Int(steps))",
                            goal: "\(Int(stepsGoal))",
                            currentValue: steps,
                            goalValue: stepsGoal
                        )
                        ActivityLegendRow(
                            color: Theme.calories,
                            icon: "flame.fill",
                            label: "activity.calories".localized,
                            value: "\(Int(calories))",
                            goal: "\(Int(caloriesGoal)) " + "units.kcal".localized,
                            currentValue: calories,
                            goalValue: caloriesGoal
                        )
                        ActivityLegendRow(
                            color: Theme.activity,
                            icon: "figure.run",
                            label: "activity.exercise".localized,
                            value: "\(Int(exercise))",
                            goal: "\(Int(exerciseGoal)) " + "units.minutes".localized,
                            currentValue: exercise,
                            goalValue: exerciseGoal
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            if !weeklyData.isEmpty {
                Button {
                    showDetail = true
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 11))
                        Text("View Activity Details")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(Theme.activity)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.activity.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.sm))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .sheet(isPresented: $showDetail) {
            ActivityDetailSheet(weeklyData: weeklyData)
        }
    }
}

struct ActivityRing: View {
    let progress: Double
    let color: Color
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

struct ActivityLegendRow: View {
    let color: Color
    let icon: String
    let label: String
    let value: String
    let goal: String
    var currentValue: Double = 0
    var goalValue: Double = 1

    @State private var showDetail = false

    private var percentage: Int {
        guard goalValue > 0 else { return 0 }
        return min(999, Int((currentValue / goalValue) * 100))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: Theme.IconSize.sm - 2, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: Theme.IconFrame.sm)

                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                    HStack(spacing: Theme.Spacing.xxs) {
                        Text(value)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                        Text("/ \(goal)")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }

            if showDetail {
                HStack(spacing: Theme.Spacing.sm) {
                    Spacer().frame(width: Theme.IconFrame.sm)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(color.opacity(0.15)).frame(height: 4)
                            Capsule().fill(color)
                                .frame(width: geo.size.width * min(1.0, currentValue / max(1, goalValue)), height: 4)
                        }
                    }
                    .frame(height: 4)

                    Text("\(percentage)%")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(percentage >= 100 ? .green : color)
                        .frame(width: 36, alignment: .trailing)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showDetail.toggle()
            }
        }
    }
}

// MARK: - Apple Activity Rings (HKActivityRingView wrapper)

import HealthKit
import HealthKitUI

struct HKActivitySummaryWrapper {
    let summary: HKActivitySummary
}

struct AppleActivityRingsView: UIViewRepresentable {
    let summary: HKActivitySummaryWrapper

    func makeUIView(context: Context) -> HKActivityRingView {
        let ringView = HKActivityRingView()
        ringView.setActivitySummary(summary.summary, animated: true)
        return ringView
    }

    func updateUIView(_ uiView: HKActivityRingView, context: Context) {
        uiView.setActivitySummary(summary.summary, animated: true)
    }
}

// MARK: - Heart Health Card

struct HeartHealthCard: View {
    let heartRate: Double?
    let restingHR: Double?
    let hrv: Double?
    let bloodOxygen: Double?
    var weeklyData: [DailyHealthSummary] = []

    @State private var showDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "dashboard.heart".localized, icon: "heart.fill", color: Theme.heartRate)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
                if let hr = heartRate {
                    HeartMetricTile(icon: "heart.fill", label: "heart.title".localized, value: "\(Int(hr))", unit: "units.bpm".localized, color: Theme.heartRate)
                }
                if let rhr = restingHR {
                    HeartMetricTile(icon: "heart.circle", label: "heart.restingHR".localized, value: "\(Int(rhr))", unit: "units.bpm".localized, color: .pink)
                }
                if let h = hrv {
                    HeartMetricTile(icon: "waveform.path.ecg", label: "heart.hrv".localized, value: "\(Int(h))", unit: "units.ms".localized, color: Theme.hrv)
                }
                if let o2 = bloodOxygen {
                    HeartMetricTile(icon: "lungs.fill", label: "heart.bloodOxygen".localized, value: "\(Int(o2 * 100))", unit: "units.percent".localized, color: Theme.bloodOxygen)
                }
            }

            if !weeklyData.isEmpty {
                Button {
                    showDetail = true
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11))
                        Text("heart.viewDetails".localized)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(Theme.heartRate)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.heartRate.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.sm))
                }
                .buttonStyle(.plain)
            }
        }
        .cardStyle()
        .sheet(isPresented: $showDetail) {
            HeartDetailSheet(
                heartRate: heartRate,
                restingHR: restingHR,
                hrv: hrv,
                bloodOxygen: bloodOxygen,
                weeklyData: weeklyData
            )
        }
    }
}

struct HeartMetricTile: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: Theme.IconSize.sm, weight: .semibold))
                .foregroundStyle(color)

            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.secondaryText)

            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xxs) {
                Text(value)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Text(unit)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.md))
    }
}

// MARK: - Sleep Card

struct SleepCard: View {
    let minutes: Double
    var weeklyData: [DailyHealthSummary] = []
    var sleepStages: SleepStages?

    @State private var showDetail = false
    @State private var selectedDay: String?

    private var hours: Int { Int(minutes) / 60 }
    private var mins: Int { Int(minutes) % 60 }

    private func summaryFor(day: String?) -> DailyHealthSummary? {
        guard let day else { return nil }
        return weeklyData.first { $0.date.shortDayName == day }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Header - Tappable
            Button {
                showDetail = true
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: Theme.IconSize.sm, weight: .semibold))
                        .foregroundStyle(Theme.sleep)
                    Text("dashboard.sleep".localized)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.primaryText)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(.plain)

            // Weekly sleep chart
            if !weeklyData.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    // Selected day info
                    if let day = selectedDay, let summary = summaryFor(day: day),
                       let sleep = summary.metrics[.sleepDuration] {
                        HStack {
                            Text(day)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                            Text("\(Int(sleep) / 60)h \(Int(sleep) % 60)m")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(Theme.sleep)
                        }
                        .transition(.opacity)
                    }

                    Chart(weeklyData) { summary in
                        let dayName = summary.date.shortDayName
                        if let sleep = summary.metrics[.sleepDuration] {
                            BarMark(
                                x: .value("Day", dayName),
                                y: .value("Hours", sleep / 60.0)
                            )
                            .foregroundStyle(selectedDay == dayName ? Theme.sleep : Theme.sleep.opacity(0.7))
                            .cornerRadius(4)
                        } else {
                            BarMark(
                                x: .value("Day", dayName),
                                y: .value("Hours", 0.3)
                            )
                            .foregroundStyle(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                        }

                        if selectedDay == dayName {
                            RuleMark(x: .value("Day", dayName))
                                .foregroundStyle(Theme.secondaryText.opacity(0.3))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        }
                    }
                    .frame(height: 100)
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture { location in
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let origin = geo[plotFrame].origin
                                    let x = location.x - origin.x
                                    if let tappedDay: String = proxy.value(atX: x) {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            selectedDay = selectedDay == tappedDay ? nil : tappedDay
                                        }
                                    }
                                }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text("\(Int(v))h")
                                        .font(.system(.caption2, design: .rounded))
                                }
                            }
                        }
                    }
                }
            }

            // 2x2 Stats Grid - Sleep Stages
            if let stages = sleepStages, stages.hasStageData {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                    // Awake
                    SleepStageBox(
                        title: "sleep.awake".localized,
                        duration: stages.formattedDuration(stages.awakeMinutes),
                        percent: stages.awakePercent,
                        color: .orange,
                        infoDescription: "sleep.awake.desc".localized
                    )

                    // REM
                    SleepStageBox(
                        title: "sleep.rem".localized,
                        duration: stages.formattedDuration(stages.remMinutes),
                        percent: stages.remPercent,
                        color: .cyan,
                        infoDescription: "sleep.rem.desc".localized
                    )

                    // Core (Light)
                    SleepStageBox(
                        title: "sleep.core".localized,
                        duration: stages.formattedDuration(stages.coreMinutes),
                        percent: stages.corePercent,
                        color: .blue,
                        infoDescription: "sleep.core.desc".localized
                    )

                    // Deep
                    SleepStageBox(
                        title: "sleep.deep".localized,
                        duration: stages.formattedDuration(stages.deepMinutes),
                        percent: stages.deepPercent,
                        color: .purple,
                        infoDescription: "sleep.deep.desc".localized
                    )
                }
            } else {
                // Fallback: show total sleep time if no stage data
                HStack {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("sleep.timeAsleep".localized)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                        Text("\(hours)" + "sleep.hoursUnit".localized + " \(mins)" + "sleep.minutesUnit".localized)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(Theme.primaryText)
                    }
                    Spacer()
                    Image(systemName: minutes >= 420 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(minutes >= 420 ? .green : .orange)
                }
                .padding(Theme.Spacing.md)
                .background(Theme.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // View Sleep Details button
            if !weeklyData.isEmpty {
                Button {
                    showDetail = true
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 11))
                        Text("sleep.viewDetails".localized)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(Theme.sleep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.sleep.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.sm))
                }
                .buttonStyle(.plain)
            }
        }
        .cardStyle()
        .sheet(isPresented: $showDetail) {
            SleepDetailSheet(
                sleepStages: sleepStages,
                totalMinutes: minutes,
                weeklyData: weeklyData
            )
        }
    }
}

// MARK: - Sleep Stat Box

private struct SleepStatBox: View {
    let title: String
    let value: String
    let isGood: Bool
    let infoDescription: String

    @State private var showInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(title)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)

                Spacer()

                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondaryText.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: isGood ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(isGood ? .green : .orange)

                Text(value)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.primaryText)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .alert(title, isPresented: $showInfo) {
            Button("common.ok".localized, role: .cancel) {}
        } message: {
            Text(infoDescription)
        }
    }
}

// MARK: - Sleep Stage Box

private struct SleepStageBox: View {
    let title: String
    let duration: String
    let percent: Int
    let color: Color
    let infoDescription: String

    @State private var showInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(color)

                Spacer()

                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondaryText.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            Text(duration)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.primaryText)

            Text("\(percent)% " + "sleep.ofSession".localized)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Theme.secondaryText)

            // Mini progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.2))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(percent) / 100, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .alert(title, isPresented: $showInfo) {
            Button("common.ok".localized, role: .cancel) {}
        } message: {
            Text(infoDescription)
        }
    }
}

// MARK: - Sleep Detail Sheet

private struct SleepDetailSheet: View {
    let sleepStages: SleepStages?
    let totalMinutes: Double
    let weeklyData: [DailyHealthSummary]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDay: String?
    @State private var selectedDayForDetail: Date?

    private var hours: Int { Int(totalMinutes) / 60 }
    private var mins: Int { Int(totalMinutes) % 60 }

    private var weeklyAverage: Double {
        let sleepData = weeklyData.compactMap { $0.metrics[.sleepDuration] }
        guard !sleepData.isEmpty else { return 0 }
        return sleepData.reduce(0, +) / Double(sleepData.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // Sleep Stages Donut Chart
                    if let stages = sleepStages, stages.hasStageData {
                        SleepStagesCard(stages: stages)
                    } else {
                        // Fallback card
                        VStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(Theme.sleep)

                            Text("\(hours)" + "sleep.hoursUnit".localized + " \(mins)" + "sleep.minutesUnit".localized)
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))

                            Text("sleep.totalSleep".localized)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .padding(Theme.Spacing.xl)
                        .frame(maxWidth: .infinity)
                        .background(Theme.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    // Weekly Chart
                    if !weeklyData.isEmpty {
                        WeeklySleepChart(weeklyData: weeklyData, selectedDay: $selectedDay)
                    }

                    // Daily Sleep List
                    if !weeklyData.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            HStack {
                                Label("Daily Sleep", systemImage: "list.bullet")
                                    .font(.system(.headline, design: .rounded, weight: .bold))

                                Spacer()

                                if weeklyAverage > 0 {
                                    HStack(spacing: Theme.Spacing.xs) {
                                        Text("Avg")
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundStyle(Theme.secondaryText)
                                        Text("\(Int(weeklyAverage) / 60)h \(Int(weeklyAverage) % 60)m")
                                            .font(.system(.caption, design: .rounded, weight: .bold))
                                            .foregroundStyle(Theme.sleep)
                                    }
                                }
                            }

                            VStack(spacing: 0) {
                                ForEach(weeklyData.sorted(by: { $0.date > $1.date }), id: \.date) { summary in
                                    Button {
                                        selectedDayForDetail = summary.date
                                    } label: {
                                        SleepDayRow(summary: summary)
                                    }
                                    .buttonStyle(.plain)

                                    if summary.date != weeklyData.sorted(by: { $0.date > $1.date }).last?.date {
                                        Divider()
                                            .padding(.leading, 50)
                                    }
                                }
                            }
                            .background(Theme.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .padding()
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("sleep.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(item: $selectedDayForDetail) { date in
                DashboardSleepDayDetailSheet(date: date, weeklyData: weeklyData)
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Sleep Day Row

private struct SleepDayRow: View {
    let summary: DailyHealthSummary

    private var sleepMinutes: Double {
        summary.metrics[.sleepDuration] ?? 0
    }

    private var sleepHours: Int { Int(sleepMinutes) / 60 }
    private var sleepMins: Int { Int(sleepMinutes) % 60 }

    private var sleepQuality: String {
        switch sleepMinutes {
        case 480...: return "Excellent"
        case 420..<480: return "Good"
        case 360..<420: return "Fair"
        default: return "Poor"
        }
    }

    private var sleepColor: Color {
        switch sleepMinutes {
        case 480...: return .green
        case 420..<480: return .yellow
        case 360..<420: return .orange
        default: return .red
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Moon icon with quality color
            ZStack {
                Circle()
                    .fill(Theme.sleep.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.sleep)
            }

            // Date and quality
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.date.relativeDescription)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.primaryText)

                if sleepMinutes > 0 {
                    Text(sleepQuality)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(sleepColor)
                } else {
                    Text("No data")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            Spacer()

            // Duration
            if sleepMinutes > 0 {
                Text("\(sleepHours)h \(sleepMins)m")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.primaryText)
            } else {
                Text("—")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.secondaryText)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }
}

// MARK: - Dashboard Sleep Day Detail Sheet

private struct DashboardSleepDayDetailSheet: View {
    let date: Date
    let weeklyData: [DailyHealthSummary]

    @Environment(\.dismiss) private var dismiss

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    private var dayData: DailyHealthSummary? {
        weeklyData.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    private var sleepMinutes: Double {
        dayData?.metrics[.sleepDuration] ?? 0
    }

    private var sleepHours: Int { Int(sleepMinutes) / 60 }
    private var sleepMins: Int { Int(sleepMinutes) % 60 }

    private var sleepQuality: String {
        switch sleepMinutes {
        case 480...: return "Excellent"
        case 420..<480: return "Good"
        case 360..<420: return "Fair"
        default: return "Poor"
        }
    }

    private var sleepColor: Color {
        switch sleepMinutes {
        case 480...: return .green
        case 420..<480: return .yellow
        case 360..<420: return .orange
        default: return .red
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // Date header
                    Text(dateString)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.top, Theme.Spacing.md)

                    // Sleep duration ring
                    if sleepMinutes > 0 {
                        ZStack {
                            Circle()
                                .stroke(sleepColor.opacity(0.2), lineWidth: 12)
                                .frame(width: 140, height: 140)

                            Circle()
                                .trim(from: 0, to: min(sleepMinutes / 480, 1.0)) // 8 hours = 100%
                                .stroke(sleepColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                .frame(width: 140, height: 140)
                                .rotationEffect(.degrees(-90))

                            VStack(spacing: 4) {
                                Text("\(sleepHours)h \(sleepMins)m")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.primaryText)

                                Text(sleepQuality)
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundStyle(sleepColor)
                            }
                        }

                        // Target indicator
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "target")
                                .font(.system(size: 12))
                            Text("Target: 7-8 hours")
                                .font(.system(.caption, design: .rounded))
                        }
                        .foregroundStyle(Theme.secondaryText)
                    } else {
                        VStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(Theme.secondaryText.opacity(0.5))

                            Text("No sleep data")
                                .font(.system(.headline, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .padding(.vertical, Theme.Spacing.xl)
                    }

                    // Sleep stages if available
                    if let data = dayData, let stages = data.sleepStages, stages.hasStageData {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text("sleep.stages".localized)
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .padding(.horizontal)

                            // Mini donut chart
                            HStack(spacing: Theme.Spacing.xl) {
                                SleepDonutChart(stages: stages)
                                    .frame(width: 100, height: 100)

                                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                    SleepStageLegendRow(
                                        label: "sleep.awake".localized,
                                        duration: stages.formattedDuration(stages.awakeMinutes),
                                        percent: stages.awakePercent,
                                        color: .orange
                                    )
                                    SleepStageLegendRow(
                                        label: "sleep.rem".localized,
                                        duration: stages.formattedDuration(stages.remMinutes),
                                        percent: stages.remPercent,
                                        color: .cyan
                                    )
                                    SleepStageLegendRow(
                                        label: "sleep.core".localized,
                                        duration: stages.formattedDuration(stages.coreMinutes),
                                        percent: stages.corePercent,
                                        color: .blue
                                    )
                                    SleepStageLegendRow(
                                        label: "sleep.deep".localized,
                                        duration: stages.formattedDuration(stages.deepMinutes),
                                        percent: stages.deepPercent,
                                        color: .purple
                                    )
                                }
                            }
                            .padding(Theme.Spacing.lg)
                            .background(Theme.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }

                    // Sleep insights
                    if sleepMinutes > 0 {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text("Insights")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .padding(.horizontal)

                            VStack(spacing: Theme.Spacing.sm) {
                                if sleepMinutes >= 480 {
                                    SleepInsightRow(
                                        icon: "checkmark.circle.fill",
                                        text: "Great! You got the recommended 8 hours of sleep.",
                                        color: .green
                                    )
                                } else if sleepMinutes >= 420 {
                                    SleepInsightRow(
                                        icon: "checkmark.circle",
                                        text: "Good sleep! You're within the healthy range of 7-8 hours.",
                                        color: .yellow
                                    )
                                } else if sleepMinutes >= 360 {
                                    SleepInsightRow(
                                        icon: "exclamationmark.triangle.fill",
                                        text: "You got less than 7 hours. Try to get more rest tonight.",
                                        color: .orange
                                    )
                                } else if sleepMinutes > 0 {
                                    SleepInsightRow(
                                        icon: "exclamationmark.triangle.fill",
                                        text: "You got less than 6 hours. This can impact your health and energy.",
                                        color: .red
                                    )
                                }

                                if let data = dayData, let stages = data.sleepStages, stages.hasStageData {
                                    if stages.deepPercent >= 15 {
                                        SleepInsightRow(
                                            icon: "moon.fill",
                                            text: "Good deep sleep (\(stages.deepPercent)%) for physical recovery.",
                                            color: .purple
                                        )
                                    } else if stages.deepPercent > 0 {
                                        SleepInsightRow(
                                            icon: "moon",
                                            text: "Low deep sleep (\(stages.deepPercent)%). Aim for 15-20% for better recovery.",
                                            color: .orange
                                        )
                                    }

                                    if stages.remPercent >= 20 {
                                        SleepInsightRow(
                                            icon: "brain.head.profile",
                                            text: "Good REM sleep (\(stages.remPercent)%) for memory and learning.",
                                            color: .cyan
                                        )
                                    } else if stages.remPercent > 0 {
                                        SleepInsightRow(
                                            icon: "brain",
                                            text: "Low REM sleep (\(stages.remPercent)%). Aim for 20-25% for cognitive health.",
                                            color: .orange
                                        )
                                    }
                                }
                            }
                            .padding(Theme.Spacing.md)
                            .background(Theme.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                }
                .padding()
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Sleep Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Sleep Stage Legend Row

private struct SleepStageLegendRow: View {
    let label: String
    let duration: String
    let percent: Int
    let color: Color

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 50, alignment: .leading)

            Text(duration)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.primaryText)

            Text("(\(percent)%)")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
    }
}

// MARK: - Sleep Insight Row

private struct SleepInsightRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 24)

            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

// MARK: - Sleep Stages Card (Donut Chart)

private struct SleepStagesCard: View {
    let stages: SleepStages

    private var chartData: [(String, Double, Color)] {
        [
            ("sleep.awake".localized, stages.awakeMinutes, .orange),
            ("sleep.rem".localized, stages.remMinutes, .cyan),
            ("sleep.core".localized, stages.coreMinutes, .blue),
            ("sleep.deep".localized, stages.deepMinutes, .purple)
        ].filter { $0.1 > 0 }
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Header
            HStack {
                Text("sleep.stages".localized)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                Spacer()
            }

            // Donut Chart
            ZStack {
                // Ring segments
                SleepDonutChart(stages: stages)
                    .frame(width: 180, height: 180)

                // Center text
                VStack(spacing: 2) {
                    Text(stages.formattedDuration(stages.totalMinutes))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text("sleep.total".localized)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .padding(.vertical, Theme.Spacing.md)

            // Legend
            HStack(spacing: Theme.Spacing.lg) {
                ForEach(chartData, id: \.0) { item in
                    HStack(spacing: Theme.Spacing.xs) {
                        Circle()
                            .fill(item.2)
                            .frame(width: 10, height: 10)
                        Text(item.0)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }

            // Stage Cards Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                SleepStageDetailCard(
                    title: "sleep.awake".localized,
                    duration: stages.formattedDuration(stages.awakeMinutes),
                    percent: stages.awakePercent,
                    color: .orange
                )

                SleepStageDetailCard(
                    title: "sleep.rem".localized,
                    duration: stages.formattedDuration(stages.remMinutes),
                    percent: stages.remPercent,
                    color: .cyan
                )

                SleepStageDetailCard(
                    title: "sleep.core".localized,
                    duration: stages.formattedDuration(stages.coreMinutes),
                    percent: stages.corePercent,
                    color: .blue
                )

                SleepStageDetailCard(
                    title: "sleep.deep".localized,
                    duration: stages.formattedDuration(stages.deepMinutes),
                    percent: stages.deepPercent,
                    color: .purple
                )
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Sleep Donut Chart

private struct SleepDonutChart: View {
    let stages: SleepStages

    private var segments: [(Double, Color)] {
        let total = stages.totalMinutes
        guard total > 0 else { return [] }
        return [
            (stages.awakeMinutes / total, .orange),
            (stages.remMinutes / total, .cyan),
            (stages.coreMinutes / total, .blue),
            (stages.deepMinutes / total, .purple)
        ].filter { $0.0 > 0 }
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let lineWidth: CGFloat = 24

            ZStack {
                // Background ring
                Circle()
                    .stroke(Theme.tertiaryBackground, lineWidth: lineWidth)

                // Segments
                ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                    let startAngle = angleFor(index: index)
                    let endAngle = startAngle + Angle(degrees: segment.0 * 360)

                    Circle()
                        .trim(from: startAngle.degrees / 360, to: endAngle.degrees / 360)
                        .stroke(segment.1, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(width: size, height: size)
        }
    }

    private func angleFor(index: Int) -> Angle {
        var angle: Double = 0
        for i in 0..<index {
            angle += segments[i].0 * 360
        }
        return Angle(degrees: angle)
    }
}

// MARK: - Sleep Stage Detail Card

private struct SleepStageDetailCard: View {
    let title: String
    let duration: String
    let percent: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.primaryText)

            Text(duration)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.primaryText)

            Text("\(percent)% " + "sleep.ofSession".localized)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.secondaryText)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(percent) / 100, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Weekly Sleep Chart

private struct WeeklySleepChart: View {
    let weeklyData: [DailyHealthSummary]
    @Binding var selectedDay: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("sleep.weeklyOverview".localized)
                .font(.system(.headline, design: .rounded, weight: .bold))

            if let day = selectedDay,
               let summary = weeklyData.first(where: { $0.date.shortDayName == day }),
               let sleep = summary.metrics[.sleepDuration] {
                HStack {
                    Text(day)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                    Text("\(Int(sleep) / 60)h \(Int(sleep) % 60)m")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.sleep)
                }
            }

            Chart(weeklyData) { summary in
                let dayName = summary.date.shortDayName
                if let sleep = summary.metrics[.sleepDuration] {
                    BarMark(
                        x: .value("Day", dayName),
                        y: .value("Hours", sleep / 60.0)
                    )
                    .foregroundStyle(selectedDay == dayName ? Theme.sleep : Theme.sleep.opacity(0.7))
                    .cornerRadius(4)
                } else {
                    BarMark(
                        x: .value("Day", dayName),
                        y: .value("Hours", 0.3)
                    )
                    .foregroundStyle(Color.gray.opacity(0.2))
                    .cornerRadius(4)
                }
            }
            .frame(height: 120)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v))h")
                                .font(.system(.caption2, design: .rounded))
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    if let tappedDay: String = proxy.value(atX: value.location.x) {
                                        withAnimation {
                                            selectedDay = selectedDay == tappedDay ? nil : tappedDay
                                        }
                                    }
                                }
                        )
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Recovery Badge

struct RecoveryBadge: View {
    let score: Int
    let label: String
    var weeklyData: [DailyHealthSummary] = []

    @State private var showDetail = false

    private var color: Color {
        switch score {
        case 70...100: return Theme.recovery
        case 40..<70: return .yellow
        default: return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "dashboard.recovery".localized, icon: "arrow.counterclockwise.circle.fill", color: Theme.recovery)

            // Tappable score area
            Button {
                showDetail = true
            } label: {
                HStack(spacing: Theme.Spacing.lg) {
                    ZStack {
                        Circle()
                            .stroke(color.opacity(0.2), lineWidth: 8)
                            .frame(width: 60, height: 60)
                        Circle()
                            .trim(from: 0, to: Double(score) / 100.0)
                            .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                        Text("\(score)")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(color)
                    }

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(label)
                            .font(Theme.body)
                            .foregroundStyle(Theme.secondaryText)

                        if RecoveryScoreEngine.shouldRest(score: score) {
                            Label("Rest day recommended", systemImage: "moon.fill")
                                .font(Theme.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if !weeklyData.isEmpty {
                Button {
                    showDetail = true
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11))
                        Text("View Recovery Details")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(Theme.recovery)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.recovery.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.sm))
                }
                .buttonStyle(.plain)
            }
        }
        .cardStyle()
        .sheet(isPresented: $showDetail) {
            RecoveryDetailSheet(
                currentScore: score,
                currentLabel: label,
                weeklyData: weeklyData
            )
        }
    }
}

// MARK: - Insights Section

struct InsightsSection: View {
    let insights: [HealthInsight]
    var aiShortSummary: String? = nil
    var aiDetailedSummary: String? = nil
    var isGeneratingDetailed: Bool = false
    var supportsAI: Bool = false
    var insightHistory: [AIInsight] = []
    var onRequestDetailed: (() -> Void)? = nil

    @State private var showingDetailed = false
    @State private var showingHistory = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "insights.title".localized, icon: "lightbulb.fill", color: .purple)
                .padding(.bottom, Theme.Spacing.sm)

            // AI summary at top
                if let summary = aiShortSummary, !summary.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        HStack(alignment: .top, spacing: Theme.Spacing.md) {
                            Image(systemName: "sparkles")
                                .font(.system(size: Theme.IconSize.sm + 1, weight: .semibold))
                                .foregroundStyle(.purple)
                                .frame(width: Theme.IconFrame.sm, alignment: .center)

                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                // Show short or detailed text
                                if showingDetailed, let detailed = aiDetailedSummary {
                                    Text(detailed)
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(Theme.primaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .lineSpacing(3)
                                        .transition(.opacity)
                                } else {
                                    Text(summary)
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(Theme.primaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .lineSpacing(2)
                                }

                                // View More / View Less button
                                if showingDetailed && aiDetailedSummary != nil {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            showingDetailed = false
                                        }
                                    } label: {
                                        Text("Show Less")
                                            .font(.system(.caption, design: .rounded, weight: .semibold))
                                            .foregroundStyle(.purple)
                                    }
                                } else if isGeneratingDetailed {
                                    HStack(spacing: Theme.Spacing.xs) {
                                        ProgressView()
                                            .controlSize(.mini)
                                        Text("Generating analysis...")
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundStyle(Theme.secondaryText)
                                    }
                                } else {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            showingDetailed = true
                                        }
                                        if aiDetailedSummary == nil {
                                            onRequestDetailed?()
                                        }
                                    } label: {
                                        HStack(spacing: Theme.Spacing.xs) {
                                            Image(systemName: supportsAI ? "sparkles" : "text.magnifyingglass")
                                                .font(.system(size: 12, weight: .semibold))
                                            Text(supportsAI ? "AI Insights" : "View Details")
                                                .font(.system(.caption, design: .rounded, weight: .bold))
                                        }
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, Theme.Spacing.md)
                                        .padding(.vertical, Theme.Spacing.sm)
                                        .background(
                                            LinearGradient(
                                                colors: [.purple, .purple.opacity(0.7)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, Theme.Spacing.sm)

                    if !insights.isEmpty {
                        Divider()
                    }
                }

                ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                    HStack(alignment: .top, spacing: Theme.Spacing.md) {
                        Image(systemName: insight.icon)
                            .font(.system(size: Theme.IconSize.sm + 1, weight: .semibold))
                            .foregroundStyle(insight.color)
                            .frame(width: Theme.IconFrame.sm, alignment: .center)

                        Text(insight.text)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, Theme.Spacing.sm)

                    if index < insights.count - 1 {
                        Divider()
                    }
                }

                // View Insight History button
                if !insightHistory.isEmpty {
                    Button {
                        showingHistory = true
                    } label: {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 11))
                            Text("insights.viewHistory".localized)
                                .font(.system(.caption, design: .rounded, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Color.purple.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.sm))
                    }
                    .buttonStyle(.plain)
                }
            }
            .cardStyle()
            .animation(.easeInOut(duration: 0.25), value: showingDetailed)
            .animation(.easeInOut(duration: 0.25), value: aiDetailedSummary != nil)
            .sheet(isPresented: $showingHistory) {
                InsightHistorySheet(insights: insightHistory)
            }
    }
}

// MARK: - Insight History Sheet

struct InsightHistorySheet: View {
    let insights: [AIInsight]
    @Environment(\.dismiss) private var dismiss
    @State private var weeklySummary: AIInsight?
    @State private var isLoadingWeekly = false

    private var groupedInsights: [(date: Date, insights: [AIInsight])] {
        let grouped = Dictionary(grouping: insights.filter { $0.insightType != .weekly }) { insight -> Date in
            Calendar.current.startOfDay(for: insight.date ?? Date())
        }
        return grouped
            .map { (date: $0.key, insights: $0.value) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.lg) {
                    // Weekly Summary Card
                    WeeklySummaryCard(
                        summary: weeklySummary,
                        isLoading: isLoadingWeekly,
                        onGenerate: {
                            Task {
                                isLoadingWeekly = true
                                weeklySummary = await InsightsService.shared.generateWeeklySummary()
                                isLoadingWeekly = false
                            }
                        }
                    )
                    .padding(.horizontal)

                    ForEach(groupedInsights, id: \.date) { group in
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            // Date header
                            HStack {
                                Text(formatDateHeader(group.date))
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                    .foregroundStyle(Theme.primaryText)

                                Spacer()

                                if let firstInsight = group.insights.first {
                                    Text("\(firstInsight.score)")
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                        .foregroundStyle(scoreColor(for: Int(firstInsight.score)))
                                }
                            }

                            // Insights for this date
                            ForEach(group.insights, id: \.id) { insight in
                                InsightHistoryCard(insight: insight)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Theme.background)
            .navigationTitle("insights.history.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                }
            }
            .task {
                // Load existing weekly summary if available
                weeklySummary = InsightsService.shared.getInsight(for: Date(), type: .weekly)
            }
        }
    }

    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "common.today".localized
        } else if calendar.isDateInYesterday(date) {
            return "common.yesterday".localized
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }

    private func scoreColor(for score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .blue
        case 40..<60: return .orange
        default: return .red
        }
    }
}

struct InsightHistoryCard: View {
    let insight: AIInsight
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Header with type and time
            HStack {
                if let type = insight.insightType {
                    HStack(spacing: 4) {
                        Image(systemName: type.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(type.displayName)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                    }
                    .foregroundStyle(insightTypeColor(type))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(insightTypeColor(type).opacity(0.12))
                    .clipShape(Capsule())
                }

                Spacer()

                if let createdAt = insight.createdAt {
                    Text(formatTime(createdAt))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            // Short text
            if let shortText = insight.shortText {
                Text(shortText)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Detailed text (expandable)
            if let detailedText = insight.detailedText, !detailedText.isEmpty {
                if isExpanded {
                    Text(detailedText)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "insights.showLess".localized : "insights.showMore".localized)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(.purple)
                }
            }

            // Metrics summary if available
            if let metrics = insight.metrics {
                HStack(spacing: Theme.Spacing.md) {
                    if let sleep = metrics.sleepMinutes {
                        MetricChip(icon: "bed.double.fill", value: "\(Int(sleep / 60))h", color: Theme.sleep)
                    }
                    if let steps = metrics.steps {
                        MetricChip(icon: "figure.walk", value: "\(Int(steps))", color: Theme.steps)
                    }
                    if let recovery = metrics.recoveryScore {
                        MetricChip(icon: "arrow.counterclockwise", value: "\(recovery)", color: Theme.recovery)
                    }
                }
            }
        }
        .padding()
        .background(Theme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func insightTypeColor(_ type: InsightType) -> Color {
        switch type {
        case .morning: return .orange
        case .midday: return .yellow
        case .evening: return .indigo
        case .realtime: return .purple
        case .weekly: return .blue
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

struct MetricChip: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
            Text(value)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Weekly Summary Card

struct WeeklySummaryCard: View {
    let summary: AIInsight?
    let isLoading: Bool
    let onGenerate: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                    Text("insights.weeklySummary".localized)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                }
                .foregroundStyle(.blue)

                Spacer()

                if let summary = summary {
                    Text("\(summary.score)")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(scoreColor(for: Int(summary.score)))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(scoreColor(for: Int(summary.score)).opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            if isLoading {
                HStack(spacing: Theme.Spacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text("insights.generatingSummary".localized)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Theme.Spacing.md)
            } else if let summary = summary {
                // Summary content
                if let shortText = summary.shortText {
                    Text(shortText)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Detailed text (expandable)
                if let detailedText = summary.detailedText, !detailedText.isEmpty {
                    if isExpanded {
                        Text(detailedText)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(2)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isExpanded ? "insights.showLess".localized : "insights.showMore".localized)
                                .font(.system(.caption, design: .rounded, weight: .medium))
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(.blue)
                    }
                }
            } else {
                // No summary yet - show generate button
                VStack(spacing: Theme.Spacing.sm) {
                    Text("insights.noWeeklySummary".localized)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)

                    Button {
                        onGenerate()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .semibold))
                            Text("insights.generateSummary".localized)
                                .font(.system(.caption, design: .rounded, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
            }
        }
        .padding()
        .background(Theme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func scoreColor(for score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .blue
        case 40..<60: return .orange
        default: return .red
        }
    }
}

// MARK: - Weekly Trends

struct WeeklyTrendsSection: View {
    let data: [DailyHealthSummary]

    @State private var selectedStepsDay: String?
    @State private var selectedCalDay: String?
    @State private var selectedSleepDay: String?

    private func summaryFor(day: String?) -> DailyHealthSummary? {
        guard let day else { return nil }
        return data.first { $0.date.shortDayName == day }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "common.thisWeek".localized, icon: "chart.bar.fill", color: Theme.accentColor)

            // Steps chart
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("activity.steps".localized)
                        .font(Theme.headline)
                        .foregroundStyle(Theme.steps)

                    Spacer()

                    if let day = selectedStepsDay, let summary = summaryFor(day: day),
                       let steps = summary.metrics[.steps] {
                        HStack(spacing: Theme.Spacing.xs) {
                            Text(day)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                            Text("\(Int(steps))")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(Theme.steps)
                        }
                        .transition(.opacity)
                    }
                }

                Chart(data) { summary in
                    let dayName = summary.date.shortDayName
                    if summary.metrics[.steps] != nil {
                        BarMark(
                            x: .value("Day", dayName),
                            y: .value("Steps", summary.metrics[.steps]!)
                        )
                        .foregroundStyle(selectedStepsDay == dayName ? Theme.steps : Theme.steps.opacity(0.7))
                        .cornerRadius(4)
                    } else {
                        BarMark(
                            x: .value("Day", dayName),
                            y: .value("Steps", 500)
                        )
                        .foregroundStyle(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                    }

                    if selectedStepsDay == dayName {
                        RuleMark(x: .value("Day", dayName))
                            .foregroundStyle(Theme.secondaryText.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    }
                }
                .frame(height: 120)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let origin = geo[plotFrame].origin
                                let x = location.x - origin.x
                                if let tappedDay: String = proxy.value(atX: x) {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        selectedStepsDay = selectedStepsDay == tappedDay ? nil : tappedDay
                                    }
                                }
                            }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v / 1000))k")
                                    .font(.system(.caption2, design: .rounded))
                            }
                        }
                    }
                }
            }

            Divider()

            // Calories chart
            let hasCalories = data.contains { $0.metrics[.activeCalories] != nil }
            if hasCalories {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack {
                        Text("Calories Burned")
                            .font(Theme.headline)
                            .foregroundStyle(Theme.calories)

                        Spacer()

                        if let day = selectedCalDay, let summary = summaryFor(day: day),
                           let cal = summary.metrics[.activeCalories] {
                            HStack(spacing: Theme.Spacing.xs) {
                                Text(day)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                                Text("\(Int(cal)) kcal")
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundStyle(Theme.calories)
                            }
                            .transition(.opacity)
                        }
                    }

                    Chart(data) { summary in
                        let dayName = summary.date.shortDayName
                        if let cal = summary.metrics[.activeCalories] {
                            AreaMark(
                                x: .value("Day", dayName),
                                y: .value("Cal", cal)
                            )
                            .foregroundStyle(Theme.calories.opacity(0.3).gradient)

                            LineMark(
                                x: .value("Day", dayName),
                                y: .value("Cal", cal)
                            )
                            .foregroundStyle(Theme.calories)
                            .lineStyle(StrokeStyle(lineWidth: 2))

                            PointMark(
                                x: .value("Day", dayName),
                                y: .value("Cal", cal)
                            )
                            .foregroundStyle(selectedCalDay == dayName ? Theme.calories : Theme.calories.opacity(0.7))
                            .symbolSize(selectedCalDay == dayName ? 60 : 20)
                        } else {
                            PointMark(
                                x: .value("Day", dayName),
                                y: .value("Cal", 0)
                            )
                            .foregroundStyle(Color.gray.opacity(0.3))
                            .symbolSize(40)
                            .symbol(.circle)
                        }

                        if selectedCalDay == dayName {
                            RuleMark(x: .value("Day", dayName))
                                .foregroundStyle(Theme.secondaryText.opacity(0.3))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        }
                    }
                    .frame(height: 100)
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture { location in
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let origin = geo[plotFrame].origin
                                    let x = location.x - origin.x
                                    if let tappedDay: String = proxy.value(atX: x) {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            selectedCalDay = selectedCalDay == tappedDay ? nil : tappedDay
                                        }
                                    }
                                }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                }
            }

            Divider()

            // Sleep chart
            let hasSleep = data.contains { $0.metrics[.sleepDuration] != nil }
            if hasSleep {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack {
                        Text("dashboard.sleep".localized)
                            .font(Theme.headline)
                            .foregroundStyle(Theme.sleep)

                        Spacer()

                        if let day = selectedSleepDay, let summary = summaryFor(day: day),
                           let sleep = summary.metrics[.sleepDuration] {
                            HStack(spacing: Theme.Spacing.xs) {
                                Text(day)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                                Text("\(Int(sleep) / 60)h \(Int(sleep) % 60)m")
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundStyle(Theme.sleep)
                            }
                            .transition(.opacity)
                        }
                    }

                    Chart(data) { summary in
                        let dayName = summary.date.shortDayName
                        if let sleep = summary.metrics[.sleepDuration] {
                            BarMark(
                                x: .value("Day", dayName),
                                y: .value("Hours", sleep / 60.0)
                            )
                            .foregroundStyle(selectedSleepDay == dayName ? Theme.sleep : Theme.sleep.opacity(0.7))
                            .cornerRadius(4)
                        } else {
                            BarMark(
                                x: .value("Day", dayName),
                                y: .value("Hours", 0.3)
                            )
                            .foregroundStyle(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                        }

                        if selectedSleepDay == dayName {
                            RuleMark(x: .value("Day", dayName))
                                .foregroundStyle(Theme.secondaryText.opacity(0.3))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        }
                    }
                    .frame(height: 100)
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture { location in
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let origin = geo[plotFrame].origin
                                    let x = location.x - origin.x
                                    if let tappedDay: String = proxy.value(atX: x) {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            selectedSleepDay = selectedSleepDay == tappedDay ? nil : tappedDay
                                        }
                                    }
                                }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text("\(Int(v))h")
                                        .font(.system(.caption2, design: .rounded))
                                }
                            }
                        }
                    }
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - Recent Workouts Card

struct RecentWorkoutsCard: View {
    let workouts: [WorkoutData]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Recent Workouts", icon: "figure.run", color: Theme.activity)

            ForEach(workouts) { workout in
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: workout.icon)
                        .font(.title3)
                        .foregroundStyle(Theme.activity)
                        .frame(width: Theme.IconFrame.lg)

                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(workout.displayName)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        Text(workout.startDate.relativeDescription)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: Theme.Spacing.xxs) {
                        Text(workout.formattedDuration)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                        if let cal = workout.calories {
                            Text("\(Int(cal)) kcal")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Theme.calories)
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.xs)

                if workout.id != workouts.last?.id {
                    Divider()
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - Mindful Card

struct MindfulCard: View {
    let minutes: Double
    var weeklyData: [DailyHealthSummary] = []

    @State private var showDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "dashboard.mindfulness".localized, icon: "brain.head.profile", color: Theme.mindfulness)

            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Theme.mindfulness.opacity(0.15))
                        .frame(width: 50, height: 50)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: Theme.IconSize.lg - 2, weight: .medium))
                        .foregroundStyle(Theme.mindfulness)
                }

                Text("\(Int(minutes)) minutes today")
                    .font(Theme.body)
                    .foregroundStyle(Theme.secondaryText)

                Spacer()

                Text("\(Int(minutes))")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.mindfulness)
                Text("min")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            if !weeklyData.isEmpty {
                Button {
                    showDetail = true
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 11))
                        Text("View Mindfulness Details")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(Theme.mindfulness)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.mindfulness.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.sm))
                }
                .buttonStyle(.plain)
            }
        }
        .cardStyle()
        .sheet(isPresented: $showDetail) {
            MetricDetailSheet(
                title: "Mindfulness",
                icon: "brain.head.profile",
                color: Theme.mindfulness,
                metricType: .mindfulMinutes,
                weeklyData: weeklyData
            )
        }
    }
}

// MARK: - Empty State

struct EmptyDashboardView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer().frame(height: 40)

            Image(systemName: "heart.text.clipboard")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Health Data Yet")
                .font(Theme.title)

            Text("LifeIndex needs access to your health data. Make sure all categories are enabled in Health app settings.")
                .font(Theme.body)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SuggestionRow(icon: "gear", text: "Open Settings > Privacy > Health > LifeIndex and enable all categories")
                SuggestionRow(icon: "applewatch", text: "Wear your Apple Watch throughout the day")
                SuggestionRow(icon: "figure.run", text: "Log a workout in the Fitness app")
                SuggestionRow(icon: "bed.double.fill", text: "Enable sleep tracking tonight")
            }
            .padding()
            .background(Theme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))

            Button {
                if let url = URL(string: "x-apple-health://") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Open Health App", systemImage: "heart.fill")
                    .font(Theme.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}

struct SuggestionRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: Theme.IconSize.lg - 8, weight: .medium))
                .foregroundStyle(Theme.accentColor)
                .frame(width: Theme.IconFrame.md)
            Text(text)
                .font(Theme.body)
                .foregroundStyle(Theme.primaryText)
        }
    }
}

// MARK: - Reusable Metric Detail Sheet

struct MetricDetailSheet: View {
    let title: String
    let icon: String
    let color: Color
    let metricType: HealthMetricType
    let weeklyData: [DailyHealthSummary]

    @Environment(\.dismiss) private var dismiss

    private var todayValue: Double? {
        weeklyData.first(where: { $0.date.isToday })?.metrics[metricType]
    }

    private var yesterdayValue: Double? {
        weeklyData.first(where: { $0.date.isYesterday })?.metrics[metricType]
    }

    private var weeklyValues: [(day: String, date: Date, value: Double?)] {
        weeklyData.map { summary in
            (day: summary.date.shortDayName, date: summary.date, value: summary.metrics[metricType])
        }
    }

    private var weeklyAverage: Double? {
        let values = weeklyData.compactMap { $0.metrics[metricType] }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private var weeklyMin: Double? {
        weeklyData.compactMap { $0.metrics[metricType] }.min()
    }

    private var weeklyMax: Double? {
        weeklyData.compactMap { $0.metrics[metricType] }.max()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    // Today hero value
                    VStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: icon)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(color)

                        if let today = todayValue {
                            Text(formatValue(today))
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(color)
                            Text("Today")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        } else {
                            Text("No data")
                                .font(.system(.title2, design: .rounded, weight: .medium))
                                .foregroundStyle(Theme.secondaryText)
                            Text("Today")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.lg)

                    // Today vs Yesterday comparison
                    if todayValue != nil || yesterdayValue != nil {
                        HStack(spacing: Theme.Spacing.xl) {
                            ComparisonTile(
                                label: "Today",
                                value: todayValue.map { formatValue($0) } ?? "—",
                                color: color
                            )
                            ComparisonTile(
                                label: "Yesterday",
                                value: yesterdayValue.map { formatValue($0) } ?? "—",
                                color: color.opacity(0.7)
                            )

                            if let today = todayValue, let yesterday = yesterdayValue, yesterday > 0 {
                                let change = ((today - yesterday) / yesterday) * 100
                                ComparisonTile(
                                    label: "Change",
                                    value: "\(change >= 0 ? "+" : "")\(Int(change))%",
                                    color: change >= 0 ? .green : .orange
                                )
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.sm)
                    }

                    // Ideal range
                    if let target = LifeIndexScoreEngine.targets[metricType] {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "target")
                                .font(.system(size: Theme.IconSize.sm, weight: .semibold))
                                .foregroundStyle(color)
                            Text("Ideal range: \(formatRange(target))")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // 7-day chart
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Label("This Week", systemImage: "chart.bar.fill")
                            .font(.system(.headline, design: .rounded, weight: .semibold))

                        WeeklyMetricChart(
                            weeklyValues: weeklyValues,
                            color: color,
                            metricType: metricType
                        )
                    }

                    // Weekly stats
                    if weeklyAverage != nil || weeklyMin != nil || weeklyMax != nil {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Label("Weekly Stats", systemImage: "chart.line.uptrend.xyaxis")
                                .font(.system(.headline, design: .rounded, weight: .semibold))

                            HStack(spacing: Theme.Spacing.xl) {
                                if let avg = weeklyAverage {
                                    StatTile(label: "Average", value: formatValue(avg), color: color)
                                }
                                if let min = weeklyMin {
                                    StatTile(label: "Low", value: formatValue(min), color: .orange)
                                }
                                if let max = weeklyMax {
                                    StatTile(label: "High", value: formatValue(max), color: .green)
                                }
                            }
                        }
                    }

                    // Daily breakdown list
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Label("Daily Values", systemImage: "list.bullet")
                            .font(.system(.headline, design: .rounded, weight: .semibold))

                        ForEach(weeklyData.reversed(), id: \.id) { summary in
                            HStack {
                                Text(summary.date.relativeDescription)
                                    .font(.system(.subheadline, design: .rounded))
                                    .frame(width: 90, alignment: .leading)

                                Spacer()

                                if let value = summary.metrics[metricType] {
                                    Text(formatValue(value))
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                        .foregroundStyle(color)
                                    Text(metricType.unit)
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(Theme.secondaryText)
                                } else {
                                    Text("No data")
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(Theme.secondaryText)
                                }
                            }

                            if summary.id != weeklyData.first?.id {
                                Divider()
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
            }
        }
    }

    private func formatValue(_ value: Double) -> String {
        switch metricType {
        case .sleepDuration:
            let h = Int(value) / 60
            let m = Int(value) % 60
            return "\(h)h \(m)m"
        case .bloodOxygen:
            return "\(Int(value * 100))%"
        case .steps:
            return String(format: "%.0f", value)
        default:
            return String(format: "%.0f", value)
        }
    }

    private func formatRange(_ range: ClosedRange<Double>) -> String {
        switch metricType {
        case .bloodOxygen:
            return "\(Int(range.lowerBound * 100))–\(Int(range.upperBound * 100))%"
        case .sleepDuration:
            return "\(Int(range.lowerBound / 60))–\(Int(range.upperBound / 60)) hrs"
        default:
            return "\(Int(range.lowerBound))–\(Int(range.upperBound)) \(metricType.unit)"
        }
    }
}

struct ComparisonTile: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.primaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.md))
    }
}

struct StatTile: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WeeklyMetricChart: View {
    let weeklyValues: [(day: String, date: Date, value: Double?)]
    let color: Color
    let metricType: HealthMetricType

    @State private var selectedDay: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
            if let day = selectedDay,
               let entry = weeklyValues.first(where: { $0.day == day }),
               let value = entry.value {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(day)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                    Text(formatChartValue(value))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(color)
                }
                .transition(.opacity)
            }

            Chart(weeklyValues, id: \.day) { entry in
                if let value = entry.value {
                    let displayValue = metricType == .sleepDuration ? value / 60.0 : value

                    BarMark(
                        x: .value("Day", entry.day),
                        y: .value("Value", displayValue)
                    )
                    .foregroundStyle(selectedDay == entry.day ? color : color.opacity(0.7))
                    .cornerRadius(4)
                } else {
                    BarMark(
                        x: .value("Day", entry.day),
                        y: .value("Value", placeholderValue)
                    )
                    .foregroundStyle(Color.gray.opacity(0.2))
                    .cornerRadius(4)
                }

                if selectedDay == entry.day {
                    RuleMark(x: .value("Day", entry.day))
                        .foregroundStyle(Theme.secondaryText.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            guard let plotFrame = proxy.plotFrame else { return }
                            let origin = geo[plotFrame].origin
                            let x = location.x - origin.x
                            if let tappedDay: String = proxy.value(atX: x) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    if selectedDay == tappedDay {
                                        selectedDay = nil
                                    } else {
                                        selectedDay = tappedDay
                                    }
                                }
                            }
                        }
                }
            }
            .frame(height: 150)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatAxisLabel(v))
                                .font(.system(.caption2, design: .rounded))
                        }
                    }
                }
            }
        }
    }

    private var placeholderValue: Double {
        switch metricType {
        case .sleepDuration: return 0.3
        case .steps: return 500
        default: return 1
        }
    }

    private func formatChartValue(_ value: Double) -> String {
        switch metricType {
        case .sleepDuration:
            let h = Int(value) / 60
            let m = Int(value) % 60
            return "\(h)h \(m)m"
        case .bloodOxygen:
            return "\(Int(value * 100))%"
        default:
            return "\(Int(value)) \(metricType.unit)"
        }
    }

    private func formatAxisLabel(_ value: Double) -> String {
        switch metricType {
        case .sleepDuration: return "\(Int(value))h"
        case .steps: return "\(Int(value / 1000))k"
        default: return "\(Int(value))"
        }
    }
}

// MARK: - Recovery Detail Sheet

struct RecoveryDetailSheet: View {
    let currentScore: Int
    let currentLabel: String
    let weeklyData: [DailyHealthSummary]

    @Environment(\.dismiss) private var dismiss

    private var weeklyRecoveryScores: [(day: String, date: Date, score: Int?)] {
        weeklyData.map { summary in
            let hrv = summary.metrics[.heartRateVariability]
            let rhr = summary.metrics[.restingHeartRate]
            let sleep = summary.metrics[.sleepDuration]
            let score = RecoveryScoreEngine.calculateScore(hrv: hrv, restingHeartRate: rhr, sleepMinutes: sleep)
            return (day: summary.date.shortDayName, date: summary.date, score: score)
        }
    }

    private var yesterdayRecovery: Int? {
        weeklyData
            .first(where: { $0.date.isYesterday })
            .flatMap { summary in
                RecoveryScoreEngine.calculateScore(
                    hrv: summary.metrics[.heartRateVariability],
                    restingHeartRate: summary.metrics[.restingHeartRate],
                    sleepMinutes: summary.metrics[.sleepDuration]
                )
            }
    }

    private var weeklyAvg: Int? {
        let scores = weeklyRecoveryScores.compactMap { $0.score }
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / scores.count
    }

    private func recoveryColor(_ score: Int) -> Color {
        switch score {
        case 70...100: return Theme.recovery
        case 40..<70: return .yellow
        default: return .orange
        }
    }

    @State private var selectedDay: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    // Today's recovery
                    VStack(spacing: Theme.Spacing.sm) {
                        ZStack {
                            Circle()
                                .stroke(recoveryColor(currentScore).opacity(0.2), lineWidth: 10)
                                .frame(width: 100, height: 100)
                            Circle()
                                .trim(from: 0, to: Double(currentScore) / 100.0)
                                .stroke(recoveryColor(currentScore), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .frame(width: 100, height: 100)
                                .rotationEffect(.degrees(-90))
                            Text("\(currentScore)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(recoveryColor(currentScore))
                        }
                        Text(currentLabel)
                            .font(.system(.title3, design: .rounded, weight: .medium))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.lg)

                    // Comparison tiles
                    HStack(spacing: Theme.Spacing.xl) {
                        ComparisonTile(
                            label: "Today",
                            value: "\(currentScore)",
                            color: recoveryColor(currentScore)
                        )
                        if let yesterday = yesterdayRecovery {
                            ComparisonTile(
                                label: "Yesterday",
                                value: "\(yesterday)",
                                color: recoveryColor(yesterday).opacity(0.7)
                            )
                        }
                        if let avg = weeklyAvg {
                            ComparisonTile(
                                label: "7-day avg",
                                value: "\(avg)",
                                color: recoveryColor(avg)
                            )
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.sm)

                    // How recovery is calculated
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Label("How Recovery Works", systemImage: "gearshape.2.fill")
                            .font(.system(.headline, design: .rounded, weight: .semibold))

                        Text("Recovery score combines HRV (40%), resting heart rate (30%), and sleep duration (30%). Higher HRV and lower resting HR indicate better recovery.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Weekly chart
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        HStack {
                            Label("This Week", systemImage: "chart.bar.fill")
                                .font(.system(.headline, design: .rounded, weight: .semibold))

                            Spacer()

                            if let day = selectedDay,
                               let entry = weeklyRecoveryScores.first(where: { $0.day == day }),
                               let score = entry.score {
                                HStack(spacing: Theme.Spacing.xs) {
                                    Text(day)
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(Theme.secondaryText)
                                    Text("\(score)")
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                        .foregroundStyle(recoveryColor(score))
                                }
                            }
                        }

                        Chart(weeklyRecoveryScores, id: \.day) { entry in
                            if let score = entry.score {
                                BarMark(
                                    x: .value("Day", entry.day),
                                    y: .value("Score", score)
                                )
                                .foregroundStyle(selectedDay == entry.day ? recoveryColor(score) : recoveryColor(score).opacity(0.7))
                                .cornerRadius(4)
                            } else {
                                BarMark(
                                    x: .value("Day", entry.day),
                                    y: .value("Score", 5)
                                )
                                .foregroundStyle(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                            }

                            if selectedDay == entry.day {
                                RuleMark(x: .value("Day", entry.day))
                                    .foregroundStyle(Theme.secondaryText.opacity(0.3))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                            }
                        }
                        .chartOverlay { proxy in
                            GeometryReader { geo in
                                Rectangle()
                                    .fill(Color.clear)
                                    .contentShape(Rectangle())
                                    .onTapGesture { location in
                                        guard let plotFrame = proxy.plotFrame else { return }
                                        let origin = geo[plotFrame].origin
                                        let x = location.x - origin.x
                                        if let tappedDay: String = proxy.value(atX: x) {
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                if selectedDay == tappedDay {
                                                    selectedDay = nil
                                                } else {
                                                    selectedDay = tappedDay
                                                }
                                            }
                                        }
                                    }
                            }
                        }
                        .chartYScale(domain: 0...100)
                        .frame(height: 150)
                        .chartYAxis {
                            AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                                AxisValueLabel {
                                    if let v = value.as(Int.self) {
                                        Text("\(v)")
                                            .font(.system(.caption2, design: .rounded))
                                    }
                                }
                            }
                        }
                    }

                    // Daily breakdown
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Label("Daily Breakdown", systemImage: "list.bullet")
                            .font(.system(.headline, design: .rounded, weight: .semibold))

                        ForEach(weeklyRecoveryScores.reversed(), id: \.day) { entry in
                            HStack {
                                Text(entry.date.relativeDescription)
                                    .font(.system(.subheadline, design: .rounded))
                                    .frame(width: 90, alignment: .leading)

                                Spacer()

                                if let score = entry.score {
                                    Text("\(score)/100")
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                        .foregroundStyle(recoveryColor(score))
                                    Text(RecoveryScoreEngine.label(for: score))
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(Theme.secondaryText)
                                } else {
                                    Text("No data")
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(Theme.secondaryText)
                                }
                            }
                            Divider()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
            }
        }
    }
}

// MARK: - Heart Detail Sheet

struct HeartDetailSheet: View {
    let heartRate: Double?
    let restingHR: Double?
    let hrv: Double?
    let bloodOxygen: Double?
    let weeklyData: [DailyHealthSummary]

    @Environment(\.dismiss) private var dismiss

    private let heartMetrics: [(type: HealthMetricType, label: String, icon: String, color: Color)] = [
        (.heartRate, "Heart Rate", "heart.fill", Theme.heartRate),
        (.restingHeartRate, "Resting HR", "heart.circle", .pink),
        (.heartRateVariability, "HRV", "waveform.path.ecg", Theme.hrv),
        (.bloodOxygen, "Blood O₂", "lungs.fill", Theme.bloodOxygen),
    ]

    private func todayValue(for type: HealthMetricType) -> Double? {
        weeklyData.first(where: { $0.date.isToday })?.metrics[type]
    }

    private func yesterdayValue(for type: HealthMetricType) -> Double? {
        weeklyData.first(where: { $0.date.isYesterday })?.metrics[type]
    }

    private func weeklyAvg(for type: HealthMetricType) -> Double? {
        let values = weeklyData.compactMap { $0.metrics[type] }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func currentValue(for type: HealthMetricType) -> Double? {
        switch type {
        case .heartRate: return heartRate
        case .restingHeartRate: return restingHR
        case .heartRateVariability: return hrv
        case .bloodOxygen: return bloodOxygen
        default: return nil
        }
    }

    private func formatValue(_ value: Double, type: HealthMetricType) -> String {
        if type == .bloodOxygen {
            return "\(Int(value * 100))%"
        }
        return "\(Int(value))"
    }

    private func idealRange(for type: HealthMetricType) -> String? {
        guard let target = LifeIndexScoreEngine.targets[type] else { return nil }
        if type == .bloodOxygen {
            return "\(Int(target.lowerBound * 100))–\(Int(target.upperBound * 100))%"
        }
        return "\(Int(target.lowerBound))–\(Int(target.upperBound)) \(type.unit)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    ForEach(heartMetrics, id: \.type) { metric in
                        let current = currentValue(for: metric.type)

                        if current != nil || weeklyData.contains(where: { $0.metrics[metric.type] != nil }) {
                            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                                // Metric header
                                HStack(spacing: Theme.Spacing.sm) {
                                    Image(systemName: metric.icon)
                                        .font(.system(size: Theme.IconSize.md, weight: .semibold))
                                        .foregroundStyle(metric.color)
                                    Text(metric.label)
                                        .font(.system(.headline, design: .rounded, weight: .semibold))
                                }

                                // Today hero
                                if let value = current {
                                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                                        Text(formatValue(value, type: metric.type))
                                            .font(.system(size: 36, weight: .bold, design: .rounded))
                                            .foregroundStyle(metric.color)
                                        if metric.type != .bloodOxygen {
                                            Text(metric.type.unit)
                                                .font(.system(.body, design: .rounded))
                                                .foregroundStyle(Theme.secondaryText)
                                        }
                                    }
                                }

                                // Ideal range
                                if let range = idealRange(for: metric.type) {
                                    HStack(spacing: Theme.Spacing.xs) {
                                        Image(systemName: "target")
                                            .font(.system(size: 11))
                                        Text("Ideal: \(range)")
                                            .font(.system(.caption, design: .rounded))
                                    }
                                    .foregroundStyle(Theme.secondaryText)
                                }

                                // Comparison tiles
                                HStack(spacing: Theme.Spacing.xl) {
                                    ComparisonTile(
                                        label: "Today",
                                        value: todayValue(for: metric.type).map { formatValue($0, type: metric.type) } ?? "—",
                                        color: metric.color
                                    )
                                    ComparisonTile(
                                        label: "Yesterday",
                                        value: yesterdayValue(for: metric.type).map { formatValue($0, type: metric.type) } ?? "—",
                                        color: metric.color.opacity(0.7)
                                    )
                                    ComparisonTile(
                                        label: "7-day avg",
                                        value: weeklyAvg(for: metric.type).map { formatValue($0, type: metric.type) } ?? "—",
                                        color: metric.color.opacity(0.5)
                                    )
                                }

                                // Weekly chart
                                let values: [(day: String, date: Date, value: Double?)] = weeklyData.map { summary in
                                    (day: summary.date.shortDayName, date: summary.date, value: summary.metrics[metric.type])
                                }

                                WeeklyMetricChart(
                                    weeklyValues: values,
                                    color: metric.color,
                                    metricType: metric.type
                                )
                            }

                            if metric.type != .bloodOxygen {
                                Divider()
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Heart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
            }
        }
    }
}

// MARK: - Activity Detail Sheet

struct ActivityDetailSheet: View {
    let weeklyData: [DailyHealthSummary]

    @Environment(\.dismiss) private var dismiss

    private let metrics: [(type: HealthMetricType, label: String, color: Color, unit: String)] = [
        (.steps, "Steps", Theme.steps, "steps"),
        (.activeCalories, "Calories", Theme.calories, "kcal"),
        (.workoutMinutes, "Exercise", Theme.activity, "min"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    ForEach(metrics, id: \.type) { metric in
                        ActivityMetricSection(
                            metricType: metric.type,
                            label: metric.label,
                            color: metric.color,
                            weeklyData: weeklyData
                        )

                        if metric.type != .workoutMinutes {
                            Divider()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Activity Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
            }
        }
    }
}

struct ActivityMetricSection: View {
    let metricType: HealthMetricType
    let label: String
    let color: Color
    let weeklyData: [DailyHealthSummary]

    private var todayValue: Double? {
        weeklyData.first(where: { $0.date.isToday })?.metrics[metricType]
    }

    private var yesterdayValue: Double? {
        weeklyData.first(where: { $0.date.isYesterday })?.metrics[metricType]
    }

    private var weeklyAvg: Double? {
        let values = weeklyData.compactMap { $0.metrics[metricType] }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: metricType.icon)
                    .font(.system(size: Theme.IconSize.md, weight: .semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
            }

            HStack(spacing: Theme.Spacing.xl) {
                ComparisonTile(
                    label: "Today",
                    value: todayValue.map { "\(Int($0))" } ?? "—",
                    color: color
                )
                ComparisonTile(
                    label: "Yesterday",
                    value: yesterdayValue.map { "\(Int($0))" } ?? "—",
                    color: color.opacity(0.7)
                )
                ComparisonTile(
                    label: "7-day avg",
                    value: weeklyAvg.map { "\(Int($0))" } ?? "—",
                    color: color.opacity(0.5)
                )
            }

            // Mini chart
            let values: [(day: String, date: Date, value: Double?)] = weeklyData.map { summary in
                (day: summary.date.shortDayName, date: summary.date, value: summary.metrics[metricType])
            }

            WeeklyMetricChart(
                weeklyValues: values,
                color: color,
                metricType: metricType
            )
        }
    }
}
