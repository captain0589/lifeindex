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
        isLoading = false
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
