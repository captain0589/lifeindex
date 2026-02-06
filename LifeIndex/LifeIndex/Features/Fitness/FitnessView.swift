import SwiftUI
import Charts

struct FitnessView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var isLoading = true
    @State private var selectedWorkout: WorkoutData?
    @State private var showAllWorkouts = false
    @State private var showWorkoutCalendar = false
    @State private var selectedDate: Date = .now

    private let maxDisplayedWorkouts = 6

    private var weekDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let startOfWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: today)!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    private var stepsValue: Double {
        healthKitManager.todaySummary.metrics[.steps] ?? 0
    }

    private var caloriesValue: Double {
        healthKitManager.todaySummary.metrics[.activeCalories] ?? 0
    }

    private var exerciseValue: Double {
        healthKitManager.todaySummary.metrics[.workoutMinutes] ?? 0
    }

    private var caloriesGoal: Double {
        500 // Daily active calorie goal
    }

    private var displayedWorkouts: [WorkoutData] {
        Array(healthKitManager.recentWorkouts.prefix(maxDisplayedWorkouts))
    }

    private var hasMoreWorkouts: Bool {
        healthKitManager.recentWorkouts.count > maxDisplayedWorkouts
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // MARK: - Week Day Selector (same as Calories page)
                    FitnessWeekDaySelector(
                        dates: weekDates,
                        selectedDate: $selectedDate,
                        hasWorkoutForDate: { date in
                            healthKitManager.recentWorkouts.contains { workout in
                                Calendar.current.isDate(workout.startDate, inSameDayAs: date)
                            }
                        }
                    )
                    .padding(.horizontal)

                    // MARK: - Energy Burn Card
                    EnergyBurnCard(
                        burned: Int(caloriesValue),
                        goal: Int(caloriesGoal)
                    )
                    .padding(.horizontal)

                    // MARK: - Activity Section
                    FitnessActivityCard(
                        steps: stepsValue,
                        calories: caloriesValue,
                        exercise: exerciseValue
                    )
                    .padding(.horizontal)

                    // MARK: - Steps This Week
                    if !healthKitManager.weeklyData.isEmpty {
                        StepsWeeklyCard(data: healthKitManager.weeklyData)
                            .padding(.horizontal)
                    }

                    // MARK: - Recent Workouts
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        HStack {
                            Text("fitness.recentWorkouts".localized)
                                .font(Theme.title)

                            Spacer()

                            if !healthKitManager.recentWorkouts.isEmpty {
                                Text("\(healthKitManager.recentWorkouts.count) workouts")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                        }
                        .padding(.horizontal)

                        if healthKitManager.recentWorkouts.isEmpty {
                            VStack(spacing: Theme.Spacing.md) {
                                Image(systemName: "figure.run")
                                    .font(.system(size: Theme.FontSize.display))
                                    .foregroundStyle(Theme.secondaryText.opacity(0.5))
                                Text("fitness.noWorkouts".localized)
                                    .font(Theme.headline)
                                    .foregroundStyle(Theme.secondaryText)
                                Text("fitness.noWorkoutsDesc".localized)
                                    .font(Theme.caption)
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                        } else {
                            // Card-style workout display
                            VStack(spacing: Theme.Spacing.md) {
                                ForEach(displayedWorkouts) { workout in
                                    Button {
                                        selectedWorkout = workout
                                    } label: {
                                        WorkoutCard(workout: workout)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)

                            // View All Workouts button
                            if hasMoreWorkouts || healthKitManager.recentWorkouts.count > 0 {
                                Button {
                                    showAllWorkouts = true
                                } label: {
                                    HStack(spacing: Theme.Spacing.xs) {
                                        Image(systemName: "figure.run")
                                            .font(.system(size: 11))
                                        Text("fitness.viewAllWorkouts".localized)
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
                                .padding(.horizontal)
                            }
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(.vertical, Theme.Spacing.lg)
            }
            .pageBackground(showGradient: true, gradientHeight: 300)
            .navigationTitle("tab.fitness".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showWorkoutCalendar = true
                    } label: {
                        FitnessCalendarBadge(workoutCount: healthKitManager.recentWorkouts.count)
                    }
                }
            }
            .sheet(isPresented: $showWorkoutCalendar) {
                WorkoutCalendarView(workouts: healthKitManager.recentWorkouts)
            }
            .refreshable {
                await loadData()
            }
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .sheet(item: $selectedWorkout) { workout in
                WorkoutDetailSheet(workout: workout)
            }
            .sheet(isPresented: $showAllWorkouts) {
                AllWorkoutsSheet(workouts: healthKitManager.recentWorkouts) { workout in
                    showAllWorkouts = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedWorkout = workout
                    }
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

// MARK: - Workout Detail Sheet

struct WorkoutDetailSheet: View {
    let workout: WorkoutData

    @Environment(\.dismiss) private var dismiss

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: workout.startDate)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let start = formatter.string(from: workout.startDate)
        let end = formatter.string(from: workout.endDate)
        return "\(start) – \(end)"
    }

    private var paceString: String? {
        guard let distance = workout.distance, distance > 0 else { return nil }
        let paceMinutes = (workout.duration / 60) / (distance / 1000) // min/km
        let mins = Int(paceMinutes)
        let secs = Int((paceMinutes - Double(mins)) * 60)
        return String(format: "%d:%02d /km", mins, secs)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // Header with workout type
                    VStack(spacing: Theme.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(Theme.activity.opacity(0.15))
                                .frame(width: 80, height: 80)

                            Image(systemName: workout.icon)
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(Theme.activity)
                        }

                        Text(workout.displayName)
                            .font(.system(.title2, design: .rounded, weight: .bold))

                        Text(dateString)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)

                        Text(timeString)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    .padding(.top, Theme.Spacing.lg)

                    // Main stats
                    HStack(spacing: Theme.Spacing.lg) {
                        WorkoutStatBox(
                            icon: "clock.fill",
                            value: workout.formattedDuration,
                            label: "workout.duration".localized,
                            color: Theme.activity
                        )

                        if let calories = workout.calories {
                            WorkoutStatBox(
                                icon: "flame.fill",
                                value: "\(Int(calories))",
                                label: "food.calories".localized,
                                color: Theme.calories
                            )
                        }

                        if let distance = workout.distance, distance > 0 {
                            WorkoutStatBox(
                                icon: "figure.run",
                                value: String(format: "%.2f km", distance / 1000),
                                label: "workout.distance".localized,
                                color: Theme.steps
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Additional stats
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("workout.details".localized)
                            .font(.system(.headline, design: .rounded, weight: .bold))

                        VStack(spacing: 0) {
                            // Duration
                            WorkoutDetailRow(
                                icon: "clock",
                                label: "workout.duration".localized,
                                value: workout.formattedDuration,
                                color: Theme.activity
                            )

                            Divider().padding(.leading, 50)

                            // Calories
                            if let calories = workout.calories {
                                WorkoutDetailRow(
                                    icon: "flame.fill",
                                    label: "workout.activeCalories".localized,
                                    value: "\(Int(calories)) kcal",
                                    color: Theme.calories
                                )
                                Divider().padding(.leading, 50)
                            }

                            // Distance
                            if let distance = workout.distance, distance > 0 {
                                WorkoutDetailRow(
                                    icon: "map",
                                    label: "workout.distance".localized,
                                    value: String(format: "%.2f km", distance / 1000),
                                    color: Theme.steps
                                )
                                Divider().padding(.leading, 50)
                            }

                            // Pace
                            if let pace = paceString {
                                WorkoutDetailRow(
                                    icon: "speedometer",
                                    label: "workout.avgPace".localized,
                                    value: pace,
                                    color: .purple
                                )
                                Divider().padding(.leading, 50)
                            }

                            // Heart Rate
                            if let hr = workout.heartRateAvg {
                                WorkoutDetailRow(
                                    icon: "heart.fill",
                                    label: "workout.avgHeartRate".localized,
                                    value: "\(Int(hr)) bpm",
                                    color: Theme.heartRate
                                )
                            }
                        }
                        .background(Theme.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.horizontal)

                    // Workout intensity indicator
                    if let calories = workout.calories {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text("workout.intensity".localized)
                                .font(.system(.headline, design: .rounded, weight: .bold))

                            let intensity = workoutIntensity(calories: calories, duration: workout.duration)
                            HStack(spacing: Theme.Spacing.md) {
                                ZStack {
                                    Circle()
                                        .stroke(intensity.color.opacity(0.2), lineWidth: 8)
                                        .frame(width: 60, height: 60)

                                    Circle()
                                        .trim(from: 0, to: intensity.progress)
                                        .stroke(intensity.color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                        .frame(width: 60, height: 60)
                                        .rotationEffect(.degrees(-90))

                                    Image(systemName: intensity.icon)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(intensity.color)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(intensity.label)
                                        .font(.system(.headline, design: .rounded, weight: .semibold))
                                        .foregroundStyle(intensity.color)

                                    Text(intensity.description)
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(Theme.secondaryText)
                                }

                                Spacer()
                            }
                            .padding(Theme.Spacing.md)
                            .background(Theme.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("workout.details".localized)
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

    private func workoutIntensity(calories: Double, duration: TimeInterval) -> (label: String, description: String, color: Color, icon: String, progress: Double) {
        let caloriesPerMinute = calories / (duration / 60)

        switch caloriesPerMinute {
        case 12...:
            return ("workout.intensity.high".localized, "workout.intensity.high.desc".localized, .red, "flame.fill", 1.0)
        case 8..<12:
            return ("workout.intensity.moderate".localized, "workout.intensity.moderate.desc".localized, .orange, "bolt.fill", 0.75)
        case 5..<8:
            return ("workout.intensity.light".localized, "workout.intensity.light.desc".localized, .yellow, "figure.walk", 0.5)
        default:
            return ("workout.intensity.low".localized, "workout.intensity.low.desc".localized, .green, "leaf.fill", 0.25)
        }
    }
}

// MARK: - Workout Stat Box

private struct WorkoutStatBox: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
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

// MARK: - Workout Detail Row

private struct WorkoutDetailRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 30)

            Text(label)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.primaryText)

            Spacer()

            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.primaryText)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }
}

// MARK: - All Workouts Sheet

struct AllWorkoutsSheet: View {
    let workouts: [WorkoutData]
    let onSelectWorkout: (WorkoutData) -> Void

    @Environment(\.dismiss) private var dismiss

    private var groupedWorkouts: [(String, [WorkoutData])] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())

        let grouped = Dictionary(grouping: workouts) { workout -> String in
            let workoutYear = calendar.component(.year, from: workout.startDate)

            if calendar.isDateInToday(workout.startDate) {
                return "Today"
            } else if calendar.isDateInYesterday(workout.startDate) {
                return "Yesterday"
            } else if calendar.isDate(workout.startDate, equalTo: Date(), toGranularity: .weekOfYear) {
                return "This Week"
            } else if workoutYear == currentYear {
                // Current year - show month only
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM"
                return formatter.string(from: workout.startDate)
            } else {
                // Previous years - show month + year
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: workout.startDate)
            }
        }

        let order = ["Today", "Yesterday", "This Week"]

        // Sort: priority sections first, then by date (most recent first)
        return grouped.sorted { first, second in
            let firstIndex = order.firstIndex(of: first.key) ?? Int.max
            let secondIndex = order.firstIndex(of: second.key) ?? Int.max
            if firstIndex != secondIndex {
                return firstIndex < secondIndex
            }

            // For month sections, sort by the actual date of the first workout in each group
            if let firstWorkout = first.value.first, let secondWorkout = second.value.first {
                return firstWorkout.startDate > secondWorkout.startDate
            }

            return first.key > second.key
        }
    }

    // Get years that have workout data
    private var yearsWithData: [Int] {
        let calendar = Calendar.current
        let years = Set(workouts.map { calendar.component(.year, from: $0.startDate) })
        return years.sorted(by: >)
    }

    private var totalCalories: Double {
        workouts.compactMap { $0.calories }.reduce(0, +)
    }

    private var totalDuration: TimeInterval {
        workouts.map { $0.duration }.reduce(0, +)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // Summary stats
                    HStack(spacing: Theme.Spacing.lg) {
                        SummaryStatPill(
                            icon: "flame.fill",
                            value: "\(Int(totalCalories))",
                            label: "Total Calories",
                            color: Theme.calories
                        )

                        SummaryStatPill(
                            icon: "clock.fill",
                            value: formatTotalDuration(totalDuration),
                            label: "Total Time",
                            color: Theme.activity
                        )

                        SummaryStatPill(
                            icon: "figure.run",
                            value: "\(workouts.count)",
                            label: "Workouts",
                            color: Theme.steps
                        )
                    }
                    .padding(.horizontal)

                    // Grouped workouts
                    ForEach(groupedWorkouts, id: \.0) { section, sectionWorkouts in
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text(section)
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                ForEach(sectionWorkouts) { workout in
                                    Button {
                                        onSelectWorkout(workout)
                                    } label: {
                                        AllWorkoutsRow(workout: workout)
                                    }
                                    .buttonStyle(.plain)

                                    if workout.id != sectionWorkouts.last?.id {
                                        Divider()
                                            .padding(.leading, 60)
                                    }
                                }
                            }
                            .background(Theme.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("All Workouts")
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

    private func formatTotalDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Summary Stat Pill

private struct SummaryStatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)

            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))

            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - All Workouts Row

private struct AllWorkoutsRow: View {
    let workout: WorkoutData

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: workout.startDate)
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Theme.activity.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: workout.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.activity)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(workout.displayName)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.primaryText)

                Text(timeString)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(workout.formattedDuration)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)

                if let calories = workout.calories {
                    Text("\(Int(calories)) kcal")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.calories)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
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
                    Text("activity.stepsThisWeek".localized)
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
                    Text("common.today".localized)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                    Text("\(todaySteps.formatted())")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.steps)
                }

                Divider()
                    .frame(height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("common.weeklyAvg".localized)
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
                    .foregroundStyle(Theme.primaryText)

                Text(workout.startDate.relativeDescription)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(workout.formattedDuration)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)

                if let calories = workout.calories {
                    Text("\(Int(calories)) " + "units.kcal".localized)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.calories)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Workout Card (Card Style)

