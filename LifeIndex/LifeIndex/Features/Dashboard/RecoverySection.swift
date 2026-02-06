import SwiftUI
import Charts

struct RecoverySection: View {
    let todayScore: Int
    let todayLabel: String
    let weeklyData: [DailyHealthSummary]

    private var color: Color {
        switch todayScore {
        case 70...100: return Theme.recovery
        case 40..<70: return .yellow
        default: return .orange
        }
    }

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

    @State private var selectedDay: DailyHealthSummary? = nil
    @State private var selectedChartDay: String? = nil

    private var selectedChartEntry: (day: String, date: Date, score: Int?)? {
        guard let day = selectedChartDay else { return nil }
        return weeklyRecoveryScores.first { $0.day == day }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            SectionHeader(title: "dashboard.recovery".localized, icon: "arrow.counterclockwise.circle.fill", color: Theme.recovery)

            // Today's recovery
            HStack(spacing: Theme.Spacing.lg) {
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.2), lineWidth: 10)
                        .frame(width: 70, height: 70)
                    Circle()
                        .trim(from: 0, to: Double(todayScore) / 100.0)
                        .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                    Text("\(todayScore)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(todayLabel)
                        .font(Theme.body)
                        .foregroundStyle(Theme.secondaryText)
                    if RecoveryScoreEngine.shouldRest(score: todayScore) {
                        Label("recovery.restRecommended".localized, systemImage: "moon.fill")
                            .font(Theme.caption)
                            .foregroundStyle(.orange)
                    }
                }
                Spacer()
            }

            // Comparison tiles
            HStack(spacing: Theme.Spacing.xl) {
                ComparisonTile(
                    label: "common.today".localized,
                    value: "\(todayScore)",
                    color: color
                )
                if let yesterday = yesterdayRecovery {
                    ComparisonTile(
                        label: "common.yesterday".localized,
                        value: "\(yesterday)",
                        color: color.opacity(0.7)
                    )
                }
                if let avg = weeklyAvg {
                    ComparisonTile(
                        label: "sleep.7dayAvg".localized,
                        value: "\(avg)",
                        color: color
                    )
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)

            // Weekly chart
            if !weeklyRecoveryScores.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: Theme.IconSize.sm, weight: .semibold))
                                .foregroundStyle(Theme.recovery)
                            Text("ui.thisWeek".localized)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        }
                        Spacer()
                        if let avg = weeklyAvg {
                            HStack(spacing: Theme.Spacing.xs) {
                                Text("ui.avg".localized)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                                Text("\(avg)")
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundStyle(color)
                            }
                        }
                    }
                    Chart(weeklyRecoveryScores, id: \.date) { entry in
                        if let score = entry.score {
                            LineMark(
                                x: .value("Day", entry.day),
                                y: .value("Score", score)
                            )
                            .foregroundStyle(Theme.recovery)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Day", entry.day),
                                y: .value("Score", score)
                            )
                            .foregroundStyle(selectedChartDay == entry.day ? Theme.recovery : color)
                            .symbolSize(selectedChartDay == entry.day ? 100 : 50)

                            AreaMark(
                                x: .value("Day", entry.day),
                                y: .value("Score", score)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Theme.recovery.opacity(0.15), Theme.recovery.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)

                            // Selection rule line
                            if selectedChartDay == entry.day {
                                RuleMark(x: .value("Day", entry.day))
                                    .foregroundStyle(Theme.recovery.opacity(0.3))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 2]))
                            }
                        }
                    }
                    .chartYScale(domain: 0...100)
                    .chartXSelection(value: $selectedChartDay)
                    .frame(height: 100)

                    // Selected day detail
                    if let entry = selectedChartEntry, let score = entry.score {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.secondaryText)
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                            Spacer()
                            Text("\(score)")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(color)
                            Text(RecoveryScoreEngine.label(for: score))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Theme.tertiaryBackground.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
                    }
                }
            }

            // Daily Recovery Scores Section
            if !weeklyRecoveryScores.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("recovery.dailyScores".localized)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .padding(.bottom, Theme.Spacing.sm)
                    ForEach(weeklyRecoveryScores, id: \.date) { entry in
                        if let score = entry.score, let summary = weeklyData.first(where: { $0.date == entry.date }) {
                            Button {
                                selectedDay = summary
                            } label: {
                                HStack {
                                    Text(entry.day)
                                        .font(.system(.body, design: .rounded))
                                        .frame(width: 40, alignment: .leading)
                                    Spacer()
                                    Text("\(score)")
                                        .font(.system(.body, design: .rounded, weight: .bold))
                                        .foregroundStyle(color)
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
        }
        .cardStyle()
        .sheet(item: $selectedDay) { summary in
            RecoveryDayDetailSheet(summary: summary)
        }
    }
}

// MARK: - Recovery Day Detail Sheet
struct RecoveryDayDetailSheet: View, Identifiable {
    let id = UUID()
    let summary: DailyHealthSummary

    @Environment(\.dismiss) private var dismiss

    private var hrv: Double? { summary.metrics[.heartRateVariability] }
    private var rhr: Double? { summary.metrics[.restingHeartRate] }
    private var sleep: Double? { summary.metrics[.sleepDuration] }

    private var recoveryScore: Int? {
        RecoveryScoreEngine.calculateScore(hrv: hrv, restingHeartRate: rhr, sleepMinutes: sleep)
    }

    private var scoreColor: Color {
        guard let score = recoveryScore else { return Theme.secondaryText }
        switch score {
        case 70...100: return Theme.recovery
        case 40..<70: return .yellow
        default: return .orange
        }
    }

    private var scoreLabel: String {
        guard let score = recoveryScore else { return "No Data" }
        switch score {
        case 80...100: return "recovery.excellent".localized
        case 60..<80: return "recovery.good".localized
        case 40..<60: return "recovery.fair".localized
        default: return "recovery.poor".localized
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
                    if let score = recoveryScore {
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
                                Text(scoreLabel)
                                    .font(.system(.headline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(scoreColor)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Theme.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg))
                    }

                    // Metrics breakdown
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("recovery.metrics".localized)
                            .font(.system(.headline, design: .rounded, weight: .semibold))

                        // HRV
                        RecoveryMetricRow(
                            icon: "waveform.path.ecg",
                            name: "heart.hrv".localized,
                            value: hrv.map { "\(Int($0))" } ?? "--",
                            unit: "units.ms".localized,
                            color: .purple,
                            status: hrvStatus
                        )

                        // Resting Heart Rate
                        RecoveryMetricRow(
                            icon: "heart.fill",
                            name: "heart.restingHR".localized,
                            value: rhr.map { "\(Int($0))" } ?? "--",
                            unit: "units.bpm".localized,
                            color: .red,
                            status: rhrStatus
                        )

                        // Sleep Duration
                        RecoveryMetricRow(
                            icon: "moon.zzz.fill",
                            name: "sleep.timeAsleep".localized,
                            value: sleep.map { formatDuration($0) } ?? "--",
                            unit: "",
                            color: Theme.sleep,
                            status: sleepStatus
                        )
                    }
                    .padding()
                    .background(Theme.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg))

                    // Recommendation
                    if let score = recoveryScore {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("ui.recommendation".localized)
                                .font(.system(.headline, design: .rounded, weight: .semibold))

                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: recommendationIcon(for: score))
                                    .font(.system(size: 20))
                                    .foregroundStyle(scoreColor)
                                Text(recommendationText(for: score))
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
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
            .navigationTitle("Recovery Detail")
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

    private var hrvStatus: String {
        guard let hrv = hrv else { return "" }
        if hrv >= 50 { return "Good" }
        if hrv >= 30 { return "Fair" }
        return "Low"
    }

    private var rhrStatus: String {
        guard let rhr = rhr else { return "" }
        if rhr <= 60 { return "Excellent" }
        if rhr <= 70 { return "Good" }
        return "Elevated"
    }

    private var sleepStatus: String {
        guard let sleep = sleep else { return "" }
        if sleep >= 420 { return "Good" } // 7+ hours
        if sleep >= 360 { return "Fair" } // 6+ hours
        return "Insufficient"
    }

    private func formatDuration(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if mins == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(mins)m"
    }

    private func recommendationIcon(for score: Int) -> String {
        switch score {
        case 80...100: return "figure.run"
        case 60..<80: return "figure.walk"
        case 40..<60: return "figure.cooldown"
        default: return "moon.fill"
        }
    }

    private func recommendationText(for score: Int) -> String {
        switch score {
        case 80...100: return "Great recovery! You're ready for high-intensity training."
        case 60..<80: return "Good recovery. Moderate activity is recommended."
        case 40..<60: return "Fair recovery. Consider lighter workouts today."
        default: return "Low recovery. Rest and recovery activities are recommended."
        }
    }
}

// MARK: - Recovery Metric Row

private struct RecoveryMetricRow: View {
    let icon: String
    let name: String
    let value: String
    let unit: String
    let color: Color
    let status: String

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 24)

            Text(name)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.primaryText)

            Spacer()

            if !status.isEmpty {
                Text(status)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(Theme.tertiaryBackground)
                    .clipShape(Capsule())
            }

            HStack(spacing: 2) {
                Text(value)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(color)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
        }
    }
}
