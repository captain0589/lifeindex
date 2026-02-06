import SwiftUI
import Charts

// MARK: - Combined LifeIndex Section (Score + History)

struct LifeIndexSection: View {
    let score: Int
    let label: String
    var breakdown: [(type: HealthMetricType, score: Double, value: Double)] = []
    var yesterdayScore: Int? = nil
    var weeklyScores: [(date: Date, score: Int)] = []
    var weeklyAverage: Int? = nil
    var weeklyData: [DailyHealthSummary] = []
    // Insights integrated into this section
    var insights: [HealthInsight] = []
    var aiShortSummary: String? = nil
    var aiDetailedSummary: String? = nil
    var isGeneratingDetailed: Bool = false
    var supportsAI: Bool = false
    var insightHistory: [AIInsight] = []
    var onRequestDetailed: (() -> Void)? = nil

    @State private var showScoreSheet = false
    @State private var showYesterdayReport = false
    @State private var selectedChartDay: String?
    @State private var showingHistory = false
    @State private var showingDetailed = false

    private var scoreColor: Color {
        scoreColorFor(score)
    }

    private func scoreColorFor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    private var selectedEntry: (date: Date, score: Int)? {
        guard let day = selectedChartDay else { return nil }
        return weeklyScores.first { $0.date.shortDayName == day }
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // MARK: - Today's Score Card
            VStack(spacing: Theme.Spacing.lg) {
                // Header
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: Theme.IconSize.sm, weight: .semibold))
                        .foregroundStyle(Theme.accentColor)
                    Text("lifeindex.today".localized)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Spacer()
                }

                // Score circle - tappable
                Button {
                    showScoreSheet = true
                } label: {
                    ZStack {
                        Circle()
                            .stroke(scoreColor.opacity(0.2), lineWidth: 12)
                            .frame(width: 140, height: 140)

                        Circle()
                            .trim(from: 0, to: CGFloat(score) / 100.0)
                            .stroke(
                                scoreColor,
                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                            )
                            .frame(width: 140, height: 140)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 1.0), value: score)

                        VStack(spacing: Theme.Spacing.xxs) {
                            Text("\(score)")
                                .font(Theme.scoreFont)
                                .foregroundStyle(scoreColor)
                                .contentTransition(.numericText())

                            Text(label)
                                .font(Theme.caption)
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
                .buttonStyle(.plain)

                // View Today's Detail Button (below score circle)
                Button {
                    showScoreSheet = true
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 11))
                        Text("lifeindex.viewDetail".localized)
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

                // Integrated Insights Section (below detail button)
                if !insights.isEmpty || aiShortSummary != nil {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        // AI Summary with expand/collapse
                        if let summary = aiShortSummary, !summary.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.purple)

                                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                        // Show short or detailed text
                                        if showingDetailed, let detailed = aiDetailedSummary {
                                            Text(detailed)
                                                .font(.system(.subheadline, design: .rounded))
                                                .foregroundStyle(Theme.primaryText)
                                                .fixedSize(horizontal: false, vertical: true)
                                                .lineSpacing(3)
                                        } else {
                                            Text(summary)
                                                .font(.system(.subheadline, design: .rounded))
                                                .foregroundStyle(Theme.primaryText)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }

                                        // View More / View Less button
                                        if showingDetailed && aiDetailedSummary != nil {
                                            Button {
                                                withAnimation(.easeInOut(duration: 0.25)) {
                                                    showingDetailed = false
                                                }
                                            } label: {
                                                Text("insights.showLess".localized)
                                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                                                    .foregroundStyle(.purple)
                                            }
                                        } else if isGeneratingDetailed {
                                            HStack(spacing: Theme.Spacing.xs) {
                                                ProgressView()
                                                    .controlSize(.mini)
                                                Text("insights.generating".localized)
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
                                                        .font(.system(size: 10, weight: .semibold))
                                                    Text(supportsAI ? "insights.aiInsights".localized : "insights.viewDetails".localized)
                                                        .font(.system(.caption, design: .rounded, weight: .semibold))
                                                }
                                                .foregroundStyle(.purple)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(Theme.Spacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.purple.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
                        }

                        // Individual insights
                        ForEach(insights.prefix(3)) { insight in
                            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                                Image(systemName: insight.icon)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(insight.color)
                                    .frame(width: 16)
                                Text(insight.text)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
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
                    .padding(.top, Theme.Spacing.xs)
                }
            }
            .cardStyle()

            // MARK: - Weekly Stats & Chart Section
            if !weeklyScores.isEmpty {
                WeeklyStatsSectionWithChart(
                    weeklyScores: weeklyScores,
                    weeklyAverage: weeklyAverage
                )
            }
        }
        .sheet(isPresented: $showScoreSheet) {
            ScoreExplainerSheet(
                score: score,
                label: label,
                scoreColor: scoreColor,
                breakdown: breakdown
            )
        }
        .sheet(isPresented: $showingHistory) {
            InsightHistorySheet(insights: insightHistory)
        }
        .animation(.easeInOut(duration: 0.25), value: showingDetailed)
        .animation(.easeInOut(duration: 0.25), value: aiDetailedSummary != nil)
    }
}

