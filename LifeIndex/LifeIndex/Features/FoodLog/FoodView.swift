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
    @State private var selectedLogForEdit: FoodLog?
    @State private var showGoalEditor = false

    // Profile-based goal
    @AppStorage("dailyCalorieGoal") private var dailyCalorieGoal: Int = 2000
    @AppStorage("customProteinTarget") private var customProteinTarget: Int = 0
    @AppStorage("customCarbsTarget") private var customCarbsTarget: Int = 0
    @AppStorage("customFatTarget") private var customFatTarget: Int = 0
    @AppStorage("useCustomMacros") private var useCustomMacros: Bool = false
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

    // MyFitnessPal formula: Remaining = Goal - Food + Exercise
    private var remaining: Int {
        dailyCalorieGoal - Int(consumedCalories) + Int(burnedCalories)
    }

    private var isOverGoal: Bool {
        remaining < 0
    }

    private var progress: Double {
        guard dailyCalorieGoal > 0 else { return 0 }
        // Progress based on net consumption (food - exercise)
        let netConsumed = consumedCalories - burnedCalories
        return min(1.0, max(0, netConsumed / Double(dailyCalorieGoal)))
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
        if useCustomMacros && (customProteinTarget > 0 || customCarbsTarget > 0 || customFatTarget > 0) {
            return NutritionEngine.MacroTargets(
                protein: customProteinTarget > 0 ? customProteinTarget : NutritionEngine.macroTargets(calorieGoal: dailyCalorieGoal).protein,
                carbs: customCarbsTarget > 0 ? customCarbsTarget : NutritionEngine.macroTargets(calorieGoal: dailyCalorieGoal).carbs,
                fat: customFatTarget > 0 ? customFatTarget : NutritionEngine.macroTargets(calorieGoal: dailyCalorieGoal).fat
            )
        }
        return NutritionEngine.macroTargets(calorieGoal: dailyCalorieGoal)
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

                    // MARK: - Edit Goals Button
                    HStack {
                        Spacer()
                        Button {
                            showGoalEditor = true
                        } label: {
                            HStack(spacing: Theme.Spacing.xs) {
                                Image(systemName: "pencil")
                                Text("food.editGoals".localized)
                            }
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .padding(.horizontal)

                    // MARK: - Calories & Macros Pager (MyFitnessPal style)
                    CaloriesMacrosPager(
                        remaining: remaining,
                        isOverGoal: isOverGoal,
                        goal: dailyCalorieGoal,
                        food: Int(consumedCalories),
                        exercise: Int(burnedCalories),
                        protein: todayProtein,
                        proteinTarget: Double(macroTargets.protein),
                        carbs: todayCarbs,
                        carbsTarget: Double(macroTargets.carbs),
                        fat: todayFat,
                        fatTarget: Double(macroTargets.fat)
                    )
                    .padding(.horizontal)

                    // MARK: - Today's Meals / Diary
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        HStack {
                            Text("food.diary".localized)
                                .font(.system(.title3, design: .rounded, weight: .bold))
                            Spacer()
                            if !todayLogs.isEmpty {
                                let totalCal = todayLogs.reduce(0) { $0 + Int($1.calories) }
                                Text("\(totalCal) " + "units.kcal".localized)
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundStyle(Theme.calories)
                            }
                        }

                        if todayLogs.isEmpty {
                            VStack(spacing: Theme.Spacing.md) {
                                Image(systemName: "fork.knife.circle")
                                    .font(.system(size: Theme.FontSize.display))
                                    .foregroundStyle(Theme.secondaryText.opacity(0.5))
                                Text("food.noMealsLogged".localized)
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.xl)
                        } else {
                            // Group by meal types in order: Breakfast, Lunch, Dinner, Snacks
                            let mealOrder: [MealType] = [.breakfast, .lunch, .dinner, .snack]
                            ForEach(mealOrder, id: \.rawValue) { mealType in
                                let logsForMeal = todayLogs.filter { $0.mealTypeEnum == mealType }
                                if !logsForMeal.isEmpty {
                                    MealSectionWithEdit(
                                        mealType: mealType,
                                        logs: logsForMeal,
                                        onLogTap: { log in
                                            selectedLogForEdit = log
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(Theme.Spacing.lg)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal)

                    Spacer(minLength: 80)
                }
                .padding(.top, Theme.Spacing.md)
            }
            .pageBackground(showGradient: true, gradientHeight: 300)
            .navigationTitle("food.title".localized)
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
            .sheet(item: $selectedLogForEdit, onDismiss: {
                refreshData()
            }) { log in
                FoodEditSheet(log: log)
            }
            .sheet(isPresented: $showGoalEditor) {
                GoalEditorSheet(
                    dailyCalorieGoal: $dailyCalorieGoal,
                    customProteinTarget: $customProteinTarget,
                    customCarbsTarget: $customCarbsTarget,
                    customFatTarget: $customFatTarget,
                    useCustomMacros: $useCustomMacros,
                    calculatedGoal: calculatedGoal
                )
                .presentationDetents([.medium])
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
                // Note: We prioritize Core Data food logs over HealthKit
                // HealthKit is only used for external entries not tracked in our app
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
        // Calculate consumed calories from local Core Data logs (source of truth for app-tracked food)
        let logsCalories = todayLogs.reduce(0) { $0 + Int($1.calories) }
        consumedCalories = Double(logsCalories)
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
    let labelKey: String
    let current: Double
    let target: Double
    let unit: String
    let color: Color
    let icon: String

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(1.0, current / target)
    }

    private var localizedEatenLabel: String {
        switch labelKey {
        case "food.protein": return "food.proteinEaten".localized
        case "food.carbs": return "food.carbsEaten".localized
        case "food.fat": return "food.fatEaten".localized
        default: return labelKey.localized
        }
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

            Text(localizedEatenLabel)
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
    @State private var showConfirmation = false

    // Profile data for calculation breakdown
    @AppStorage("userAge") private var userAge: Int = 25
    @AppStorage("userWeightKg") private var userWeightKg: Double = 70
    @AppStorage("userHeightCm") private var userHeightCm: Double = 170
    @AppStorage("userGender") private var userGender: Int = 0
    @AppStorage("userActivityLevel") private var userActivityLevel: Int = 2
    @AppStorage("userGoalType") private var userGoalType: Int = 1

    private var bmr: Int {
        Int(NutritionEngine.bmr(weightKg: userWeightKg, heightCm: userHeightCm, age: userAge, isMale: userGender == 0))
    }

    private var tdee: Int {
        let b = NutritionEngine.bmr(weightKg: userWeightKg, heightCm: userHeightCm, age: userAge, isMale: userGender == 0)
        return Int(NutritionEngine.tdee(bmr: b, activityLevel: userActivityLevel))
    }

    private var goalAdjustment: Int {
        let goal = NutritionEngine.GoalType(rawValue: userGoalType) ?? .maintain
        return goal.calorieAdjustment
    }

    private var activityLevel: NutritionEngine.ActivityLevel {
        NutritionEngine.ActivityLevel(rawValue: userActivityLevel) ?? .moderate
    }

    private var goalType: NutritionEngine.GoalType {
        NutritionEngine.GoalType(rawValue: userGoalType) ?? .maintain
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "target")
                        .font(.system(size: Theme.IconSize.md))
                        .foregroundStyle(Theme.calories)
                    Text("food.dailyGoal".localized + ": \(dailyGoal) " + "units.kcal".localized)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(Theme.primaryText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: Theme.IconSize.xs, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(Theme.Spacing.md)
            }

            if isExpanded {
                Divider()
                    .padding(.horizontal)

                VStack(spacing: Theme.Spacing.md) {
                    // Calculation breakdown
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Recommended: \(calculatedGoal) " + "units.kcal".localized)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(Theme.calories)

                        VStack(alignment: .leading, spacing: 6) {
                            CalcBreakdownRow(label: "BMR", value: "\(bmr)", detail: "Base metabolism")
                            CalcBreakdownRow(label: "× Activity", value: String(format: "%.2f", activityLevel.multiplier), detail: activityLevel.localizedName)
                            CalcBreakdownRow(label: "= TDEE", value: "\(tdee)", detail: "Daily energy")
                            if goalAdjustment != 0 {
                                CalcBreakdownRow(
                                    label: goalAdjustment > 0 ? "+ Surplus" : "− Deficit",
                                    value: "\(abs(goalAdjustment))",
                                    detail: goalType.localizedName
                                )
                            }
                        }
                        .padding(Theme.Spacing.sm)
                        .background(Theme.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.xs, style: .continuous))
                    }

                    Divider()

                    // Manual goal input
                    HStack {
                        Text("food.dailyGoal".localized)
                            .font(.system(.subheadline, design: .rounded))
                        Spacer()
                        HStack(spacing: Theme.Spacing.xs) {
                            TextField("", value: $dailyGoal, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .frame(width: 60)
                            Text("units.kcal".localized)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }

                    Button {
                        showConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("food.useRecommended".localized + " (\(calculatedGoal) " + "units.kcal".localized + ")")
                        }
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(Theme.calories)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Theme.calories.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm, style: .continuous))
                    }
                }
                .padding(Theme.Spacing.md)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .alert("Update Daily Goal?", isPresented: $showConfirmation) {
            Button("common.cancel".localized, role: .cancel) { }
            Button("Confirm") {
                dailyGoal = calculatedGoal
            }
        } message: {
            Text("This will change your daily calorie goal from \(dailyGoal) to \(calculatedGoal) kcal. Your tracking data will remain, but progress will be calculated against the new goal.")
        }
    }
}

// MARK: - Calculation Breakdown Row

private struct CalcBreakdownRow: View {
    let label: String
    let value: String
    let detail: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.primaryText)
            Text(detail)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
            Spacer()
        }
    }
}

