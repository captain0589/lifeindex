import SwiftUI
import Charts

struct SleepTabView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var isLoading = true
    @State private var selectedDay: DailyHealthSummary? = nil

    private var sleepMinutes: Double? {
        healthKitManager.todaySummary.metrics[.sleepDuration]
    }

    private var sleepStages: SleepStages? {
        healthKitManager.todaySummary.sleepStages
    }

    // Calculate sleep score (0-100) using SleepScoreEngine (aligned with Apple Health methodology)
    private var todaySleepScore: Int? {
        guard let stages = sleepStages else {
            // Fallback: use duration only if no stage data
            guard let minutes = sleepMinutes else { return nil }
            return SleepScoreEngine.calculateScore(sleepMinutes: minutes, stages: nil)
        }
        // Use actual asleep time (excluding awake time) with stage data
        return SleepScoreEngine.calculateScore(sleepMinutes: stages.totalAsleepMinutes, stages: stages)
    }

    private var sleepColor: Color {
        guard let score = todaySleepScore else { return Theme.secondaryText }
        switch score {
        case 80...100: return Theme.sleep
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    private var weeklySleepScores: [(day: String, date: Date, score: Int?, minutes: Double?)] {
        healthKitManager.weeklyData.map { summary in
            let stages = summary.sleepStages
            let minutes = stages?.totalAsleepMinutes ?? summary.metrics[.sleepDuration]
            guard let sleepMinutes = minutes else {
                return (day: summary.date.shortDayName, date: summary.date, score: nil, minutes: nil)
            }
            let score = SleepScoreEngine.calculateScore(sleepMinutes: sleepMinutes, stages: stages)
            return (day: summary.date.shortDayName, date: summary.date, score: score, minutes: sleepMinutes)
        }
    }

    private var yesterdaySleep: (score: Int, minutes: Double)? {
        healthKitManager.weeklyData
            .first(where: { $0.date.isYesterday })
            .flatMap { summary in
                let stages = summary.sleepStages
                let minutes = stages?.totalAsleepMinutes ?? summary.metrics[.sleepDuration]
                guard let sleepMinutes = minutes,
                      let score = SleepScoreEngine.calculateScore(sleepMinutes: sleepMinutes, stages: stages) else {
                    return nil
                }
                return (score: score, minutes: sleepMinutes)
            }
    }

    private var weeklyAvg: Int? {
        let scores = weeklySleepScores.compactMap { $0.score }
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / scores.count
    }

    private var weeklyAvgMinutes: Double? {
        let minutes = weeklySleepScores.compactMap { $0.minutes }
        guard !minutes.isEmpty else { return nil }
        return minutes.reduce(0, +) / Double(minutes.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // MARK: - Today's Sleep Section (Full Width - No Card)
                    if let stages = sleepStages, let score = todaySleepScore {
                        TodaySleepCard(
                            score: score,
                            color: sleepColor,
                            stages: stages
                        )
                    } else if sleepMinutes != nil, let score = todaySleepScore {
                        // Has sleep duration but no stages
                        TodaySleepCard(
                            score: score,
                            color: sleepColor,
                            stages: nil
                        )
                    } else {
                        // No sleep data
                        VStack(spacing: Theme.Spacing.lg) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(Theme.sleep.opacity(0.5))

                            Text("sleep.noData".localized)
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                                .foregroundStyle(.white)

                            Text("sleep.noDataDesc".localized)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, Theme.Spacing.xxl)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                    }

                    // MARK: - Weekly Sleep Chart
                    if !weeklySleepScores.isEmpty {
                        WeeklySleepChart(
                            scores: weeklySleepScores,
                            weeklyAvg: weeklyAvg,
                            color: sleepColor,
                            todayScore: todaySleepScore,
                            yesterdayScore: yesterdaySleep?.score
                        )
                        .padding(.horizontal)
                    }

                    // MARK: - Daily Sleep Scores
                    if !weeklySleepScores.isEmpty {
                        DailySleepScoresSection(
                            scores: weeklySleepScores,
                            weeklyData: healthKitManager.weeklyData,
                            color: sleepColor,
                            onSelect: { summary in
                                selectedDay = summary
                            }
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, Theme.Spacing.lg)
            }
            .background {
                // Full-screen night sky background
                GeometryReader { geo in
                    ZStack(alignment: .top) {
                        // Base background color
                        Theme.background
                            .ignoresSafeArea()

                        // Night sky image - full screen coverage with subtle bottom fade
                        Image("night_sky")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .overlay {
                                // Slight dark overlay for readability
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.15),
                                        Color.black.opacity(0.05),
                                        Color.black.opacity(0.1)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            }
                            .mask {
                                // Subtle fade at bottom
                                VStack(spacing: 0) {
                                    Rectangle()
                                        .fill(Color.white)
                                    LinearGradient(
                                        colors: [Color.white, Color.white.opacity(0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .frame(height: 60)
                                }
                            }
                            .ignoresSafeArea()
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationTitle("tab.sleep".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("tab.sleep".localized)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .refreshable {
                await loadData()
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
            .sheet(item: $selectedDay) { summary in
                SleepDayDetailSheet(summary: summary)
            }
        }
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        isLoading = true
        await healthKitManager.fetchTodaySummary()
        await healthKitManager.fetchWeeklyData()
        isLoading = false
    }
}

// MARK: - Today's Sleep Card (Full Width - No Card Style)

private struct TodaySleepCard: View {
    let score: Int
    let color: Color
    let stages: SleepStages?

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            // Centered score ring (smaller size)
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 14)
                    .frame(width: 120, height: 120)
                Circle()
                    .trim(from: 0, to: Double(score) / 100.0)
                    .stroke(color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                Text("\(score)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.top, Theme.Spacing.xl)

            // Centered duration
            if let stages = stages {
                Text(formatDuration(stages.totalAsleepMinutes))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
            }

            // Sleep stages breakdown
            if let stages = stages {
                SleepStagesBreakdown(stages: stages, color: color)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .frame(maxWidth: .infinity)
    }

    private func formatDuration(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if mins == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(mins)m"
    }
}

// MARK: - Sleep Stages Breakdown

private struct SleepStagesBreakdown: View {
    let stages: SleepStages
    let color: Color

    private var stageData: [(name: String, minutes: Double, percent: Int, color: Color)] {
        [
            ("REM", stages.remMinutes, stages.remPercent, .cyan),
            ("Core", stages.coreMinutes, stages.corePercent, .blue),
            ("Deep", stages.deepMinutes, stages.deepPercent, .purple),
            ("Awake", stages.awakeMinutes, stages.awakePercent, .orange)
        ].filter { $0.minutes > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("sleep.stages".localized)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("sleep.totalSleep".localized + ": " + formatDuration(stages.totalAsleepMinutes))
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }

            // Stacked bar
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(stageData, id: \.name) { stage in
                        let width = (stage.minutes / stages.totalMinutes) * geometry.size.width
                        RoundedRectangle(cornerRadius: 4)
                            .fill(stage.color)
                            .frame(width: max(4, width - 2))
                    }
                }
            }
            .frame(height: 12)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Legend - evenly distributed with bolder text
            HStack(spacing: 0) {
                ForEach(stageData, id: \.name) { stage in
                    HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                        Circle()
                            .fill(stage.color)
                            .frame(width: 10, height: 10)
                            .padding(.top, 3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stage.name)
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundStyle(.white)
                            Text("\(Int(stage.minutes))m")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                            Text("\(stage.percent)%")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))
    }

    private func formatDuration(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if mins == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(mins)m"
    }
}

// MARK: - Weekly Sleep Chart

private struct WeeklySleepChart: View {
    let scores: [(day: String, date: Date, score: Int?, minutes: Double?)]
    let weeklyAvg: Int?
    let color: Color
    let todayScore: Int?
    let yesterdayScore: Int?

    @State private var selectedDay: String? = nil

    private var selectedEntry: (day: String, date: Date, score: Int?, minutes: Double?)? {
        guard let day = selectedDay else { return nil }
        return scores.first { $0.day == day }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return Theme.sleep
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: Theme.IconSize.sm, weight: .semibold))
                        .foregroundStyle(Theme.sleep)
                    Text("sleep.weeklyOverview".localized)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                Spacer()
            }

            // Comparison tiles (moved from TodaySleepCard)
            HStack(spacing: Theme.Spacing.xl) {
                if let today = todayScore {
                    ComparisonTile(
                        label: "common.today".localized,
                        value: "\(today)",
                        color: scoreColor(today)
                    )
                }
                if let yesterday = yesterdayScore {
                    ComparisonTile(
                        label: "common.yesterday".localized,
                        value: "\(yesterday)",
                        color: scoreColor(yesterday).opacity(0.7)
                    )
                }
                if let avg = weeklyAvg {
                    ComparisonTile(
                        label: "sleep.7dayAvg".localized,
                        value: "\(avg)",
                        color: scoreColor(avg)
                    )
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)

            Chart(scores, id: \.date) { entry in
                if let score = entry.score {
                    LineMark(
                        x: .value("Day", entry.day),
                        y: .value("Score", score)
                    )
                    .foregroundStyle(Theme.sleep)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Day", entry.day),
                        y: .value("Score", score)
                    )
                    .foregroundStyle(selectedDay == entry.day ? Theme.sleep : scoreColor(score))
                    .symbolSize(selectedDay == entry.day ? 100 : 50)

                    AreaMark(
                        x: .value("Day", entry.day),
                        y: .value("Score", score)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.sleep.opacity(0.15), Theme.sleep.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    // Selection rule line
                    if selectedDay == entry.day {
                        RuleMark(x: .value("Day", entry.day))
                            .foregroundStyle(Theme.sleep.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 2]))
                    }
                }
            }
            .chartYScale(domain: 0...100)
            .chartXSelection(value: $selectedDay)
            .frame(height: 100)

            // Selected day detail
            if let entry = selectedEntry, let score = entry.score {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondaryText)
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                    if let minutes = entry.minutes {
                        Text("•")
                            .foregroundStyle(Theme.secondaryText)
                        Text(formatDuration(minutes))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Spacer()
                    Text("\(score)")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(scoreColor(score))
                    Text(SleepScoreEngine.label(for: score))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Theme.tertiaryBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
            }
        }
        .padding(Theme.Spacing.md)
        .background(.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))
    }

    private func formatDuration(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if mins == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(mins)m"
    }
}

