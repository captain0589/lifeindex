import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // MARK: - Header
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(viewModel.greeting)
                            .font(Theme.largeTitle)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                        Text(viewModel.todayDateString)
                            .font(Theme.body)
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if viewModel.hasData {
                        // Show banner if using yesterday's data
                        if viewModel.showingYesterdayData {
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: Theme.IconSize.sm, weight: .medium))
                                Text("Showing most recent data — today hasn't synced yet")
                                    .font(.system(.caption, design: .rounded))
                            }
                            .foregroundStyle(.secondary)
                            .padding(.vertical, Theme.Spacing.sm)
                            .padding(.horizontal, Theme.Spacing.md)
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // MARK: - LifeIndex Score (top)
                        LifeIndexScoreCard(
                            score: viewModel.lifeIndexScore,
                            label: viewModel.scoreLabel,
                            explanation: viewModel.scoreExplanation,
                            topContributor: viewModel.topContributor,
                            weakestArea: viewModel.weakestArea,
                            breakdown: viewModel.scoreBreakdown
                        )

                        // MARK: - Score Breakdown (related to score)
                        if !viewModel.scoreBreakdown.isEmpty {
                            ScoreBreakdownCard(breakdown: viewModel.scoreBreakdown)
                        }

                        // MARK: - Score History Sparkline
                        if !viewModel.weeklyScores.isEmpty {
                            ScoreHistoryCard(
                                weeklyScores: viewModel.weeklyScores,
                                yesterdayScore: viewModel.yesterdayScore,
                                weeklyAverage: viewModel.weeklyAverageScore
                            )
                        }

                        // MARK: - Insights (with AI summary)
                        if !viewModel.insights.isEmpty || viewModel.aiShortSummary != nil {
                            InsightsSection(
                                insights: viewModel.insights,
                                aiShortSummary: viewModel.aiShortSummary,
                                aiDetailedSummary: viewModel.aiDetailedSummary,
                                isGeneratingDetailed: viewModel.isGeneratingDetailed,
                                supportsAI: viewModel.supportsAI,
                                onRequestDetailed: {
                                    Task { await viewModel.generateDetailedSummary() }
                                }
                            )
                        }

                        // MARK: - Activity Rings
                        ActivityCard(
                            steps: viewModel.stepsValue,
                            stepsGoal: viewModel.stepsGoal,
                            calories: viewModel.caloriesValue,
                            caloriesGoal: viewModel.caloriesGoal,
                            exercise: viewModel.workoutMinutesValue,
                            exerciseGoal: viewModel.workoutMinutesGoal,
                            activitySummary: viewModel.activitySummary,
                            weeklyData: viewModel.weeklyData
                        )

                        // MARK: - Sleep
                        if let sleep = viewModel.sleepMinutes {
                            SleepCard(minutes: sleep, weeklyData: viewModel.weeklyData)
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

                        // MARK: - Recovery
                        if let recovery = viewModel.recoveryScore {
                            RecoveryBadge(score: recovery, label: viewModel.recoveryLabel, weeklyData: viewModel.weeklyData)
                        }

                        // MARK: - Recent Workouts
                        if !viewModel.recentWorkouts.isEmpty {
                            RecentWorkoutsCard(workouts: viewModel.recentWorkouts)
                        }

                        // MARK: - Weekly Trends
                        if !viewModel.weeklyData.isEmpty {
                            WeeklyTrendsSection(data: viewModel.weeklyData)
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
            .refreshable {
                await viewModel.loadData(forceRefresh: true)
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Loading health data...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
        .task {
            viewModel.configure(with: healthKitManager)
            await viewModel.loadData()
        }
    }
}

// MARK: - Score History Sparkline

struct ScoreHistoryCard: View {
    let weeklyScores: [(date: Date, score: Int)]
    let yesterdayScore: Int?
    let weeklyAverage: Int?

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
                SectionHeader(title: "Score History", icon: "chart.line.uptrend.xyaxis", color: Theme.accentColor)

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
                weeklyAverage: weeklyAverage
            )
        }
    }
}

// MARK: - Score History Detail Sheet

