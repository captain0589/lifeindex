import SwiftUI
import Charts

struct FoodView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var nutritionManager: NutritionManager?
    @State private var foodLogViewModel: FoodLogViewModel?
    @State private var showFoodLog = false
    @State private var todayLogs: [FoodLog] = []
    @State private var consumedCalories: Double = 0
    @State private var selectedDate: Date = .now
    @State private var currentStreak: Int = 0
    @State private var showStreakView = false

    // Profile-based goal
    @AppStorage("dailyCalorieGoal") private var dailyCalorieGoal: Int = 2000
    @AppStorage("userAge") private var userAge: Int = 25
    @AppStorage("userWeightKg") private var userWeightKg: Double = 70
    @AppStorage("userHeightCm") private var userHeightCm: Double = 170
    @AppStorage("userGender") private var userGender: Int = 0
    @AppStorage("userActivityLevel") private var userActivityLevel: Int = 2
    @AppStorage("userGoalType") private var userGoalType: Int = 1

    private var calculatedGoal: Int {
        NutritionEngine.calculateDailyGoal(
            weightKg: userWeightKg,
            heightCm: userHeightCm,
            age: userAge,
            isMale: userGender == 0,
            activityLevel: userActivityLevel,
            goalType: userGoalType
        )
    }

    private var burnedCalories: Double {
        healthKitManager.todaySummary.value(for: .activeCalories) ?? 0
    }

    private var remaining: Int {
        dailyCalorieGoal - Int(consumedCalories)
    }

    private var progress: Double {
        guard dailyCalorieGoal > 0 else { return 0 }
        return min(1.0, consumedCalories / Double(dailyCalorieGoal))
    }

    // Macro totals from today's logs
    private var todayProtein: Double {
        todayLogs.reduce(0) { $0 + $1.protein }
    }
    private var todayCarbs: Double {
        todayLogs.reduce(0) { $0 + $1.carbs }
    }
    private var todayFat: Double {
        todayLogs.reduce(0) { $0 + $1.fat }
    }

    private var macroTargets: NutritionEngine.MacroTargets {
        NutritionEngine.macroTargets(calorieGoal: dailyCalorieGoal)
    }

    private var weekDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let startOfWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: today)!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // MARK: - Week Day Selector
                    WeekDaySelector(
                        dates: weekDates,
                        selectedDate: $selectedDate,
                        hasDataForDate: { date in
                            let logs = CoreDataStack.shared.fetchFoodLogs(for: date)
                            return !logs.isEmpty
                        }
                    )
                    .padding(.horizontal)

                    // MARK: - Goal Settings (moved up)
                    GoalSettingsCard(
                        dailyGoal: $dailyCalorieGoal,
                        calculatedGoal: calculatedGoal
                    )
                    .padding(.horizontal)

                    // MARK: - Calorie Card
                    VStack(spacing: Theme.Spacing.lg) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline, spacing: 0) {
                                    Text("\(Int(consumedCalories))")
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                    Text("/\(dailyCalorieGoal)")
                                        .font(.system(size: 20, weight: .medium, design: .rounded))
                                        .foregroundStyle(Theme.secondaryText)
                                }
                                Text("Calories eaten")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                            }

                            Spacer()

                            // Calorie ring
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)

                                Circle()
                                    .trim(from: 0, to: progress)
                                    .stroke(
                                        Theme.calories,
                                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))
                                    .animation(.easeInOut(duration: 0.5), value: progress)

                                Image(systemName: "flame.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Theme.calories)
                            }
                            .frame(width: 60, height: 60)
                        }
                    }
                    .padding(Theme.Spacing.lg)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal)

                    // MARK: - Macro Cards
                    HStack(spacing: Theme.Spacing.md) {
                        MacroCard(
                            label: "Protein",
                            current: todayProtein,
                            target: Double(macroTargets.protein),
                            unit: "g",
                            color: .red.opacity(0.8),
                            icon: "p.circle.fill"
                        )

                        MacroCard(
                            label: "Carbs",
                            current: todayCarbs,
                            target: Double(macroTargets.carbs),
                            unit: "g",
                            color: .orange,
                            icon: "c.circle.fill"
                        )

                        MacroCard(
                            label: "Fat",
                            current: todayFat,
                            target: Double(macroTargets.fat),
                            unit: "g",
                            color: .blue,
                            icon: "f.circle.fill"
                        )
                    }
                    .padding(.horizontal)

                    // MARK: - Today's Meals / Diary
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        HStack {
                            Text("Diary")
                                .font(.system(.title3, design: .rounded, weight: .bold))
                            Spacer()
                            if !todayLogs.isEmpty {
                                let totalCal = todayLogs.reduce(0) { $0 + Int($1.calories) }
                                Text("\(totalCal) kcal")
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundStyle(Theme.calories)
                            }
                        }

                        if todayLogs.isEmpty {
                            VStack(spacing: Theme.Spacing.md) {
                                Image(systemName: "fork.knife.circle")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Theme.secondaryText.opacity(0.5))
                                Text("No meals logged")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.xl)
                        } else {
                            // Show all food items without meal type headers
                            ForEach(todayLogs) { log in
                                FoodItemRow(log: log)
                            }
                        }
                    }
                    .padding(Theme.Spacing.lg)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal)

                    // MARK: - Calories Burned This Week (moved to bottom)
                    if !healthKitManager.weeklyData.isEmpty {
                        CaloriesBurnedWeeklyCard(data: healthKitManager.weeklyData)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 80)
                }
                .padding(.top, Theme.Spacing.md)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Calories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showStreakView = true
                    } label: {
                        StreakBadge(streak: currentStreak)
                    }
                }
            }
            .sheet(isPresented: $showStreakView) {
                StreakView()
            }
            .overlay(alignment: .bottomTrailing) {
                // Floating Action Button - equal margin from right and bottom
                Button {
                    showFoodLog = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Theme.calories)
                        .clipShape(Circle())
                        .shadow(color: Theme.calories.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .padding(24)
            }
            .sheet(isPresented: $showFoodLog, onDismiss: {
                refreshData()
                currentStreak = StreakManager.calculateCurrentStreak()
            }) {
                if let foodLogVM = foodLogViewModel {
                    FoodLogSheet(viewModel: foodLogVM, isPresented: $showFoodLog)
                }
            }
        }
        .task {
            if nutritionManager == nil {
                let nm = NutritionManager(healthStore: healthKitManager.healthStore)
                nutritionManager = nm
                foodLogViewModel = FoodLogViewModel(nutritionManager: nm)
            }
            refreshData()
            currentStreak = StreakManager.calculateCurrentStreak()
            if let nm = nutritionManager {
                do {
                    try await nm.requestAuthorization()
                } catch {}
                await nm.fetchTodayConsumedCalories()
                consumedCalories = nm.todayConsumedCalories
            }
            // Fetch weekly data for the calories burned chart
            await healthKitManager.fetchWeeklyData()
        }
        .onChange(of: selectedDate) { _, newDate in
            todayLogs = CoreDataStack.shared.fetchFoodLogs(for: newDate)
            // Recalculate consumed calories for selected date
            let logsCalories = todayLogs.reduce(0) { $0 + Int($1.calories) }
            consumedCalories = Double(logsCalories)
        }
    }

    private func refreshData() {
        todayLogs = CoreDataStack.shared.fetchFoodLogs(for: selectedDate)
        if let nm = nutritionManager {
            Task {
                await nm.fetchTodayConsumedCalories()
                if Calendar.current.isDateInToday(selectedDate) {
                    consumedCalories = nm.todayConsumedCalories
                } else {
                    let logsCalories = todayLogs.reduce(0) { $0 + Int($1.calories) }
                    consumedCalories = Double(logsCalories)
                }
            }
        }
    }
}

