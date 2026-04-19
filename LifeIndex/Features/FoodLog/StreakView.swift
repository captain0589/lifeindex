import SwiftUI

struct StreakView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStreak: Int = 0
    @State private var longestStreak: Int = 0
    @State private var totalDaysLogged: Int = 0
    @State private var selectedMonth: Date = Date()
    @State private var daysWithLogs: Set<Date> = []
    @State private var showConfetti = false
    @State private var selectedDate: Date? = nil
    @State private var selectedDateLogs: [FoodLog] = []

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // MARK: - Streak Hero
                    StreakHeroCard(
                        currentStreak: currentStreak,
                        longestStreak: longestStreak,
                        totalDaysLogged: totalDaysLogged
                    )

                    // MARK: - Monthly Calendar
                    StreakCalendarCard(
                        selectedMonth: $selectedMonth,
                        selectedDate: $selectedDate,
                        daysWithLogs: daysWithLogs,
                        onDateTap: { date in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedDate == date {
                                    selectedDate = nil
                                    selectedDateLogs = []
                                } else {
                                    selectedDate = date
                                    selectedDateLogs = CoreDataStack.shared.fetchFoodLogs(for: date)
                                }
                            }
                        }
                    )

                    // MARK: - Selected Date Details
                    if let date = selectedDate {
                        SelectedDateDetailCard(
                            date: date,
                            logs: selectedDateLogs
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity
                        ))
                    }

                    // MARK: - Missions & Achievements
                    MissionsCard(
                        currentStreak: currentStreak,
                        totalDaysLogged: totalDaysLogged
                    )

                    // MARK: - Streak Tips
                    StreakTipsCard()
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("streak.title".localized)
            .navigationBarTitleDisplayMode(.large)
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
        .task {
            loadStreakData()
        }
        .onChange(of: selectedMonth) { _, _ in
            loadMonthData()
        }
    }

    private func loadStreakData() {
        currentStreak = StreakManager.calculateCurrentStreak()
        longestStreak = calculateLongestStreak()
        totalDaysLogged = calculateTotalDaysLogged()
        loadMonthData()
    }

    private func loadMonthData() {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        daysWithLogs = StreakManager.datesWithLogs(from: startOfMonth, to: min(endOfMonth, Date()))
    }

    private func calculateLongestStreak() -> Int {
        // Look back 365 days to find longest streak
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -365, to: today) else { return 0 }

        var longestStreak = 0
        var currentStreakCount = 0
        var checkDate = startDate

        while checkDate <= today {
            let logs = CoreDataStack.shared.fetchFoodLogs(for: checkDate)
            if !logs.isEmpty {
                currentStreakCount += 1
                longestStreak = max(longestStreak, currentStreakCount)
            } else {
                currentStreakCount = 0
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: checkDate) else { break }
            checkDate = nextDay
        }

        return longestStreak
    }

    private func calculateTotalDaysLogged() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -365, to: today) else { return 0 }

        var count = 0
        var checkDate = startDate

        while checkDate <= today {
            let logs = CoreDataStack.shared.fetchFoodLogs(for: checkDate)
            if !logs.isEmpty {
                count += 1
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: checkDate) else { break }
            checkDate = nextDay
        }

        return count
    }
}

// MARK: - Streak Hero Card

private struct StreakHeroCard: View {
    let currentStreak: Int
    let longestStreak: Int
    let totalDaysLogged: Int

    @State private var isAnimating = false

    private let fireGradient = LinearGradient(
        colors: [.orange, .red, .orange],
        startPoint: .bottom,
        endPoint: .top
    )

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Big fire + streak number
            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    // Glow effect
                    Image(systemName: "flame.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(fireGradient)
                        .blur(radius: 15)
                        .opacity(0.5)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)

                    Image(systemName: "flame.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(fireGradient)
                        .scaleEffect(isAnimating ? 1.05 : 1.0)
                }
                .animation(
                    Animation.easeInOut(duration: 1.2)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(currentStreak)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)