// MARK: - Weekly Stats Section With Chart

struct WeeklyStatsSectionWithChart: View {
    let weeklyScores: [(date: Date, score: Int)]
    let weeklyAverage: Int?

    @State private var selectedDay: String? = nil

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    private var weeklyMin: Int? { weeklyScores.map(\.score).min() }
    private var weeklyMax: Int? { weeklyScores.map(\.score).max() }

    private var selectedEntry: (date: Date, score: Int)? {
        guard let day = selectedDay else { return nil }
        return weeklyScores.first { $0.date.shortDayName == day }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: Theme.IconSize.sm, weight: .semibold))
                    .foregroundStyle(Theme.accentColor)
                Text("ui.thisWeek".localized)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                Spacer()
            }

            // Comparison tiles (above chart)
            HStack(spacing: Theme.Spacing.xl) {
                // Today's score
                if let today = weeklyScores.first(where: { Calendar.current.isDateInToday($0.date) }) {
                    ComparisonTile(
                        label: "common.today".localized,
                        value: "\(today.score)",
                        color: scoreColor(today.score)
                    )
                }
                // Yesterday's score
                if let yesterday = weeklyScores.first(where: { Calendar.current.isDateInYesterday($0.date) }) {
                    ComparisonTile(
                        label: "common.yesterday".localized,
                        value: "\(yesterday.score)",
                        color: scoreColor(yesterday.score).opacity(0.7)
                    )
                }
                // 7-day average
                if let avg = weeklyAverage {
                    ComparisonTile(
                        label: "sleep.7dayAvg".localized,
                        value: "\(avg)",
                        color: scoreColor(avg)
                    )
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)

            // Weekly chart with selection
            Chart(weeklyScores, id: \.date) { entry in
                LineMark(
                    x: .value("Day", entry.date.shortDayName),
                    y: .value("Score", entry.score)
                )
                .foregroundStyle(Theme.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Day", entry.date.shortDayName),
                    y: .value("Score", entry.score)
                )
                .foregroundStyle(selectedDay == entry.date.shortDayName ? Theme.accentColor : scoreColor(entry.score))
                .symbolSize(selectedDay == entry.date.shortDayName ? 100 : 50)

                AreaMark(
                    x: .value("Day", entry.date.shortDayName),
                    y: .value("Score", entry.score)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.accentColor.opacity(0.15), Theme.accentColor.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                // Selection rule line
                if selectedDay == entry.date.shortDayName {
                    RuleMark(x: .value("Day", entry.date.shortDayName))
                        .foregroundStyle(Theme.accentColor.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 2]))
                }
            }
            .chartYScale(domain: 0...100)
            .chartXSelection(value: $selectedDay)
            .frame(height: 100)

            // Selected day detail
            if let entry = selectedEntry {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondaryText)
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text("\(entry.score)")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(scoreColor(entry.score))
                    Text(LifeIndexScoreEngine.label(for: entry.score))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Theme.tertiaryBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
            }
        }
        .cardStyle()
    }
}


// MARK: - Legacy LifeIndexScoreCard (for backwards compatibility)

struct LifeIndexScoreCard: View {
    let score: Int
    let label: String
    let explanation: String
    let topContributor: ScoreContributor?
    let weakestArea: ScoreContributor?
    var breakdown: [(type: HealthMetricType, score: Double, value: Double)] = []
    var yesterdayScore: Int? = nil
    var onViewYesterday: (() -> Void)? = nil