// MARK: - Goal Editor Sheet

private struct GoalEditorSheet: View {
    @Binding var dailyCalorieGoal: Int
    @Binding var customProteinTarget: Int
    @Binding var customCarbsTarget: Int
    @Binding var customFatTarget: Int
    @Binding var useCustomMacros: Bool
    let calculatedGoal: Int
    @Environment(\.dismiss) private var dismiss

    @State private var calorieText: String = ""
    @State private var proteinText: String = ""
    @State private var carbsText: String = ""
    @State private var fatText: String = ""
    @State private var showBreakdown = false

    // Profile data for calculation breakdown
    @AppStorage("userAge") private var userAge: Int = 25
    @AppStorage("userWeightKg") private var userWeightKg: Double = 70
    @AppStorage("userHeightCm") private var userHeightCm: Double = 170
    @AppStorage("userGender") private var userGender: Int = 0
    @AppStorage("userActivityLevel") private var userActivityLevel: Int = 2
    @AppStorage("userGoalType") private var userGoalType: Int = 1

    private var defaultMacros: NutritionEngine.MacroTargets {
        NutritionEngine.macroTargets(calorieGoal: dailyCalorieGoal)
    }

    private var bmi: Double {
        let heightM = userHeightCm / 100
        guard heightM > 0 else { return 0 }
        return userWeightKg / (heightM * heightM)
    }