                    Text("streak.dayStreak".localized)
                        .font(.system(.title3, design: .rounded, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            // Stats row
            HStack(spacing: Theme.Spacing.xl) {
                StatBubble(
                    value: "\(longestStreak)",
                    label: "streak.bestStreak".localized,
                    icon: "trophy.fill",
                    color: .yellow
                )

                StatBubble(
                    value: "\(totalDaysLogged)",
                    label: "streak.totalDays".localized,
                    icon: "calendar.badge.checkmark",
                    color: .green
                )
            }

            // Motivational message
            Text(motivationalMessage)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(Theme.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.orange.opacity(0.5), .red.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
        )
        .onAppear { isAnimating = true }
    }

    private var motivationalMessage: String {
        switch currentStreak {
        case 0: return "streak.motivation.0".localized
        case 1: return "streak.motivation.1".localized
        case 2...6: return "streak.motivation.week".localized
        case 7...13: return "streak.motivation.fullWeek".localized
        case 14...29: return "streak.motivation.twoWeeks".localized
        case 30...59: return "streak.motivation.month".localized
        case 60...89: return "streak.motivation.twoMonths".localized
        case 90...179: return "streak.motivation.threeMonths".localized
        case 180...364: return "streak.motivation.halfYear".localized
        default: return "streak.motivation.year".localized
        }
    }
}

// MARK: - Stat Bubble

private struct StatBubble: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)

            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.primaryText)

            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Streak Calendar Card

private struct StreakCalendarCard: View {
    @Binding var selectedMonth: Date
    @Binding var selectedDate: Date?
    let daysWithLogs: Set<Date>
    let onDateTap: (Date) -> Void

    private let calendar = Calendar.current
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

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

        // Fill remaining cells
        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Header
            HStack {
                Text("streak.calendar".localized)
                    .font(.system(.headline, design: .rounded, weight: .bold))

                Spacer()

                HStack(spacing: Theme.Spacing.md) {
                    Button {
                        withAnimation {
                            selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.calories)
                    }

                    Text(monthYearString)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .frame(minWidth: 120)

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
                                    : Theme.calories
                            )
                    }
                    .disabled(calendar.date(byAdding: .month, value: 1, to: selectedMonth)! > Date())
                }
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
                        CalendarDayCell(
                            date: date,
                            hasLog: daysWithLogs.contains(calendar.startOfDay(for: date)),
                            isToday: calendar.isDateInToday(date),
                            isFuture: date > Date(),
                            isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false,
                            onTap: { onDateTap(date) }
                        )
                    } else {
                        Color.clear
                            .frame(height: 36)
                    }
                }
            }

            // Hint text
            Text("streak.tapToView".localized)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(Theme.Spacing.lg)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Calendar Day Cell

private struct CalendarDayCell: View {
    let date: Date
    let hasLog: Bool
    let isToday: Bool
    let isFuture: Bool
    let isSelected: Bool
    let onTap: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button {
            if !isFuture {
                onTap()
            }
        } label: {
            ZStack {
                if hasLog {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.orange, .red.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                } else if isToday {
                    Circle()
                        .fill(Theme.tertiaryBackground)

                    Circle()
                        .stroke(Theme.calories, lineWidth: 2)

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

                // Selection ring
                if isSelected {
                    Circle()
                        .stroke(Theme.calories, lineWidth: 3)
                }
            }
            .frame(height: 36)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }
}

// MARK: - Missions Card

private struct MissionsCard: View {
    let currentStreak: Int
    let totalDaysLogged: Int

    private var missions: [Mission] {
        [
            Mission(
                id: "first_log",
                title: "mission.firstStep.title".localized,
                description: "mission.firstStep.desc".localized,
                icon: "star.fill",
                color: .yellow,
                progress: min(1, totalDaysLogged),
                target: 1,
                reward: "mission.firstStep.reward".localized
            ),
            Mission(
                id: "streak_3",
                title: "mission.gettingStarted.title".localized,
                description: "mission.gettingStarted.desc".localized,
                icon: "flame.fill",
                color: .orange,
                progress: min(3, currentStreak),
                target: 3,
                reward: "mission.gettingStarted.reward".localized
            ),
            Mission(
                id: "streak_7",
                title: "mission.weekWarrior.title".localized,
                description: "mission.weekWarrior.desc".localized,
                icon: "flame.fill",
                color: .orange,
                progress: min(7, currentStreak),
                target: 7,
                reward: "mission.weekWarrior.reward".localized
            ),
            Mission(
                id: "streak_30",
                title: "mission.monthlyMaster.title".localized,
                description: "mission.monthlyMaster.desc".localized,
                icon: "flame.fill",
                color: .red,
                progress: min(30, currentStreak),
                target: 30,
                reward: "mission.monthlyMaster.reward".localized
            ),
            Mission(
                id: "total_10",
                title: "mission.dedicatedLogger.title".localized,
                description: "mission.dedicatedLogger.desc".localized,
                icon: "calendar.badge.checkmark",
                color: .green,
                progress: min(10, totalDaysLogged),
                target: 10,
                reward: "mission.dedicatedLogger.reward".localized
            ),
            Mission(
                id: "total_50",
                title: "mission.habitBuilder.title".localized,
                description: "mission.habitBuilder.desc".localized,
                icon: "calendar.badge.checkmark",
                color: .green,
                progress: min(50, totalDaysLogged),
                target: 50,
                reward: "mission.habitBuilder.reward".localized
            ),
            Mission(
                id: "streak_100",
                title: "mission.centuryClub.title".localized,
                description: "mission.centuryClub.desc".localized,
                icon: "crown.fill",
                color: .purple,
                progress: min(100, currentStreak),
                target: 100,
                reward: "mission.centuryClub.reward".localized
            ),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "target")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.purple)