struct ScoreHistoryDetailSheet: View {
    let weeklyScores: [(date: Date, score: Int)]
    let yesterdayScore: Int?
    let weeklyAverage: Int?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDay: String?

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
                            HStack {
                                Text(entry.date.relativeDescription)
                                    .font(.system(.subheadline, design: .rounded))
                                    .frame(width: 90, alignment: .leading)

                                Spacer()

                                Text("\(entry.score)/100")
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundStyle(scoreColor(entry.score))

                                Text(LifeIndexScoreEngine.label(for: entry.score))
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                            }

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
        }
    }
}

// MARK: - Score Breakdown

struct ScoreBreakdownCard: View {
    let breakdown: [(type: HealthMetricType, score: Double, value: Double)]

    @State private var expandedMetric: HealthMetricType?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Score Breakdown", icon: "chart.pie.fill", color: Theme.accentColor)

            ForEach(breakdown, id: \.type) { item in
                VStack(spacing: Theme.Spacing.sm) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: item.type.icon)
                            .font(.system(size: Theme.IconSize.sm, weight: .semibold))
                            .foregroundStyle(colorFor(item.type))
                            .frame(width: Theme.IconFrame.sm)

                        Text(item.type.displayName)
                            .font(.system(.subheadline, design: .rounded))
                            .frame(width: 90, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(colorFor(item.type).opacity(0.15))
                                    .frame(height: Theme.progressBarHeight)

                                Capsule()
                                    .fill(colorFor(item.type))
                                    .frame(width: geo.size.width * item.score, height: Theme.progressBarHeight)
                            }
                        }
                        .frame(height: Theme.progressBarHeight)

                        Text(HealthDataPoint(type: item.type, value: item.value, date: .now).formattedValue)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.secondaryText)
                            .frame(width: 50, alignment: .trailing)
                    }

                    // Expanded detail row
                    if expandedMetric == item.type {
                        HStack(spacing: Theme.Spacing.sm) {
                            Spacer().frame(width: Theme.IconFrame.sm)

                            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                if let target = LifeIndexScoreEngine.targets[item.type] {
                                    HStack(spacing: Theme.Spacing.xs) {
                                        Image(systemName: "target")
                                            .font(.system(size: 10))
                                        Text("Ideal: \(formatTarget(target, type: item.type))")
                                            .font(.system(.caption2, design: .rounded))
                                    }
                                    .foregroundStyle(Theme.secondaryText)
                                }

                                if let weight = LifeIndexScoreEngine.weights[item.type] {
                                    HStack(spacing: Theme.Spacing.xs) {
                                        Image(systemName: "scalemass")
                                            .font(.system(size: 10))
                                        Text("Weight: \(Int(weight * 100))% of total score")
                                            .font(.system(.caption2, design: .rounded))
                                    }
                                    .foregroundStyle(Theme.secondaryText)
                                }

                                HStack(spacing: Theme.Spacing.xs) {
                                    Circle()
                                        .fill(scoreStatusColor(item.score))
                                        .frame(width: 6, height: 6)
                                    Text("Score: \(Int(item.score * 100))%")
                                        .font(.system(.caption2, design: .rounded, weight: .medium))
                                        .foregroundStyle(scoreStatusColor(item.score))
                                }
                            }

                            Spacer()
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if expandedMetric == item.type {
                            expandedMetric = nil
                        } else {
                            expandedMetric = item.type
                        }
                    }
                }
            }
        }
        .cardStyle()
    }

    private func colorFor(_ type: HealthMetricType) -> Color {
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

    private func scoreStatusColor(_ score: Double) -> Color {
        switch score {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .yellow
        case 0.4..<0.6: return .orange
        default: return .red
        }
    }

    private func formatTarget(_ range: ClosedRange<Double>, type: HealthMetricType) -> String {
        switch type {
        case .bloodOxygen:
            return "\(Int(range.lowerBound * 100))–\(Int(range.upperBound * 100))%"
        case .sleepDuration:
            return "\(Int(range.lowerBound / 60))–\(Int(range.upperBound / 60)) hrs"
        default:
            return "\(Int(range.lowerBound))–\(Int(range.upperBound)) \(type.unit)"
        }
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
            SectionHeader(title: "Activity", icon: "flame.fill", color: Theme.activity)

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
                        label: "Steps",
                        value: "\(Int(steps))",
                        goal: "\(Int(stepsGoal))",
                        currentValue: steps,
                        goalValue: stepsGoal
                    )
                    ActivityLegendRow(
                        color: Theme.calories,
                        icon: "flame.fill",
                        label: "Calories",
                        value: "\(Int(calories))",
                        goal: "\(Int(caloriesGoal)) kcal",
                        currentValue: calories,
                        goalValue: caloriesGoal
                    )
                    ActivityLegendRow(
                        color: Theme.activity,
                        icon: "figure.run",
                        label: "Exercise",
                        value: "\(Int(exercise))",
                        goal: "\(Int(exerciseGoal)) min",
                        currentValue: exercise,
                        goalValue: exerciseGoal
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

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
            SectionHeader(title: "Heart", icon: "heart.fill", color: Theme.heartRate)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
                if let hr = heartRate {
                    HeartMetricTile(icon: "heart.fill", label: "Heart Rate", value: "\(Int(hr))", unit: "bpm", color: Theme.heartRate)
                }
                if let rhr = restingHR {
                    HeartMetricTile(icon: "heart.circle", label: "Resting HR", value: "\(Int(rhr))", unit: "bpm", color: .pink)
                }
                if let h = hrv {
                    HeartMetricTile(icon: "waveform.path.ecg", label: "HRV", value: "\(Int(h))", unit: "ms", color: Theme.hrv)
                }
                if let o2 = bloodOxygen {
                    HeartMetricTile(icon: "lungs.fill", label: "Blood O2", value: "\(Int(o2 * 100))", unit: "%", color: Theme.bloodOxygen)
                }
            }

            if !weeklyData.isEmpty {
                Button {
                    showDetail = true
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11))
                        Text("View Heart Details")
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

    @State private var showDetail = false

    private var hours: Int { Int(minutes) / 60 }
    private var mins: Int { Int(minutes) % 60 }
    private var quality: String {
        switch minutes {
        case 420...540: return "Ideal"
        case 360..<420: return "Fair"
        case 540...: return "Oversleep"
        default: return "Low"
        }
    }
    private var qualityColor: Color {
        switch minutes {
        case 420...540: return .green
        case 360..<420: return .yellow
        default: return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Sleep", icon: "bed.double.fill", color: Theme.sleep)

            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                        Text("\(hours)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                        Text("hr")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                        Text("\(mins)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                        Text("min")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }

                    Text(quality)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(qualityColor)
                }

                Spacer()

                // Sleep gauge
                ZStack {
                    Circle()
                        .stroke(Theme.sleep.opacity(0.2), lineWidth: 10)
                        .frame(width: 70, height: 70)
                    Circle()
                        .trim(from: 0, to: min(1.0, minutes / 540))
                        .stroke(Theme.sleep, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "moon.zzz.fill")
                        .foregroundStyle(Theme.sleep)
                }
            }

            // Sleep target bar
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.sleep.opacity(0.15)).frame(height: Theme.progressBarHeight - 2)
                        Capsule().fill(Theme.sleep).frame(width: geo.size.width * min(1.0, minutes / 540), height: Theme.progressBarHeight - 2)
                    }
                }
                .frame(height: Theme.progressBarHeight - 2)

                HStack {
                    Text("0h")
                    Spacer()
                    Text("Target: 7-9h")
                    Spacer()
                    Text("9h+")
                }
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
            }

            if !weeklyData.isEmpty {
                Button {
                    showDetail = true
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "bed.double.fill")
                            .font(.system(size: 11))
                        Text("View Sleep Details")
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
            MetricDetailSheet(
                title: "Sleep",
                icon: "bed.double.fill",
                color: Theme.sleep,
                metricType: .sleepDuration,
                weeklyData: weeklyData
            )
        }
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
            SectionHeader(title: "Recovery", icon: "arrow.counterclockwise.circle.fill", color: Theme.recovery)

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
    var onRequestDetailed: (() -> Void)? = nil

    @State private var showingDetailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Insights", icon: "lightbulb.fill", color: .yellow)

            VStack(spacing: 0) {
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
            }
            .cardStyle()
        }
        .animation(.easeInOut(duration: 0.25), value: showingDetailed)
        .animation(.easeInOut(duration: 0.25), value: aiDetailedSummary != nil)
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
            SectionHeader(title: "This Week", icon: "chart.bar.fill", color: Theme.accentColor)

            // Steps chart
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("Steps")
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
                        Text("Sleep")
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
            SectionHeader(title: "Mindfulness", icon: "brain.head.profile", color: Theme.mindfulness)

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
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(color.opacity(0.08))
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