// MARK: - Daily Sleep Scores Section

private struct DailySleepScoresSection: View {
    let scores: [(day: String, date: Date, score: Int?, minutes: Double?)]
    let weeklyData: [DailyHealthSummary]
    let color: Color
    let onSelect: (DailyHealthSummary) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("sleep.dailyScores".localized)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .padding(.bottom, Theme.Spacing.sm)

            ForEach(scores.reversed(), id: \.date) { entry in
                if let score = entry.score, let summary = weeklyData.first(where: { $0.date == entry.date }) {
                    Button {
                        onSelect(summary)
                    } label: {
                        HStack {
                            Text(entry.date.relativeDescription)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Theme.primaryText)
                                .frame(width: 90, alignment: .leading)

                            Spacer()

                            Text("\(score)/100")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(scoreColor(score))

                            Text(SleepScoreEngine.label(for: score))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.tertiaryText)
                        }
                    }
                    .buttonStyle(.plain)

                    if entry.date != scores.first?.date {
                        Divider()
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return Theme.sleep
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }
}


// MARK: - Sleep Day Detail Sheet

struct SleepDayDetailSheet: View, Identifiable {
    let id = UUID()
    let summary: DailyHealthSummary

    @Environment(\.dismiss) private var dismiss

    private var sleepMinutes: Double? {
        summary.sleepStages?.totalAsleepMinutes ?? summary.metrics[.sleepDuration]
    }

