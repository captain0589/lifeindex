import SwiftUI
import Charts

struct FitnessView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    RecoveryCard(
                        hrv: healthKitManager.todaySummary.metrics[.heartRateVariability],
                        restingHR: healthKitManager.todaySummary.metrics[.restingHeartRate],
                        sleepMinutes: healthKitManager.todaySummary.metrics[.sleepDuration]
                    )

                    // Steps This Week
                    if !healthKitManager.weeklyData.isEmpty {
                        StepsWeeklyCard(data: healthKitManager.weeklyData)
                            .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Workouts")
                            .font(Theme.title)
                            .padding(.horizontal)

                        if healthKitManager.recentWorkouts.isEmpty {
                            ContentUnavailableView(
                                "No Workouts",
                                systemImage: "figure.run",
                                description: Text("Your recent workouts will appear here.")
                            )
                            .frame(height: 200)
                        } else {
                            ForEach(healthKitManager.recentWorkouts) { workout in
                                WorkoutRow(workout: workout)
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Fitness")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await loadData()
            }
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
        }
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        isLoading = true
        await healthKitManager.fetchTodaySummary()
        await healthKitManager.fetchRecentWorkouts()
        await healthKitManager.fetchWeeklyData()
        isLoading = false
    }
}

// MARK: - Steps Weekly Card

struct StepsWeeklyCard: View {
    let data: [DailyHealthSummary]

    @State private var selectedDay: String?

    private func summaryFor(day: String?) -> DailyHealthSummary? {
        guard let day else { return nil }
        return data.first { $0.date.shortDayName == day }
    }

    private var weeklyAverage: Int {
        let stepsData = data.compactMap { $0.metrics[.steps] }
        guard !stepsData.isEmpty else { return 0 }
        return Int(stepsData.reduce(0, +) / Double(stepsData.count))
    }

    private var todaySteps: Int {
        guard let today = data.first(where: { Calendar.current.isDateInToday($0.date) }),
              let steps = today.metrics[.steps] else { return 0 }
        return Int(steps)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Header
            HStack {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: Theme.IconSize.sm, weight: .semibold))
                        .foregroundStyle(Theme.steps)
                    Text("Steps This Week")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                }

                Spacer()

                if let day = selectedDay, let summary = summaryFor(day: day),
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

            // Today's stats row
            HStack(spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                    Text("\(todaySteps.formatted())")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.steps)
                }

                Divider()
                    .frame(height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly Avg")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                    Text("\(weeklyAverage.formatted())")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()
            }
            .padding(.bottom, Theme.Spacing.xs)

            // Chart
            Chart(data) { summary in
                let dayName = summary.date.shortDayName
                if summary.metrics[.steps] != nil {
                    BarMark(
                        x: .value("Day", dayName),
                        y: .value("Steps", summary.metrics[.steps]!)
                    )
                    .foregroundStyle(selectedDay == dayName ? Theme.steps : Theme.steps.opacity(0.7))
                    .cornerRadius(4)
                } else {
                    BarMark(
                        x: .value("Day", dayName),
                        y: .value("Steps", 500)
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
                            Text("\(Int(v / 1000))k")
                                .font(.system(.caption2, design: .rounded))
                        }
                    }
                }
            }
        }
        .cardStyle()
    }
}

struct RecoveryCard: View {
    let hrv: Double?
    let restingHR: Double?
    let sleepMinutes: Double?

    private var recoveryScore: Int? {
        RecoveryScoreEngine.calculateScore(
            hrv: hrv,
            restingHeartRate: restingHR,
            sleepMinutes: sleepMinutes
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Recovery")
                .font(Theme.headline)
                .foregroundStyle(Theme.secondaryText)

            if let score = recoveryScore {
                Text("\(score)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(score >= 60 ? Theme.recovery : .orange)

                Text(RecoveryScoreEngine.label(for: score))
                    .font(Theme.body)
                    .foregroundStyle(Theme.secondaryText)

                if RecoveryScoreEngine.shouldRest(score: score) {
                    Label("Consider a rest day", systemImage: "moon.fill")
                        .font(Theme.caption)
                        .foregroundStyle(.orange)
                        .padding(.top, 4)
                }
            } else {
                Text("—")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)

                Text("Insufficient data")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            HStack(spacing: 20) {
                RecoveryMetric(label: "HRV", value: hrv, unit: "ms")
                RecoveryMetric(label: "RHR", value: restingHR, unit: "bpm")
                RecoveryMetric(label: "Sleep", value: sleepMinutes.map { $0 / 60.0 }, unit: "hrs")
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
        .padding(.horizontal)
    }
}

struct RecoveryMetric: View {
    let label: String
    let value: Double?
    let unit: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(Theme.caption)
                .foregroundStyle(Theme.secondaryText)

            if let value {
                Text(String(format: "%.0f", value))
                    .font(.system(.body, design: .rounded, weight: .semibold))
            } else {
                Text("—")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
            }

            Text(unit)
                .font(.system(size: 10))
                .foregroundStyle(Theme.secondaryText)
        }
    }
}

struct WorkoutRow: View {
    let workout: WorkoutData

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: workout.icon)
                .font(.title2)
                .foregroundStyle(Theme.activity)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.displayName)
                    .font(Theme.headline)

                Text(workout.startDate.relativeDescription)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(workout.formattedDuration)
                    .font(.system(.body, design: .rounded, weight: .semibold))

                if let calories = workout.calories {
                    Text("\(Int(calories)) kcal")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.calories)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
