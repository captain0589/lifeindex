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

    private var sleepScoreLabel: String {
        guard let score = todaySleepScore else { return "ui.noData".localized }
        return SleepScoreEngine.label(for: score) + " " + "tab.sleep".localized
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
                    // MARK: - Today's Sleep Card
                    if let stages = sleepStages, let score = todaySleepScore {
                        TodaySleepCard(
                            score: score,
                            label: sleepScoreLabel,
                            color: sleepColor,
                            stages: stages
                        )
                    } else if sleepMinutes != nil, let score = todaySleepScore {
                        // Has sleep duration but no stages
                        TodaySleepCard(
                            score: score,
                            label: sleepScoreLabel,
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
                                .foregroundStyle(Theme.primaryText)

                            Text("sleep.noDataDesc".localized)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, Theme.Spacing.xxl)
                        .frame(maxWidth: .infinity)
                        .cardStyle()
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
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, Theme.Spacing.lg)
            }
            .pageBackground(showGradient: true, gradientHeight: 300)
            .navigationTitle("tab.sleep".localized)
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await loadData()
            }
            .overlay {
                if isLoading {
                    ProgressView()
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

// MARK: - Today's Sleep Card

private struct TodaySleepCard: View {
    let score: Int
    let label: String
    let color: Color
    let stages: SleepStages?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            SectionHeader(title: "tab.sleep".localized, icon: "moon.zzz.fill", color: Theme.sleep)

            // Score ring + label
            HStack(spacing: Theme.Spacing.lg) {
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.2), lineWidth: 10)
                        .frame(width: 70, height: 70)
                    Circle()
                        .trim(from: 0, to: Double(score) / 100.0)
                        .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                    Text("\(score)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(label)
                        .font(Theme.body)
                        .foregroundStyle(Theme.secondaryText)

                    if let stages = stages {
                        Text(formatDuration(stages.totalAsleepMinutes))
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.primaryText)
                    }
                }
                Spacer()
            }

            // Sleep stages breakdown
            if let stages = stages {
                SleepStagesBreakdown(stages: stages, color: color)
            }
        }
        .cardStyle()
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
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                Spacer()
                Text("sleep.total".localized + ": " + formatDuration(stages.totalMinutes))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
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

            // Legend - evenly distributed
            HStack(spacing: 0) {
                ForEach(stageData, id: \.name) { stage in
                    HStack(spacing: Theme.Spacing.xs) {
                        Circle()
                            .fill(stage.color)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(stage.name)
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                                .foregroundStyle(Theme.secondaryText)
                            Text("\(Int(stage.minutes))m")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.tertiaryBackground.opacity(0.5))
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
        .cardStyle()
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

            ForEach(scores, id: \.date) { entry in
                if let score = entry.score, let summary = weeklyData.first(where: { $0.date == entry.date }) {
                    Button {
                        onSelect(summary)
                    } label: {
                        HStack {
                            Text(entry.day)
                                .font(.system(.body, design: .rounded))
                                .frame(width: 40, alignment: .leading)

                            if let minutes = entry.minutes {
                                Text(formatDuration(minutes))
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                            }

                            Spacer()

                            Text("\(score)")
                                .font(.system(.body, design: .rounded, weight: .bold))
                                .foregroundStyle(scoreColor(score))

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .padding(.vertical, Theme.Spacing.xs)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .cardStyle()
    }

    private func formatDuration(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if mins == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(mins)m"
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
        summary.metrics[.sleepDuration]
    }

    private var sleepScore: Int? {
        let stages = summary.sleepStages
        let minutes = stages?.totalAsleepMinutes ?? sleepMinutes
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Date header
                    Text(summary.date.formatted(date: .complete, time: .omitted))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.primaryText)

                    // Score card
                    if let score = sleepScore {
                        HStack(spacing: Theme.Spacing.lg) {
                            ZStack {
                                Circle()
                                    .stroke(scoreColor.opacity(0.2), lineWidth: 8)
                                    .frame(width: 60, height: 60)
                                Circle()
                                    .trim(from: 0, to: Double(score) / 100.0)
                                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                    .frame(width: 60, height: 60)
                                    .rotationEffect(.degrees(-90))
                                Text("\(score)")
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .foregroundStyle(scoreColor)
                            }

                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text("sleep.sleepScore".localized)
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                                if let minutes = sleepMinutes {
                                    Text(formatDuration(minutes))
                                        .font(.system(.headline, design: .rounded, weight: .semibold))
                                }
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Theme.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg))
                    }

                    // Sleep stages if available
                    if let stages = summary.sleepStages {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text("sleep.stages".localized)
                                .font(.system(.headline, design: .rounded, weight: .semibold))

                            SleepStageRow(name: "sleep.rem".localized, minutes: stages.remMinutes, percent: stages.remPercent, color: .cyan)
                            SleepStageRow(name: "sleep.core".localized, minutes: stages.coreMinutes, percent: stages.corePercent, color: .blue)
                            SleepStageRow(name: "sleep.deep".localized, minutes: stages.deepMinutes, percent: stages.deepPercent, color: .purple)
                            SleepStageRow(name: "sleep.awake".localized, minutes: stages.awakeMinutes, percent: stages.awakePercent, color: .orange)

                            Divider()

                            HStack {
                                Text("sleep.totalSleep".localized)
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                Spacer()
                                Text(formatDuration(stages.totalAsleepMinutes))
                                    .font(.system(.body, design: .rounded, weight: .bold))
                                    .foregroundStyle(Theme.sleep)
                            }
                        }
                        .padding()
                        .background(Theme.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg))
                    }
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Sleep Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.done".localized) {
                        dismiss()
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

private struct SleepStageRow: View {
    let name: String
    let minutes: Double
    let percent: Int
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(name)
                .font(.system(.body, design: .rounded))
            Spacer()
            Text("\(Int(minutes))m")
                .font(.system(.body, design: .rounded, weight: .medium))
            Text("(\(percent)%)")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
    }
}