    private var bmiCategory: String {
        switch bmi {
        case ..<18.5: return "food.bmi.underweight".localized
        case 18.5..<25: return "food.bmi.normal".localized
        case 25..<30: return "food.bmi.overweight".localized
        default: return "food.bmi.obese".localized
        }
    }

    private var bmr: Int {
        Int(NutritionEngine.bmr(weightKg: userWeightKg, heightCm: userHeightCm, age: userAge, isMale: userGender == 0))
    }

    private var tdee: Int {
        let b = NutritionEngine.bmr(weightKg: userWeightKg, heightCm: userHeightCm, age: userAge, isMale: userGender == 0)
        return Int(NutritionEngine.tdee(bmr: b, activityLevel: userActivityLevel))
    }

    private var goalAdjustment: Int {
        let goal = NutritionEngine.GoalType(rawValue: userGoalType) ?? .maintain
        return goal.calorieAdjustment
    }

    private var activityLevel: NutritionEngine.ActivityLevel {
        NutritionEngine.ActivityLevel(rawValue: userActivityLevel) ?? .moderate
    }

    private var goalType: NutritionEngine.GoalType {
        NutritionEngine.GoalType(rawValue: userGoalType) ?? .maintain
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Calories Goal
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(Theme.calories)
                            Text("food.calorieGoal".localized)
                                .font(.system(.headline, design: .rounded, weight: .semibold))
                        }