struct WorkoutCard: View {
    let workout: WorkoutData

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        return formatter.string(from: workout.startDate)
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: workout.startDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Top row: Icon, name, date/time, chevron
            HStack(spacing: Theme.Spacing.md) {
                // Workout icon in circle
                ZStack {
                    Circle()
                        .fill(Theme.activity.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: workout.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.activity)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.displayName)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.primaryText)

                    HStack(spacing: Theme.Spacing.xs) {
                        Text(formattedDate)
                        Text("•")
                            .foregroundStyle(Theme.tertiaryText)
                        Text(formattedTime)
                    }
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }

            // Stats row
            HStack(spacing: Theme.Spacing.lg) {
                // Duration
                WorkoutStatPill(
                    icon: "clock.fill",
                    value: workout.formattedDuration,
                    color: Theme.activity
                )

                // Calories
                if let calories = workout.calories {
                    WorkoutStatPill(
                        icon: "flame.fill",
                        value: "\(Int(calories)) kcal",
                        color: Theme.calories
                    )
                }

                // Distance (if available)
                if let distance = workout.distance, distance > 0 {
                    let km = distance / 1000
                    WorkoutStatPill(
                        icon: "figure.run",
                        value: String(format: "%.2f km", km),
                        color: .blue
                    )
                }

                // Heart rate (if available)
                if let avgHR = workout.heartRateAvg {
                    WorkoutStatPill(
                        icon: "heart.fill",
                        value: "\(Int(avgHR)) bpm",
                        color: .red
                    )
                }

                Spacer()
            }
        }
        .padding(Theme.Spacing.md)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
    }
}

