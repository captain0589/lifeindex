import CoreData

// MARK: - Meal Type

enum MealType: Int16, CaseIterable, Identifiable {
    case breakfast = 0
    case lunch = 1
    case dinner = 2
    case snack = 3

    var id: Int16 { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        }
    }

    var localizedName: String {
        switch self {
        case .breakfast: return "meal.breakfast".localized
        case .lunch: return "meal.lunch".localized
        case .dinner: return "meal.dinner".localized
        case .snack: return "meal.snack".localized
        }
    }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.fill"
        case .snack: return "carrot.fill"
        }
    }
}

// MARK: - FoodLog Core Data Model

@objc(FoodLog)
public class FoodLog: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var calories: Int32
    @NSManaged public var mealType: Int16
    @NSManaged public var date: Date?
    @NSManaged public var syncedToHealthKit: Bool
    @NSManaged public var protein: Double
    @NSManaged public var carbs: Double
    @NSManaged public var fat: Double
    @NSManaged public var imageFileName: String?
}

extension FoodLog {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<FoodLog> {
        return NSFetchRequest<FoodLog>(entityName: "FoodLog")
    }

    var mealTypeEnum: MealType {
        MealType(rawValue: mealType) ?? .snack
    }
}
