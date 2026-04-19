import Foundation

struct NutritionEngine {

    // MARK: - Activity Level

    enum ActivityLevel: Int, CaseIterable, Identifiable {
        case sedentary = 0
        case light = 1
        case moderate = 2
        case active = 3
        case veryActive = 4

        var id: Int { rawValue }

        var displayName: String {
            switch self {
            case .sedentary: return "Sedentary"
            case .light: return "Lightly Active"
            case .moderate: return "Moderately Active"
            case .active: return "Active"
            case .veryActive: return "Very Active"
            }
        }

        var description: String {
            switch self {
            case .sedentary: return "Little or no exercise"
            case .light: return "Light exercise 1-3 days/week"
            case .moderate: return "Moderate exercise 3-5 days/week"
            case .active: return "Hard exercise 6-7 days/week"
            case .veryActive: return "Very hard exercise, physical job"
            }
        }

        var multiplier: Double {
            switch self {
            case .sedentary: return 1.2
            case .light: return 1.375
            case .moderate: return 1.55
            case .active: return 1.725
            case .veryActive: return 1.9
            }
        }
    }

    // MARK: - Goal Type

    enum GoalType: Int, CaseIterable, Identifiable {
        case lose = 0
        case maintain = 1
        case gain = 2

        var id: Int { rawValue }

        var displayName: String {
            switch self {
            case .lose: return "Lose Weight"
            case .maintain: return "Maintain"
            case .gain: return "Gain Weight"
            }
        }

        var calorieAdjustment: Int {
            switch self {
            case .lose: return -500
            case .maintain: return 0
            case .gain: return 300
            }
        }
    }

    // MARK: - BMR (Mifflin-St Jeor)

    static func bmr(weightKg: Double, heightCm: Double, age: Int, isMale: Bool) -> Double {
        let base = (9.99 * weightKg) + (6.25 * heightCm) - (4.92 * Double(age))
        return base + (isMale ? 5.0 : -161.0)
    }

    // MARK: - TDEE

    static func tdee(bmr: Double, activityLevel: Int) -> Double {
        let level = ActivityLevel(rawValue: activityLevel) ?? .moderate
        return bmr * level.multiplier
    }

    // MARK: - Calorie Goal

    static func calorieGoal(tdee: Double, goalType: Int) -> Int {
        let goal = GoalType(rawValue: goalType) ?? .maintain
        let target = tdee + Double(goal.calorieAdjustment)
        // Minimum safe intake
        return max(1200, Int(target))
    }

    // MARK: - Convenience: Full Calculation

    static func calculateDailyGoal(
        weightKg: Double, heightCm: Double, age: Int,
        isMale: Bool, activityLevel: Int, goalType: Int
    ) -> Int {
        let b = bmr(weightKg: weightKg, heightCm: heightCm, age: age, isMale: isMale)
        let t = tdee(bmr: b, activityLevel: activityLevel)
        return calorieGoal(tdee: t, goalType: goalType)
    }

    // MARK: - Macro Targets (Protein 30%, Carbs 40%, Fat 30%)

    struct MacroTargets {
        let protein: Int   // grams
        let carbs: Int     // grams
        let fat: Int       // grams
    }

    static func macroTargets(calorieGoal: Int) -> MacroTargets {
        let cal = Double(calorieGoal)
        return MacroTargets(
            protein: Int(cal * 0.30 / 4.0),  // 4 cal/g
            carbs: Int(cal * 0.40 / 4.0),    // 4 cal/g
            fat: Int(cal * 0.30 / 9.0)       // 9 cal/g
        )
    }
}