// MARK: - Week Day Selector

private struct WeekDaySelector: View {
    let dates: [Date]
    @Binding var selectedDate: Date
    let hasDataForDate: (Date) -> Bool

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
                let hasData = hasDataForDate(date)
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
                                .fill(isSelected ? Theme.calories : Color.clear)
                                .frame(width: 36, height: 36)

                            if hasData && !isSelected {
                                Circle()
                                    .stroke(Theme.calories, lineWidth: 2)
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
                            .fill(isToday ? Theme.calories : Color.clear)
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

// MARK: - Macro Card

private struct MacroCard: View {
    let label: String
    let current: Double
    let target: Double
    let unit: String
    let color: Color
    let icon: String

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(1.0, current / target)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // Value display
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(Int(current))")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Text("/\(Int(target))\(unit)")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }

            Text("\(label) eaten")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Theme.secondaryText)

            // Ring
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.4), value: progress)

                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
            }
            .frame(width: 44, height: 44)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Goal Settings Card

private struct GoalSettingsCard: View {
    @Binding var dailyGoal: Int
    let calculatedGoal: Int
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "target")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.calories)
                    Text("Daily Goal: \(dailyGoal) kcal")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(Theme.primaryText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(Theme.Spacing.md)
            }

            if isExpanded {
                Divider()
                    .padding(.horizontal)

                VStack(spacing: Theme.Spacing.md) {
                    HStack {
                        Text("Calorie Goal")
                            .font(.system(.subheadline, design: .rounded))
                        Spacer()
                        HStack(spacing: Theme.Spacing.xs) {
                            TextField("", value: $dailyGoal, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .frame(width: 60)
                            Text("kcal")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }

                    Button {
                        dailyGoal = calculatedGoal
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Use Recommended (\(calculatedGoal) kcal)")
                        }
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(Theme.calories)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Theme.calories.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(Theme.Spacing.md)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Meal Section

private struct MealSection: View {
    let mealType: MealType
    let logs: [FoodLog]

    private var totalCalories: Int {
        logs.reduce(0) { $0 + Int($1.calories) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Meal type header
            HStack {
                Image(systemName: mealType.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.calories)

                Text(mealType.displayName)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))

                Spacer()

                Text("\(totalCalories) kcal")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(.bottom, Theme.Spacing.xs)

            // Food items - now with card styling
            ForEach(logs) { log in
                FoodItemRow(log: log)
            }
        }
        .padding(.bottom, Theme.Spacing.sm)
    }
}

// MARK: - Food Item Row

private struct FoodItemRow: View {
    let log: FoodLog
    @State private var thumbnail: UIImage?

    private let imageSize: CGFloat = 72

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Thumbnail - larger size for better visibility
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageSize, height: imageSize)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else if log.imageFileName != nil {
                // Placeholder while loading
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.tertiaryBackground)
                    .frame(width: imageSize, height: imageSize)
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
            } else {
                // Default food icon when no image
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.calories.opacity(0.1))
                    .frame(width: imageSize, height: imageSize)
                    .overlay {
                        Image(systemName: log.mealTypeEnum.icon)
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.calories)
                    }
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Top row: Name + Time
                HStack {
                    Text(log.name ?? "Food")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .lineLimit(1)

                    Spacer()

                    if let date = log.date {
                        Text(date.formatted(date: .omitted, time: .shortened))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }

                // Calories row
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.calories)
                    Text("\(log.calories) kcal")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(Theme.calories)
                }

                // Macros row (if available)
                if log.protein > 0 || log.carbs > 0 || log.fat > 0 {
                    HStack(spacing: Theme.Spacing.md) {
                        MacroLabel(icon: "bolt.fill", value: Int(log.protein), unit: "g", color: .pink)
                        MacroLabel(icon: "leaf.fill", value: Int(log.carbs), unit: "g", color: .orange)
                        MacroLabel(icon: "drop.fill", value: Int(log.fat), unit: "g", color: .blue)
                    }
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .task {
            if let fileName = log.imageFileName {
                thumbnail = FoodImageManager.shared.loadThumbnail(fileName: fileName, size: imageSize)
            }
        }
    }
}

