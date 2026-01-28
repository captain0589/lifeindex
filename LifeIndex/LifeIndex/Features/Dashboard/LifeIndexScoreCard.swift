import SwiftUI

struct LifeIndexScoreCard: View {
    let score: Int
    let label: String
    let explanation: String
    let topContributor: ScoreContributor?
    let weakestArea: ScoreContributor?
    var breakdown: [(type: HealthMetricType, score: Double, value: Double)] = []

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
            Text("Today's LifeIndex")
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

            Button {
                showScoreSheet = true
            } label: {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                    Text("View Score Breakdown")
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    // Score header
                    VStack(spacing: Theme.Spacing.sm) {
                        Text("\(score)")
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundStyle(scoreColor)
                        Text(label)
                            .font(.system(.title3, design: .rounded, weight: .medium))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.lg)

                    // Your metrics today (most relevant — show first)
                    if !breakdown.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Label("Today's Metrics", systemImage: "chart.bar.fill")
                                .font(.system(.headline, design: .rounded, weight: .semibold))

                            ForEach(breakdown.sorted(by: { $0.score > $1.score }), id: \.type) { item in
                                HStack(spacing: Theme.Spacing.sm) {
                                    Image(systemName: item.type.icon)
                                        .font(.system(size: Theme.IconSize.sm, weight: .semibold))
                                        .foregroundStyle(metricColor(item.type))
                                        .frame(width: Theme.IconFrame.sm)

                                    Text(item.type.displayName)
                                        .font(.system(.subheadline, design: .rounded))

                                    Spacer()

                                    Text(HealthDataPoint(type: item.type, value: item.value, date: .now).formattedValue)
                                        .font(.system(.subheadline, design: .rounded, weight: .semibold))

                                    // Score indicator
                                    Circle()
                                        .fill(scoreIndicatorColor(item.score))
                                        .frame(width: 10, height: 10)

                                    Text("\(Int(item.score * 100))%")
                                        .font(.system(.caption, design: .rounded, weight: .bold))
                                        .foregroundStyle(scoreIndicatorColor(item.score))
                                        .frame(width: 36, alignment: .trailing)
                                }
                            }
                        }
                    }

                    // Weights breakdown
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Label("Metric Weights", systemImage: "chart.pie.fill")
                            .font(.system(.headline, design: .rounded, weight: .semibold))

                        ForEach(LifeIndexScoreEngine.weights.sorted(by: { $0.value > $1.value }), id: \.key) { type, weight in
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: type.icon)
                                    .font(.system(size: Theme.IconSize.sm, weight: .semibold))
                                    .foregroundStyle(metricColor(type))
                                    .frame(width: Theme.IconFrame.sm)

                                Text(type.displayName)
                                    .font(.system(.subheadline, design: .rounded))

                                Spacer()

                                Text("\(Int(weight * 100))%")
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundStyle(metricColor(type))
                            }
                        }
                    }

                    // Ideal ranges
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Label("Ideal Ranges", systemImage: "target")
                            .font(.system(.headline, design: .rounded, weight: .semibold))

                        ForEach(Array(LifeIndexScoreEngine.targets.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { type in
                            if let target = LifeIndexScoreEngine.targets[type] {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: Theme.IconSize.sm, weight: .semibold))
                                        .foregroundStyle(metricColor(type))
                                        .frame(width: Theme.IconFrame.sm)

                                    Text(type.displayName)
                                        .font(.system(.subheadline, design: .rounded))

                                    Spacer()

                                    Text(formatRange(target, type: type))
                                        .font(.system(.caption, design: .rounded, weight: .medium))
                                        .foregroundStyle(Theme.secondaryText)
                                }
                            }
                        }
                    }

                    // How it works
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Label("How Your Score Works", systemImage: "gearshape.2.fill")
                            .font(.system(.headline, design: .rounded, weight: .semibold))

                        Text("Your LifeIndex score is a weighted average of all your health metrics. Each metric is compared against an ideal range, and its score is weighted by importance.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Time awareness note
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Label("Time-Aware Scoring", systemImage: "clock.fill")
                            .font(.system(.headline, design: .rounded, weight: .semibold))

                        Text("Cumulative metrics (steps, calories, workouts, mindfulness) are scaled by time of day. Early in the morning, lower step counts won't penalize your score — targets adjust as the day progresses.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding()
            }
            .navigationTitle("Score Breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
            }
        }
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

    private func scoreIndicatorColor(_ score: Double) -> Color {
        switch score {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .yellow
        case 0.4..<0.6: return .orange
        default: return .red
        }
    }

    private func formatRange(_ range: ClosedRange<Double>, type: HealthMetricType) -> String {
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