                Text("streak.missions".localized)
                    .font(.system(.headline, design: .rounded, weight: .bold))

                Spacer()

                Text("\(missions.filter { $0.isComplete }.count)/\(missions.count)")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
            }

            ForEach(missions) { mission in
                MissionRow(mission: mission)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Mission Model

private struct Mission: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let color: Color
    let progress: Int
    let target: Int
    let reward: String

    var isComplete: Bool { progress >= target }
    var progressPercent: Double { Double(progress) / Double(target) }
}

// MARK: - Mission Row

private struct MissionRow: View {
    let mission: Mission

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(mission.isComplete ? mission.color : mission.color.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: mission.isComplete ? "checkmark" : mission.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(mission.isComplete ? .white : mission.color)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(mission.title)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.primaryText)

                    if mission.isComplete {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                    }
                }

                Text(mission.description)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)

                if !mission.isComplete {
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 6)

                            Capsule()
                                .fill(mission.color)
                                .frame(width: geo.size.width * mission.progressPercent, height: 6)
                        }
                    }
                    .frame(height: 6)

                    Text("\(mission.progress)/\(mission.target)")
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            Spacer()
        }
        .padding(.vertical, Theme.Spacing.xs)
        .opacity(mission.isComplete ? 0.7 : 1.0)
    }
}

// MARK: - Streak Tips Card

private struct StreakTipsCard: View {
    private var tips: [(String, String)] {
        [
            ("clock.badge.checkmark", "streak.tip.sameTime".localized),
            ("bell.badge", "streak.tip.reminders".localized),
            ("photo.on.rectangle", "streak.tip.photos".localized),
            ("sparkles", "streak.tip.aiEstimate".localized),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.yellow)

                Text("streak.proTips".localized)
                    .font(.system(.headline, design: .rounded, weight: .bold))
            }

            ForEach(tips, id: \.0) { tip in
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    Image(systemName: tip.0)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.calories)
                        .frame(width: 24)

                    Text(tip.1)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Selected Date Detail Card

private struct SelectedDateDetailCard: View {
    let date: Date
    let logs: [FoodLog]

    private var totalCalories: Int {
        logs.reduce(0) { $0 + Int($1.calories) }
    }

    private var totalProtein: Double {
        logs.reduce(0) { $0 + $1.protein }
    }

    private var totalCarbs: Double {
        logs.reduce(0) { $0 + $1.carbs }
    }

    private var totalFat: Double {
        logs.reduce(0) { $0 + $1.fat }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateFormatter.string(from: date))
                        .font(.system(.headline, design: .rounded, weight: .bold))

                    if logs.isEmpty {
                        Text("streak.noLogsThisDay".localized)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    } else {
                        Text("\(logs.count) " + (logs.count == 1 ? "food.item".localized : "food.items".localized))
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }

                Spacer()

                // Total calories badge
                if !logs.isEmpty {
                    Text("\(totalCalories) " + "units.kcal".localized)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Theme.calories)
                        .clipShape(Capsule())
                }
            }

            if !logs.isEmpty {
                // Macro summary
                HStack(spacing: Theme.Spacing.lg) {
                    MacroSummaryItem(label: "P", value: Int(totalProtein), color: .pink)
                    MacroSummaryItem(label: "C", value: Int(totalCarbs), color: .orange)
                    MacroSummaryItem(label: "F", value: Int(totalFat), color: .blue)
                }
                .padding(.vertical, Theme.Spacing.sm)

                Divider()

                // Food items list
                ForEach(logs) { log in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.name ?? "Unknown")
                                .font(.system(.subheadline, design: .rounded, weight: .medium))

                            Text(log.mealTypeEnum.displayName)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }

                        Spacer()

                        Text("\(log.calories) " + "units.kcal".localized)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.calories)
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Macro Summary Item

private struct MacroSummaryItem: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text("\(value)g")
                .font(.system(.caption, design: .rounded, weight: .medium))
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}
