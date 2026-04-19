import Foundation

/// Manages tracking of consecutive food logging streaks
struct StreakManager {

    /// Calculates the current streak of consecutive days with food logs
    /// - Returns: Number of consecutive days ending with today (or yesterday if no logs today yet)
    static func calculateCurrentStreak() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var streak = 0
        var checkDate = today

        // Check if today has logs
        let todayLogs = CoreDataStack.shared.fetchFoodLogs(for: today)
        let hasTodayLogs = !todayLogs.isEmpty

        // If no logs today, start checking from yesterday
        if !hasTodayLogs {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
                return 0
            }
            checkDate = yesterday
        }

        // Count consecutive days with logs
        while true {
            let logs = CoreDataStack.shared.fetchFoodLogs(for: checkDate)
            if logs.isEmpty {
                break
            }

            streak += 1

            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                break
            }
            checkDate = previousDay
        }

        return streak
    }

    /// Checks if the user logged food today
    static func hasLoggedToday() -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let logs = CoreDataStack.shared.fetchFoodLogs(for: today)
        return !logs.isEmpty
    }

    /// Gets dates with food logs in a given range
    static func datesWithLogs(from startDate: Date, to endDate: Date) -> Set<Date> {
        let calendar = Calendar.current
        var dates: Set<Date> = []
        var currentDate = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        while currentDate <= end {
            let logs = CoreDataStack.shared.fetchFoodLogs(for: currentDate)
            if !logs.isEmpty {
                dates.insert(currentDate)
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDay
        }

        return dates
    }
}