// MARK: - Workout Stat Pill

private struct WorkoutStatPill: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(Theme.primaryText)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Fitness Activity Card

struct FitnessActivityCard: View {
    let steps: Double
    let calories: Double
    let exercise: Double

    private let stepsGoal: Double = 10000
    private let caloriesGoal: Double = 500
    private let exerciseGoal: Double = 30

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            // Header
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "flame.fill")
                    .font(.system(size: Theme.IconSize.sm, weight: .semibold))
                    .foregroundStyle(Theme.activity)
                Text("dashboard.activity".localized)
                    .font(.system(.headline, design: .rounded, weight: .bold))
            }

            HStack(spacing: Theme.Spacing.xl) {
                // Rings
                ZStack {
                    FitnessRing(progress: min(1.0, steps / stepsGoal), color: Theme.steps, size: 90, lineWidth: 10)
                    FitnessRing(progress: min(1.0, calories / caloriesGoal), color: Theme.calories, size: 66, lineWidth: 10)
                    FitnessRing(progress: min(1.0, exercise / exerciseGoal), color: Theme.activity, size: 42, lineWidth: 10)
                }
                .frame(width: 100, height: 100)

                // Legend
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    FitnessLegendRow(
                        color: Theme.steps,
                        icon: "figure.walk",
                        label: "activity.steps".localized,
                        value: "\(Int(steps))",
                        goal: "\(Int(stepsGoal))",
                        progress: steps / stepsGoal
                    )
                    FitnessLegendRow(
                        color: Theme.calories,
                        icon: "flame.fill",
                        label: "activity.calories".localized,
                        value: "\(Int(calories))",
                        goal: "\(Int(caloriesGoal)) " + "units.kcal".localized,
                        progress: calories / caloriesGoal
                    )
                    FitnessLegendRow(
                        color: Theme.activity,
                        icon: "figure.run",
                        label: "activity.exercise".localized,
                        value: "\(Int(exercise))",
                        goal: "\(Int(exerciseGoal)) " + "units.minutes".localized,
                        progress: exercise / exerciseGoal
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

struct FitnessRing: View {
    let progress: Double
    let color: Color
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

struct FitnessLegendRow: View {
    let color: Color
    let icon: String
    let label: String
    let value: String
    let goal: String
    let progress: Double

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(value)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.primaryText)
                    Text("/ \(goal)")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(color.opacity(0.15))
                        Rectangle()
                            .fill(color)
                            .frame(width: geo.size.width * min(progress, 1.0))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                .frame(height: 4)
            }
        }
    }
}