    @State private var showScoreSheet = false

    var scoreColor: Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("lifeindex.today".localized)
                .font(Theme.headline)
                .foregroundStyle(Theme.secondaryText)

            ZStack {
                Circle()
                    .stroke(scoreColor.opacity(0.2), lineWidth: 12)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100.0)
                    .stroke(
                        scoreColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: score)

                VStack(spacing: Theme.Spacing.xxs) {
                    Text("\(score)")
                        .font(Theme.scoreFont)
                        .foregroundStyle(scoreColor)
                        .contentTransition(.numericText())

                    Text(label)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            // Dynamic explanation
            Text(explanation)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.sm)

            // Top contributor & weakest area badges
            if topContributor != nil || weakestArea != nil {
                HStack(spacing: Theme.Spacing.md) {
                    if let top = topContributor {
                        ContributorBadge(
                            icon: "arrow.up.circle.fill",
                            label: top.name,
                            detail: "\(Int(top.percentage))%",
                            color: .green
                        )
                    }

                    if let weak = weakestArea {
                        ContributorBadge(
                            icon: "arrow.down.circle.fill",
                            label: weak.name,
                            detail: "\(Int(weak.percentage))%",
                            color: .orange
                        )
                    }
                }
            }

            // Action buttons
            VStack(spacing: Theme.Spacing.sm) {
                Button {
                    showScoreSheet = true
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 11))
                        Text("lifeindex.viewScoreDetails".localized)
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

                // View Yesterday button (especially useful late at night)
                if let onViewYesterday = onViewYesterday, let yesterdayScore = yesterdayScore {
                    Button {
                        onViewYesterday()
                    } label: {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 11))
                            Text("View Yesterday's Report (\(yesterdayScore))")
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
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
        .sheet(isPresented: $showScoreSheet) {
            ScoreExplainerSheet(
                score: score,
                label: label,
                scoreColor: scoreColor,
                breakdown: breakdown
            )
        }
    }
}

// MARK: - Score Explainer Sheet