                        HStack {
                            TextField("2000", text: $calorieText)
                                .keyboardType(.numberPad)
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .multilineTextAlignment(.leading)
                            Text("units.kcal".localized)
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                            Spacer()
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))

                        Button {
                            calorieText = "\(calculatedGoal)"
                        } label: {
                            HStack(spacing: Theme.Spacing.xs) {
                                Image(systemName: "sparkles")
                                Text("food.useRecommended".localized + " (\(calculatedGoal))")
                            }
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(Theme.calories)
                        }

                        // Calculation breakdown toggle
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showBreakdown.toggle()
                            }
                        } label: {
                            HStack(spacing: Theme.Spacing.xs) {
                                Image(systemName: showBreakdown ? "chevron.up" : "chevron.down")
                                Text("food.howCalculated".localized)
                            }
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(Theme.secondaryText)
                        }

                        if showBreakdown {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                // BMI
                                HStack {
                                    Text("BMI")
                                        .font(.system(.caption, design: .rounded, weight: .medium))
                                        .foregroundStyle(Theme.secondaryText)
                                        .frame(width: 70, alignment: .leading)
                                    Text(String(format: "%.1f", bmi))
                                        .font(.system(.caption, design: .rounded, weight: .bold))
                                        .foregroundStyle(Theme.primaryText)
                                    Text("(\(bmiCategory))")
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(bmiColor)
                                    Spacer()
                                }

                                // BMR
                                HStack {
                                    Text("BMR")
                                        .font(.system(.caption, design: .rounded, weight: .medium))
                                        .foregroundStyle(Theme.secondaryText)
                                        .frame(width: 70, alignment: .leading)
                                    Text("\(bmr)")
                                        .font(.system(.caption, design: .rounded, weight: .bold))
                                        .foregroundStyle(Theme.primaryText)
                                    Text("food.baseMetabolism".localized)
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(Theme.secondaryText)
                                    Spacer()
                                }

                                // TDEE
                                HStack {
                                    Text("TDEE")
                                        .font(.system(.caption, design: .rounded, weight: .medium))
                                        .foregroundStyle(Theme.secondaryText)
                                        .frame(width: 70, alignment: .leading)
                                    Text("\(tdee)")
                                        .font(.system(.caption, design: .rounded, weight: .bold))
                                        .foregroundStyle(Theme.primaryText)
                                    Text("× \(String(format: "%.2f", activityLevel.multiplier))")
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(Theme.secondaryText)
                                    Spacer()
                                }

                                // Goal adjustment
                                if goalAdjustment != 0 {
                                    HStack {
                                        Text("food.goal".localized)
                                            .font(.system(.caption, design: .rounded, weight: .medium))
                                            .foregroundStyle(Theme.secondaryText)
                                            .frame(width: 70, alignment: .leading)
                                        Text(goalAdjustment > 0 ? "+\(goalAdjustment)" : "\(goalAdjustment)")
                                            .font(.system(.caption, design: .rounded, weight: .bold))
                                            .foregroundStyle(goalAdjustment > 0 ? .green : Theme.calories)
                                        Text(goalType.localizedName)
                                            .font(.system(.caption2, design: .rounded))
                                            .foregroundStyle(Theme.secondaryText)
                                        Spacer()
                                    }
                                }
                            }
                            .padding(Theme.Spacing.md)
                            .background(Theme.tertiaryBackground.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                    Divider()

                    // Macro Targets
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        HStack {
                            Text("food.macroTargets".localized)
                                .font(.system(.headline, design: .rounded, weight: .semibold))
                            Spacer()
                            Toggle("", isOn: $useCustomMacros)
                                .labelsHidden()
                                .tint(Theme.calories)
                        }

                        Text(useCustomMacros ? "food.customMacros".localized : "food.autoMacros".localized)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)

                        if useCustomMacros {
                            VStack(spacing: Theme.Spacing.sm) {
                                MacroInputRow(
                                    label: "food.protein".localized,
                                    text: $proteinText,
                                    placeholder: "\(defaultMacros.protein)",
                                    color: .pink
                                )
                                MacroInputRow(
                                    label: "food.carbs".localized,
                                    text: $carbsText,
                                    placeholder: "\(defaultMacros.carbs)",
                                    color: .orange
                                )
                                MacroInputRow(
                                    label: "food.fat".localized,
                                    text: $fatText,
                                    placeholder: "\(defaultMacros.fat)",
                                    color: .blue
                                )
                            }
                        } else {
                            HStack(spacing: Theme.Spacing.lg) {
                                MacroPreview(label: "P", value: defaultMacros.protein, color: .pink)
                                MacroPreview(label: "C", value: defaultMacros.carbs, color: .orange)
                                MacroPreview(label: "F", value: defaultMacros.fat, color: .blue)
                            }
                            .padding(Theme.Spacing.md)
                            .background(Theme.tertiaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("food.editGoals".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.save".localized) {
                        saveGoals()
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                }
            }
        }
        .onAppear {
            calorieText = "\(dailyCalorieGoal)"
            proteinText = customProteinTarget > 0 ? "\(customProteinTarget)" : ""
            carbsText = customCarbsTarget > 0 ? "\(customCarbsTarget)" : ""
            fatText = customFatTarget > 0 ? "\(customFatTarget)" : ""
            // Default to custom macros enabled
            if !useCustomMacros && customProteinTarget == 0 && customCarbsTarget == 0 && customFatTarget == 0 {
                useCustomMacros = true
            }
        }
    }

    private var bmiColor: Color {
        switch bmi {
        case ..<18.5: return .blue
        case 18.5..<25: return .green
        case 25..<30: return .orange
        default: return .red
        }
    }

    private func saveGoals() {
        if let calories = Int(calorieText), calories > 0 {
            dailyCalorieGoal = calories
        }
        if useCustomMacros {
            customProteinTarget = Int(proteinText) ?? 0
            customCarbsTarget = Int(carbsText) ?? 0
            customFatTarget = Int(fatText) ?? 0
        }
    }
}