// MARK: - Energy Burn Card (Focus on active calories burned)

struct EnergyBurnCard: View {
    let burned: Int
    let goal: Int

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(1.0, Double(burned) / Double(goal))
    }

    private var progressColor: Color {
        if progress >= 1.0 {
            return .green
        } else if progress >= 0.7 {
            return Theme.activity
        } else {
            return Theme.activity.opacity(0.8)
        }
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Header with goal
            HStack {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: Theme.IconSize.sm, weight: .semibold))
                        .foregroundStyle(Theme.activity)
                    Text("fitness.energyBurned".localized)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                }
                Spacer()

                // Goal indicator
                Text("\(burned)/\(goal) " + "units.kcal".localized)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
            }

            // Main burned display
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(burned)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(progressColor)
                        .contentTransition(.numericText())
                    Text("units.kcal".localized + " " + "fitness.burnedToday".localized)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()

                // Fire ring animation
                ZStack {
                    Circle()
                        .stroke(Theme.activity.opacity(0.2), lineWidth: 8)
                        .frame(width: 70, height: 70)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(progressColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: progress)

                    Image(systemName: burned >= goal ? "flame.fill" : "flame")
                        .font(.system(size: 24))
                        .foregroundStyle(progressColor)
                }
            }

            // Goal reached celebration
            if burned >= goal {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.green)
                    Text("fitness.goalReached".localized)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.sm)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
            }
        }
        .cardStyle()
    }
}