    private var sleepScore: Int? {
        let stages = summary.sleepStages
        let minutes = stages?.totalAsleepMinutes ?? summary.metrics[.sleepDuration]
        guard let sleepMinutes = minutes else { return nil }
        return SleepScoreEngine.calculateScore(sleepMinutes: sleepMinutes, stages: stages)
    }

    private var scoreColor: Color {
        guard let score = sleepScore else { return Theme.secondaryText }
        switch score {
        case 80...100: return Theme.sleep
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        return formatter.string(from: summary.date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Sleep section - same design as main TodaySleepCard (full width)
                    if let score = sleepScore {
                        VStack(spacing: Theme.Spacing.xl) {
                            // Date header inside the night sky
                            Text(formattedDate)
                                .font(.system(.headline, design: .rounded, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(.top, Theme.Spacing.xl)

                            // Centered score ring (smaller size, matching main page)
                            ZStack {
                                Circle()
                                    .stroke(scoreColor.opacity(0.2), lineWidth: 14)
                                    .frame(width: 120, height: 120)
                                Circle()
                                    .trim(from: 0, to: Double(score) / 100.0)
                                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                                    .frame(width: 120, height: 120)
                                    .rotationEffect(.degrees(-90))
                                Text("\(score)")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }

                            // Centered duration
                            if let minutes = sleepMinutes {
                                Text(formatDuration(minutes))
                                    .font(.system(.title2, design: .rounded, weight: .bold))
                                    .foregroundStyle(.white)
                            }

                            // Sleep stages breakdown
                            if let stages = summary.sleepStages {
                                SleepStagesBreakdown(stages: stages, color: scoreColor)
                            }
                        }
                        .padding(.bottom, Theme.Spacing.xl)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .background {
                // Full-screen night sky background
                GeometryReader { geo in
                    ZStack(alignment: .top) {
                        // Base background color
                        Theme.background
                            .ignoresSafeArea()

                        // Night sky image - full screen coverage with subtle bottom fade
                        Image("night_sky")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .overlay {
                                // Slight dark overlay for readability
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.15),
                                        Color.black.opacity(0.1),
                                        Color.black.opacity(0.2)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            }
                            .mask {
                                // Subtle fade at bottom
                                VStack(spacing: 0) {
                                    Rectangle()
                                        .fill(Color.white)
                                    LinearGradient(
                                        colors: [Color.white, Color.white.opacity(0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .frame(height: 60)
                                }
                            }
                            .ignoresSafeArea()
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("sleep.detail".localized)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("common.done".localized)
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private func formatDuration(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if mins == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(mins)m"
    }
}