// MARK: - Macro Label

private struct MacroLabel: View {
    let icon: String
    let value: Int
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)
            Text("\(value)\(unit)")
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(Theme.secondaryText)
        }
    }
}

// MARK: - Nutrition Stat Row (shared)

struct NutritionStatRow: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(unit)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
    }
}

// MARK: - Streak Badge

private struct StreakBadge: View {
    let streak: Int
    @State private var isAnimating = false

    private let fireGradient = LinearGradient(
        colors: [.orange, .red, .orange.opacity(0.8)],
        startPoint: .bottom,
        endPoint: .top
    )

    var body: some View {
        HStack(spacing: 4) {
            // Animated fire icon
            ZStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(fireGradient)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .opacity(isAnimating ? 1.0 : 0.9)
            }
            .animation(
                streak > 0 ?
                    Animation.easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true) : .default,
                value: isAnimating
            )

            // Streak count
            Text("\(streak)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(streak > 0 ? Theme.primaryText : Theme.secondaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(streak > 0 ? Color.orange.opacity(0.15) : Color.gray.opacity(0.1))
        )
        .onAppear {
            if streak > 0 {
                isAnimating = true
            }
        }
        .onChange(of: streak) { _, newStreak in
            isAnimating = newStreak > 0
        }
    }
}

// MARK: - Calories Burned Weekly Card

struct CaloriesBurnedWeeklyCard: View {
    let data: [DailyHealthSummary]

    @State private var selectedDay: String?

    private func summaryFor(day: String?) -> DailyHealthSummary? {
        guard let day else { return nil }
        return data.first { $0.date.shortDayName == day }
    }

    private var weeklyAverage: Int {
        let calData = data.compactMap { $0.metrics[.activeCalories] }
        guard !calData.isEmpty else { return 0 }
        return Int(calData.reduce(0, +) / Double(calData.count))
    }

    private var todayCalories: Int {
        guard let today = data.first(where: { Calendar.current.isDateInToday($0.date) }),
              let cal = today.metrics[.activeCalories] else { return 0 }
        return Int(cal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Header
            HStack {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: Theme.IconSize.sm, weight: .semibold))
                        .foregroundStyle(Theme.calories)
                    Text("Calories Burned")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                }

                Spacer()

                if let day = selectedDay, let summary = summaryFor(day: day),
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

            // Today's stats row
            HStack(spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(todayCalories)")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(Theme.calories)
                        Text("kcal")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }

                Divider()
                    .frame(height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly Avg")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(weeklyAverage)")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(Theme.secondaryText)
                        Text("kcal")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }

                Spacer()
            }
            .padding(.bottom, Theme.Spacing.xs)

            // Chart
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
                    .foregroundStyle(selectedDay == dayName ? Theme.calories : Theme.calories.opacity(0.7))
                    .symbolSize(selectedDay == dayName ? 60 : 20)
                } else {
                    PointMark(
                        x: .value("Day", dayName),
                        y: .value("Cal", 0)
                    )
                    .foregroundStyle(Color.gray.opacity(0.3))
                    .symbolSize(40)
                    .symbol(.circle)
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
                AxisMarks(position: .leading)
            }
        }
        .cardStyle()
    }
}