struct ScoreExplainerSheet: View {
    let score: Int
    let label: String
    let scoreColor: Color
    let breakdown: [(type: HealthMetricType, score: Double, value: Double)]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // Score header with ring
                    ZStack {
                        Circle()
                            .stroke(scoreColor.opacity(0.2), lineWidth: 10)
                            .frame(width: 120, height: 120)

                        Circle()
                            .trim(from: 0, to: CGFloat(score) / 100.0)
                            .stroke(scoreColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 2) {
                            Text("\(score)")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundStyle(scoreColor)
                            Text(label)
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .padding(.top, Theme.Spacing.md)

                    // Tab picker
                    Picker("View", selection: $selectedTab) {
                        Text("lifeindex.yourMetrics".localized).tag(0)
                        Text("lifeindex.howItWorks".localized).tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if selectedTab == 0 {
                        metricsBreakdownView
                    } else {
                        howItWorksView
                    }
                }
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Theme.background)
            .navigationTitle("lifeindex.scoreBreakdown".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done".localized) { dismiss() }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
            }
        }
    }

    // MARK: - Metrics Breakdown View

    private var metricsBreakdownView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            if !breakdown.isEmpty {
                ForEach(breakdown.sorted(by: { $0.score > $1.score }), id: \.type) { item in
                    MetricScoreRow(
                        type: item.type,
                        value: item.value,
                        score: item.score,
                        target: LifeIndexScoreEngine.targets[item.type]
                    )
                }
            } else {
                Text("ui.noHealthData".localized)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Theme.Spacing.xl)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - How It Works View

    private var howItWorksView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            // Explanation
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Label("lifeindex.howScoringWorks".localized, systemImage: "sparkles")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.accentColor)

                Text("lifeindex.scoringExplanation".localized)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Importance levels
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Label("lifeindex.metricImportance".localized, systemImage: "chart.pie.fill")
                    .font(.system(.headline, design: .rounded, weight: .semibold))

                Text("lifeindex.metricImportanceHint".localized)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)

                ForEach(LifeIndexScoreEngine.weights.sorted(by: { $0.value > $1.value }), id: \.key) { type, weight in
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: type.icon)
                            .font(.system(size: Theme.IconSize.sm, weight: .semibold))
                            .foregroundStyle(metricColor(type))
                            .frame(width: Theme.IconFrame.sm)

                        Text(type.displayName)
                            .font(.system(.subheadline, design: .rounded))

                        Spacer()

                        // Visual weight indicator (dots)
                        HStack(spacing: 3) {
                            ForEach(0..<5) { i in
                                Circle()
                                    .fill(i < importanceLevel(weight) ? metricColor(type) : Color.gray.opacity(0.2))
                                    .frame(width: 8, height: 8)
                            }
                        }

                        Text(importanceLabel(weight))
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                            .foregroundStyle(Theme.secondaryText)
                            .frame(width: 50, alignment: .trailing)
                    }
                }
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Time awareness
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Label("lifeindex.smartTimeAdjustment".localized, systemImage: "clock.fill")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.sleep)

                Text("lifeindex.timeAdjustmentExplanation".localized)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Score levels
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Label("lifeindex.scoreLevels".localized, systemImage: "gauge.with.dots.needle.bottom.50percent")
                    .font(.system(.headline, design: .rounded, weight: .semibold))

                VStack(spacing: Theme.Spacing.sm) {
                    ScoreLevelRow(range: "80-100", label: "score.excellent".localized, color: .green, description: "score.excellentDesc".localized)
                    ScoreLevelRow(range: "60-79", label: "score.good".localized, color: .yellow, description: "score.goodDesc".localized)
                    ScoreLevelRow(range: "40-59", label: "score.fair".localized, color: .orange, description: "score.fairDesc".localized)
                    ScoreLevelRow(range: "0-39", label: "score.needsWork".localized, color: .red, description: "score.needsWorkDesc".localized)
                }
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.horizontal)
    }

    private func metricColor(_ type: HealthMetricType) -> Color {
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

    private func importanceLevel(_ weight: Double) -> Int {
        switch weight {
        case 0.20...: return 5
        case 0.15..<0.20: return 4
        case 0.10..<0.15: return 3
        case 0.05..<0.10: return 2
        default: return 1
        }
    }

    private func importanceLabel(_ weight: Double) -> String {
        switch weight {
        case 0.20...: return "importance.high".localized
        case 0.10..<0.20: return "importance.medium".localized
        default: return "importance.low".localized
        }
    }
}

// MARK: - Score Level Row

private struct ScoreLevelRow: View {
    let range: String
    let label: String
    let color: Color
    let description: String

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(range)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 50, alignment: .leading)

            Text(label)
                .font(.system(.subheadline, design: .rounded, weight: .medium))

            Spacer()

            Text(description)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
    }
}

// MARK: - Metric Score Row

private struct MetricScoreRow: View {
    let type: HealthMetricType
    let value: Double
    let score: Double
    let target: ClosedRange<Double>?

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
        case 0.8...1.0: return "metricStatus.excellent".localized
        case 0.6..<0.8: return "metricStatus.good".localized
        case 0.4..<0.6: return "metricStatus.fair".localized
        default: return "metricStatus.needsWork".localized
        }
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(metricColor.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: type.icon)
                        .font(.system(size: 16, weight: .semibold))
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

                // Score badge
                VStack(alignment: .trailing, spacing: 2) {
                    Text(statusText)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(scoreColor)

                    Text("\(Int(score * 100))%")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)

                    Capsule()
                        .fill(scoreColor)
                        .frame(width: geo.size.width * score, height: 6)
                }
            }
            .frame(height: 6)

            // Target hint
            if let target = target {
                HStack {
                    Image(systemName: "target")
                        .font(.system(size: 10))
                    Text("lifeindex.target".localized + " " + formatTarget(target))
                        .font(.system(.caption2, design: .rounded))
                }
                .foregroundStyle(Theme.secondaryText.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func formatTarget(_ range: ClosedRange<Double>) -> String {
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

// MARK: - Supporting Types

struct ScoreContributor {
    let name: String
    let percentage: Double
}

struct ContributorBadge: View {
    let icon: String
    let label: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: Theme.IconSize.sm, weight: .semibold))
                .foregroundStyle(color)

            Text(label)
                .font(.system(.caption, design: .rounded, weight: .medium))

            Text(detail)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}