// MARK: - Macro Input Row

private struct MacroInputRow: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 60, alignment: .leading)
            TextField(placeholder, text: $text)
                .keyboardType(.numberPad)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .multilineTextAlignment(.trailing)
            Text("g")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.xs))
    }
}

// MARK: - Macro Preview

private struct MacroPreview: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text("\(value)g")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
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

// MARK: - Meal Section With Edit

private struct MealSectionWithEdit: View {
    let mealType: MealType
    let logs: [FoodLog]
    let onLogTap: (FoodLog) -> Void

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

                Text(mealType.localizedName)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))

                Spacer()

                Text("\(totalCalories) " + "units.kcal".localized)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(.bottom, Theme.Spacing.xs)

            // Food items - tappable for editing
            ForEach(logs) { log in
                Button {
                    onLogTap(log)
                } label: {
                    FoodItemRow(log: log)
                }
                .buttonStyle(.plain)
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
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: Theme.IconSize.xs))
                        .foregroundStyle(Theme.calories)
                    Text("\(log.calories) " + "units.kcal".localized)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(Theme.calories)
                }

                // Macros row (if available)
                if log.protein > 0 || log.carbs > 0 || log.fat > 0 {
                    HStack(spacing: Theme.Spacing.md) {
                        MacroLabel(icon: "bolt.fill", value: Int(log.protein), unit: "food.grams".localized, color: .pink)
                        MacroLabel(icon: "leaf.fill", value: Int(log.carbs), unit: "food.grams".localized, color: .orange)
                        MacroLabel(icon: "drop.fill", value: Int(log.fat), unit: "food.grams".localized, color: .blue)
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

// MARK: - Food Edit Sheet

struct FoodEditSheet: View {
    let log: FoodLog
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var caloriesText: String = ""
    @State private var proteinText: String = ""
    @State private var carbsText: String = ""
    @State private var fatText: String = ""
    @State private var selectedImage: UIImage?
    @State private var showDeleteConfirmation = false
    @State private var showCamera = false

    private var canSave: Bool {
        guard let cal = Int(caloriesText) else { return false }
        return cal > 0 && cal <= 9999
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // MARK: - Food Name
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("food.whatDidYouEat".localized)
                            .font(Theme.headline)

                        TextField("food.placeholder".localized, text: $name)
                            .font(.system(.body, design: .rounded))
                            .padding(Theme.Spacing.md)
                            .background(Theme.tertiaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
                    }

                    // MARK: - Photo
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("food.addPhoto".localized)
                            .font(Theme.headline)

                        HStack(spacing: Theme.Spacing.sm) {
                            Button {
                                showCamera = true
                            } label: {
                                HStack(spacing: Theme.Spacing.xs) {
                                    Image(systemName: "camera.fill")
                                    Text("Take Photo")
                                }
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.sm)
                                .background(Theme.tertiaryBackground)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
                            }

                            Spacer()

                            if selectedImage != nil {
                                Button {
                                    selectedImage = nil
                                } label: {
                                    HStack(spacing: Theme.Spacing.xs) {
                                        Image(systemName: "xmark.circle.fill")
                                        Text("food.removePhoto".localized)
                                    }
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundStyle(Theme.error)
                                }
                            }
                        }

                        // Photo preview
                        if let image = selectedImage {
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                .fill(Theme.tertiaryBackground)
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .overlay {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
                                        .padding(Theme.Spacing.sm)
                                }
                        }
                    }
                    .fullScreenCover(isPresented: $showCamera) {
                        CameraView(image: $selectedImage)
                            .ignoresSafeArea()
                    }

                    // MARK: - Calories
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("food.calories".localized)
                            .font(Theme.headline)

                        HStack {
                            TextField("0", text: $caloriesText)
                                .keyboardType(.numberPad)
                                .font(.system(.title, design: .rounded, weight: .bold))
                            Text("units.kcal".localized)
                                .font(.system(.title3, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
                    }

                    // MARK: - Macros
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("food.macrosOptional".localized)
                            .font(Theme.headline)

                        HStack(spacing: Theme.Spacing.sm) {
                            EditMacroField(labelKey: "food.protein", text: $proteinText, color: .blue)
                            EditMacroField(labelKey: "food.carbs", text: $carbsText, color: .orange)
                            EditMacroField(labelKey: "food.fat", text: $fatText, color: .pink)
                        }
                    }

                    // MARK: - Delete Button
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("common.delete".localized)
                        }
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(Theme.error)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md, style: .continuous))
                    }
                }
                .padding()
            }
            .navigationTitle("Edit Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveChanges()
                    } label: {
                        Text("common.save".localized)
                            .font(.system(.body, design: .rounded, weight: .semibold))
                    }
                    .disabled(!canSave)
                }
            }
            .alert("Delete Entry?", isPresented: $showDeleteConfirmation) {
                Button("common.cancel".localized, role: .cancel) { }
                Button("common.delete".localized, role: .destructive) {
                    deleteEntry()
                }
            } message: {
                Text("This will permanently delete this food entry.")
            }
        }
        .onAppear {
            loadLogData()
        }
    }

    private func loadLogData() {
        name = log.name ?? ""
        caloriesText = "\(log.calories)"
        proteinText = log.protein > 0 ? "\(Int(log.protein))" : ""
        carbsText = log.carbs > 0 ? "\(Int(log.carbs))" : ""
        fatText = log.fat > 0 ? "\(Int(log.fat))" : ""

        // Load existing image
        if let fileName = log.imageFileName {
            selectedImage = FoodImageManager.shared.loadImage(fileName: fileName)
        }
    }

    private func saveChanges() {
        guard let calories = Int(caloriesText), canSave else { return }

        // Save new image if changed
        var imageFileName = log.imageFileName
        if let newImage = selectedImage {
            // Check if image actually changed
            let existingImage = log.imageFileName.flatMap { FoodImageManager.shared.loadImage(fileName: $0) }
            if existingImage?.pngData() != newImage.pngData() {
                imageFileName = FoodImageManager.shared.saveImage(newImage)
            }
        } else if selectedImage == nil && log.imageFileName != nil {
            // Image was removed
            imageFileName = nil
        }

        CoreDataStack.shared.updateFoodLog(
            log,
            name: name.isEmpty ? nil : name,
            calories: calories,
            protein: Double(proteinText) ?? 0,
            carbs: Double(carbsText) ?? 0,
            fat: Double(fatText) ?? 0,
            imageFileName: imageFileName
        )

        dismiss()
    }

    private func deleteEntry() {
        CoreDataStack.shared.deleteFoodLog(log)
        dismiss()
    }
}