// MARK: - Weekly Workout Summary

struct WeeklyWorkoutSummary: View {
    let weeklyData: [DailyHealthSummary]
    let recentWorkouts: [WorkoutData]

    private let calendar = Calendar.current

    private var weekDays: [(date: Date, hasWorkout: Bool, workoutMinutes: Double)] {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let startOfWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: today)!

        return (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek)!

            // Check if any workout exists on this day
            let hasWorkout = recentWorkouts.contains { workout in
                calendar.isDate(workout.startDate, inSameDayAs: date)
            }

            // Get workout minutes from weekly data
            let minutes = weeklyData.first { calendar.isDate($0.date, inSameDayAs: date) }?
                .metrics[.workoutMinutes] ?? 0

            return (date: date, hasWorkout: hasWorkout || minutes > 0, workoutMinutes: minutes)
        }
    }

    private var totalWorkoutDays: Int {
        weekDays.filter { $0.hasWorkout }.count
    }

    private var totalMinutes: Int {
        Int(weekDays.reduce(0) { $0 + $1.workoutMinutes })
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Header
            HStack {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: Theme.IconSize.sm, weight: .semibold))
                        .foregroundStyle(Theme.activity)
                    Text("fitness.weeklyWorkouts".localized)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                }

                Spacer()

                Text("\(totalWorkoutDays)/7 " + "fitness.days".localized)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(totalWorkoutDays >= 3 ? .green : Theme.secondaryText)
            }

            // 7-day grid
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(weekDays, id: \.date) { day in
                    WorkoutDayCell(
                        date: day.date,
                        hasWorkout: day.hasWorkout,
                        minutes: Int(day.workoutMinutes),
                        isToday: calendar.isDateInToday(day.date),
                        isFuture: day.date > Date()
                    )
                }
            }

            // Summary
            if totalMinutes > 0 {
                HStack {
                    Label("\(totalMinutes) " + "units.minutes".localized + " " + "fitness.thisWeek".localized, systemImage: "clock.fill")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - Workout Day Cell

private struct WorkoutDayCell: View {
    let date: Date
    let hasWorkout: Bool
    let minutes: Int
    let isToday: Bool
    let isFuture: Bool

    private let calendar = Calendar.current

    private var dayLetter: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(dayLetter)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(isFuture ? Theme.secondaryText.opacity(0.4) : Theme.secondaryText)

            ZStack {
                Circle()
                    .fill(hasWorkout ? Theme.activity : (isFuture ? Theme.tertiaryBackground.opacity(0.5) : Theme.tertiaryBackground))
                    .frame(width: 36, height: 36)

                if hasWorkout {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                } else if isToday {
                    Circle()
                        .stroke(Theme.activity, lineWidth: 2)
                        .frame(width: 36, height: 36)

                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.primaryText)
                } else {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(isFuture ? Theme.secondaryText.opacity(0.4) : Theme.secondaryText)
                }
            }

            if hasWorkout && minutes > 0 {
                Text("\(minutes)m")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.activity)
            } else {
                Text("")
                    .font(.system(.caption2, design: .rounded))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Fitness Week Day Selector (same as FoodView)

private struct FitnessWeekDaySelector: View {
    let dates: [Date]
    @Binding var selectedDate: Date
    let hasWorkoutForDate: (Date) -> Bool

    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "E"
        return f
    }()

    var body: some View {
        HStack(spacing: 0) {
            ForEach(dates, id: \.self) { date in
                let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                let isToday = Calendar.current.isDateInToday(date)
                let hasData = hasWorkoutForDate(date)
                let isFuture = date > Date()

                Button {
                    selectedDate = date
                } label: {
                    VStack(spacing: 6) {
                        Text(dayFormatter.string(from: date).prefix(1))
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                            .foregroundStyle(isFuture ? Theme.secondaryText.opacity(0.5) : Theme.secondaryText)

                        ZStack {
                            Circle()
                                .fill(isSelected ? Theme.activity : Color.clear)
                                .frame(width: 36, height: 36)

                            if hasData && !isSelected {
                                Circle()
                                    .stroke(Theme.activity, lineWidth: 2)
                                    .frame(width: 36, height: 36)
                            }

                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.system(.subheadline, design: .rounded, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(
                                    isSelected ? .white :
                                    isFuture ? Theme.secondaryText.opacity(0.5) :
                                    Theme.primaryText
                                )
                        }

                        // Today indicator dot
                        Circle()
                            .fill(isToday ? Theme.activity : Color.clear)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(maxWidth: .infinity)
                .disabled(isFuture)
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
    }
}

// MARK: - Fitness Calendar Badge

private struct FitnessCalendarBadge: View {
    let workoutCount: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.activity)

            if workoutCount > 0 {
                Text("\(workoutCount)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.primaryText)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

// MARK: - Workout Calendar View

struct WorkoutCalendarView: View {
    let workouts: [WorkoutData]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMonth: Date = Date()
    @State private var selectedWorkout: WorkoutData?

    private let calendar = Calendar.current

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }

    private var daysInMonth: [Date?] {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)

        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }

        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    private func workoutsFor(date: Date) -> [WorkoutData] {
        workouts.filter { calendar.isDate($0.startDate, inSameDayAs: date) }
    }

    private var totalWorkoutsThisMonth: Int {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        return workouts.filter { workout in
            workout.startDate >= startOfMonth && workout.startDate <= endOfMonth
        }.count
    }

    private var totalMinutesThisMonth: Int {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        return Int(workouts
            .filter { $0.startDate >= startOfMonth && $0.startDate <= endOfMonth }
            .reduce(0) { $0 + $1.duration / 60 }
        )
    }

    private var totalCaloriesThisMonth: Int {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        return Int(workouts
            .filter { $0.startDate >= startOfMonth && $0.startDate <= endOfMonth }
            .compactMap { $0.calories }
            .reduce(0, +)
        )
    }

    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // Month stats
                    HStack(spacing: Theme.Spacing.lg) {
                        WorkoutCalendarStat(
                            value: "\(totalWorkoutsThisMonth)",
                            label: "fitness.workouts".localized,
                            icon: "figure.run",
                            color: Theme.activity
                        )

                        WorkoutCalendarStat(
                            value: totalMinutesThisMonth > 60 ? "\(totalMinutesThisMonth / 60)h" : "\(totalMinutesThisMonth)m",
                            label: "fitness.totalTime".localized,
                            icon: "clock.fill",
                            color: .purple
                        )

                        WorkoutCalendarStat(
                            value: "\(totalCaloriesThisMonth)",
                            label: "fitness.caloriesBurned".localized,
                            icon: "flame.fill",
                            color: Theme.calories
                        )
                    }
                    .padding(.horizontal)

                    // Calendar
                    VStack(spacing: Theme.Spacing.md) {
                        // Month navigation
                        HStack {
                            Button {
                                withAnimation {
                                    selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.activity)
                            }

                            Spacer()

                            Text(monthYearString)
                                .font(.system(.headline, design: .rounded, weight: .bold))

                            Spacer()

                            Button {
                                let nextMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                                if nextMonth <= Date() {
                                    withAnimation {
                                        selectedMonth = nextMonth
                                    }
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(
                                        calendar.date(byAdding: .month, value: 1, to: selectedMonth)! > Date()
                                            ? Theme.secondaryText.opacity(0.3)
                                            : Theme.activity
                                    )
                            }
                            .disabled(calendar.date(byAdding: .month, value: 1, to: selectedMonth)! > Date())
                        }

                        // Weekday headers
                        HStack(spacing: 0) {
                            ForEach(weekdays, id: \.self) { day in
                                Text(day)
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundStyle(Theme.secondaryText)
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        // Calendar grid
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                            ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                                if let date = date {
                                    let dayWorkouts = workoutsFor(date: date)
                                    WorkoutCalendarDayCell(
                                        date: date,
                                        workouts: dayWorkouts,
                                        isToday: calendar.isDateInToday(date),
                                        isFuture: date > Date()
                                    ) {
                                        if let first = dayWorkouts.first {
                                            selectedWorkout = first
                                        }
                                    }
                                } else {
                                    Color.clear
                                        .frame(height: 44)
                                }
                            }
                        }
                    }
                    .padding(Theme.Spacing.lg)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal)

                    // Legend
                    HStack(spacing: Theme.Spacing.lg) {
                        LegendItem(color: Theme.activity, label: "fitness.workoutDay".localized)
                        LegendItem(color: Theme.tertiaryBackground, label: "fitness.restDay".localized)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("fitness.workoutCalendar".localized)
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
            .sheet(item: $selectedWorkout) { workout in
                WorkoutDetailSheet(workout: workout)
            }
        }
    }
}

// MARK: - Workout Calendar Stat

private struct WorkoutCalendarStat: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)

            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))

            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Workout Calendar Day Cell

private struct WorkoutCalendarDayCell: View {
    let date: Date
    let workouts: [WorkoutData]
    let isToday: Bool
    let isFuture: Bool
    let onTap: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if !workouts.isEmpty {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.activity, Theme.activity.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: workouts.first?.icon ?? "figure.run")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)

                } else if isToday {
                    Circle()
                        .fill(Theme.tertiaryBackground)

                    Circle()
                        .stroke(Theme.activity, lineWidth: 2)

                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.primaryText)
                } else {
                    Circle()
                        .fill(isFuture ? Theme.tertiaryBackground.opacity(0.3) : Theme.tertiaryBackground)

                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(isFuture ? Theme.secondaryText.opacity(0.4) : Theme.primaryText)
                }
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
        .disabled(workouts.isEmpty)
    }
}

// MARK: - Legend Item

private struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
    }
}