// MARK: - Edit Macro Field

private struct EditMacroField: View {
    let labelKey: String
    @Binding var text: String
    let color: Color

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(labelKey.localized)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(color)
            HStack(spacing: 2) {
                TextField("0", text: $text)
                    .keyboardType(.decimalPad)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .multilineTextAlignment(.center)
                Text("food.grams".localized)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Theme.tertiaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.xs))
        }
        .frame(maxWidth: .infinity)
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
                    Text("activity.caloriesBurned".localized)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                }

                Spacer()

                if let day = selectedDay, let summary = summaryFor(day: day),
                   let cal = summary.metrics[.activeCalories] {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(day)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                        Text("\(Int(cal)) " + "units.kcal".localized)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(Theme.calories)
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
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(todayCalories)")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(Theme.calories)
                        Text("units.kcal".localized)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }

                Divider()
                    .frame(height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("common.weeklyAvg".localized)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(weeklyAverage)")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(Theme.secondaryText)
                        Text("units.kcal".localized)
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

// MARK: - Calories & Macros Pager (MyFitnessPal style)

private struct CaloriesMacrosPager: View {
    let remaining: Int
    let isOverGoal: Bool
    let goal: Int
    let food: Int
    let exercise: Int

    let protein: Double
    let proteinTarget: Double
    let carbs: Double
    let carbsTarget: Double
    let fat: Double
    let fatTarget: Double

    @State private var selectedPage = 0

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width * 0.85
            let spacing: CGFloat = 12

            VStack(spacing: Theme.Spacing.sm) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: spacing) {
                        // MARK: - Calories Card (Page 0)
                        CaloriesMainCard(
                            remaining: remaining,
                            isOverGoal: isOverGoal,
                            goal: goal,
                            food: food,
                            exercise: exercise
                        )
                        .frame(width: cardWidth)
                        .id(0)

                        // MARK: - Macros Card (Page 1)
                        MacrosMainCard(
                            protein: protein,
                            proteinTarget: proteinTarget,
                            carbs: carbs,
                            carbsTarget: carbsTarget,
                            fat: fat,
                            fatTarget: fatTarget
                        )
                        .frame(width: cardWidth)
                        .id(1)
                    }
                    .scrollTargetLayout()
                    .padding(.trailing, geometry.size.width - cardWidth - spacing)
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: Binding(
                    get: { selectedPage },
                    set: { if let newValue = $0 { selectedPage = newValue } }
                ))
                .frame(height: 200)

                // Page indicator dots
                HStack(spacing: 6) {
                    ForEach(0..<2, id: \.self) { index in
                        Circle()
                            .fill(selectedPage == index ? Theme.calories : Theme.secondaryText.opacity(0.3))
                            .frame(width: 6, height: 6)
                            .animation(.easeInOut(duration: 0.2), value: selectedPage)
                    }
                }
            }
        }
        .frame(height: 220)
    }
}

// MARK: - Calories Main Card

private struct CaloriesMainCard: View {
    let remaining: Int
    let isOverGoal: Bool
    let goal: Int
    let food: Int
    let exercise: Int

    private var remainingColor: Color {
        if isOverGoal {
            return .red
        } else if remaining < 200 {
            return .orange
        } else {
            return .green
        }
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Main remaining display
            VStack(spacing: 4) {
                Text(isOverGoal ? "food.overGoal".localized : "food.remaining".localized)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)

                Text("\(abs(remaining))")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(remainingColor)
                    .contentTransition(.numericText())
            }

            // Equation breakdown: remaining = Goal - Food + Exercise
            HStack(spacing: 0) {
                Text("remaining =")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.trailing, 6)

                EquationItem(label: "food.baseGoal".localized, value: goal, color: Theme.primaryText)

                Text("−")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 4)

                EquationItem(label: "food.food".localized, value: food, color: Theme.calories)

                Text("+")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 4)

                EquationItem(label: "food.exercise".localized, value: exercise, color: Theme.activity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Spacing.lg)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Equation Item

private struct EquationItem: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(Theme.secondaryText)
            Text("\(value)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
        .frame(minWidth: 50)
    }
}

// MARK: - Macros Main Card

private struct MacrosMainCard: View {
    let protein: Double
    let proteinTarget: Double
    let carbs: Double
    let carbsTarget: Double
    let fat: Double
    let fatTarget: Double

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("food.macronutrients".localized)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)

            HStack(spacing: Theme.Spacing.xl) {
                MacroRing(
                    label: "food.protein".localized,
                    current: protein,
                    target: proteinTarget,
                    color: .pink
                )

                MacroRing(
                    label: "food.carbs".localized,
                    current: carbs,
                    target: carbsTarget,
                    color: .orange
                )

                MacroRing(
                    label: "food.fat".localized,
                    current: fat,
                    target: fatTarget,
                    color: .blue
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Spacing.lg)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Macro Ring

private struct MacroRing: View {
    let label: String
    let current: Double
    let target: Double
    let color: Color

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(1.0, current / target)
    }

    private var remaining: Int {
        max(0, Int(target) - Int(current))
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)

                VStack(spacing: 0) {
                    Text("\(Int(current))")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(color)
                    Text("/\(Int(target))")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .frame(width: 70, height: 70)

            VStack(spacing: 2) {
                Text(label)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.primaryText)
                Text("\(remaining)g " + "food.left".localized)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }
}
