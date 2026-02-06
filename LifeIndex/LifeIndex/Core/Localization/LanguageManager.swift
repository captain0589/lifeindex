import SwiftUI
import Combine

// MARK: - Supported Languages

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case thai = "th"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English (อังกฤษ)"
        case .thai: return "ไทย (Thai)"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .thai: return "🇹🇭"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

// MARK: - Language Manager

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    private let languageKey = "selectedLanguage"

    @Published var currentLanguage: AppLanguage = .english {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
            Bundle.setLanguage(currentLanguage.rawValue)
        }
    }

    private init() {
        // Load stored language preference
        let storedLanguage = UserDefaults.standard.string(forKey: languageKey) ?? "en"
        if let language = AppLanguage(rawValue: storedLanguage) {
            currentLanguage = language
            Bundle.setLanguage(language.rawValue)
        }
    }

    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
    }
}

// MARK: - Bundle Extension for Language Switching

private var bundleKey: UInt8 = 0

class BundleEx: Bundle {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let path = objc_getAssociatedObject(self, &bundleKey) as? String,
              let bundle = Bundle(path: path) else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    static func setLanguage(_ language: String) {
        defer {
            object_setClass(Bundle.main, BundleEx.self)
        }

        objc_setAssociatedObject(
            Bundle.main,
            &bundleKey,
            Bundle.main.path(forResource: language, ofType: "lproj"),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
}

// MARK: - String Extension for Localization

extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }

    func localized(with arguments: CVarArg...) -> String {
        String(format: self.localized, arguments: arguments)
    }
}

// MARK: - Localization Keys

enum L10n {
    // MARK: - Common
    enum Common {
        static let cancel = "common.cancel".localized
        static let save = "common.save".localized
        static let done = "common.done".localized
        static let edit = "common.edit".localized
        static let delete = "common.delete".localized
        static let ok = "common.ok".localized
        static let yes = "common.yes".localized
        static let no = "common.no".localized
        static let loading = "common.loading".localized
        static let error = "common.error".localized
        static let success = "common.success".localized
        static let today = "common.today".localized
        static let yesterday = "common.yesterday".localized
        static let thisWeek = "common.thisWeek".localized
        static let weeklyAvg = "common.weeklyAvg".localized
    }

    // MARK: - Tabs
    enum Tab {
        static let home = "tab.home".localized
        static let fitness = "tab.fitness".localized
        static let food = "tab.food".localized
        static let wellness = "tab.wellness".localized
        static let settings = "tab.settings".localized
    }

    // MARK: - Dashboard
    enum Dashboard {
        static let greeting = "dashboard.greeting".localized
        static let todayScore = "dashboard.todayScore".localized
        static let viewScoreDetails = "dashboard.viewScoreDetails".localized
        static let sleepTitle = "dashboard.sleep".localized
        static let activityTitle = "dashboard.activity".localized
        static let heartTitle = "dashboard.heart".localized
        static let recoveryTitle = "dashboard.recovery".localized
        static let mindfulnessTitle = "dashboard.mindfulness".localized
        static let viewDetails = "dashboard.viewDetails".localized
        static let noData = "dashboard.noData".localized
        static let recentData = "dashboard.recentData".localized
    }

    // MARK: - Sleep
    enum Sleep {
        static let title = "sleep.title".localized
        static let timeAsleep = "sleep.timeAsleep".localized
        static let quality = "sleep.quality".localized
        static let variability = "sleep.variability".localized
        static let regularity = "sleep.regularity".localized
        static let viewDetails = "sleep.viewDetails".localized
        static let hoursUnit = "sleep.hoursUnit".localized
        static let minutesUnit = "sleep.minutesUnit".localized
    }

    // MARK: - Activity
    enum Activity {
        static let title = "activity.title".localized
        static let steps = "activity.steps".localized
        static let calories = "activity.calories".localized
        static let exercise = "activity.exercise".localized
        static let viewDetails = "activity.viewDetails".localized
        static let stepsThisWeek = "activity.stepsThisWeek".localized
        static let caloriesBurned = "activity.caloriesBurned".localized
    }

    // MARK: - Heart
    enum Heart {
        static let title = "heart.title".localized
        static let restingHR = "heart.restingHR".localized
        static let hrv = "heart.hrv".localized
        static let bloodOxygen = "heart.bloodOxygen".localized
        static let viewDetails = "heart.viewDetails".localized
    }

    // MARK: - Food
    enum Food {
        static let title = "food.title".localized
        static let diary = "food.diary".localized
        static let logFood = "food.logFood".localized
        static let caloriesEaten = "food.caloriesEaten".localized
        static let dailyGoal = "food.dailyGoal".localized
        static let remaining = "food.remaining".localized
        static let noMealsLogged = "food.noMealsLogged".localized
        static let whatDidYouEat = "food.whatDidYouEat".localized
        static let estimateCalories = "food.estimateCalories".localized
        static let estimating = "food.estimating".localized
        static let addPhoto = "food.addPhoto".localized
        static let choosePhoto = "food.choosePhoto".localized
        static let removePhoto = "food.removePhoto".localized
        static let calories = "food.calories".localized
        static let protein = "food.protein".localized
        static let carbs = "food.carbs".localized
        static let fat = "food.fat".localized
        static let macrosOptional = "food.macrosOptional".localized
        static let todayEntries = "food.todayEntries".localized
        static let useRecommended = "food.useRecommended".localized
        static let kcal = "food.kcal".localized
        static let grams = "food.grams".localized
    }

    // MARK: - Fitness
    enum Fitness {
        static let title = "fitness.title".localized
        static let recentWorkouts = "fitness.recentWorkouts".localized
        static let noWorkouts = "fitness.noWorkouts".localized
        static let recovery = "fitness.recovery".localized
        static let viewRecoveryDetails = "fitness.viewRecoveryDetails".localized
    }

    // MARK: - Wellness
    enum Wellness {
        static let title = "wellness.title".localized
        static let mood = "wellness.mood".localized
        static let howAreYouFeeling = "wellness.howAreYouFeeling".localized
        static let moodBad = "wellness.mood.bad".localized
        static let moodLow = "wellness.mood.low".localized
        static let moodOkay = "wellness.mood.okay".localized
        static let moodGood = "wellness.mood.good".localized
        static let moodGreat = "wellness.mood.great".localized
        static let journalEntry = "wellness.journalEntry".localized
        static let writeYourThoughts = "wellness.writeYourThoughts".localized
        static let mindfulness = "wellness.mindfulness".localized
    }

    // MARK: - Settings
    enum Settings {
        static let title = "settings.title".localized
        static let profile = "settings.profile".localized
        static let appearance = "settings.appearance".localized
        static let language = "settings.language".localized
        static let colorScheme = "settings.colorScheme".localized
        static let systemDefault = "settings.systemDefault".localized
        static let light = "settings.light".localized
        static let dark = "settings.dark".localized
        static let age = "settings.age".localized
        static let weight = "settings.weight".localized
        static let height = "settings.height".localized
        static let gender = "settings.gender".localized
        static let male = "settings.male".localized
        static let female = "settings.female".localized
        static let activityLevel = "settings.activityLevel".localized
        static let goal = "settings.goal".localized
        static let about = "settings.about".localized
        static let version = "settings.version".localized
        static let privacyPolicy = "settings.privacyPolicy".localized
        static let termsOfService = "settings.termsOfService".localized
        static let sedentary = "settings.sedentary".localized
        static let lightActivity = "settings.lightActivity".localized
        static let moderateActivity = "settings.moderateActivity".localized
        static let activeActivity = "settings.activeActivity".localized
        static let veryActive = "settings.veryActive".localized
        static let loseWeight = "settings.loseWeight".localized
        static let maintainWeight = "settings.maintainWeight".localized
        static let gainWeight = "settings.gainWeight".localized
    }

    // MARK: - Onboarding
    enum Onboarding {
        static let welcome = "onboarding.welcome".localized
        static let welcomeSubtitle = "onboarding.welcomeSubtitle".localized
        static let selectLanguage = "onboarding.selectLanguage".localized
        static let continueButton = "onboarding.continue".localized
        static let getStarted = "onboarding.getStarted".localized
        static let healthPermission = "onboarding.healthPermission".localized
        static let healthPermissionDesc = "onboarding.healthPermissionDesc".localized
        static let allowAccess = "onboarding.allowAccess".localized
    }

    // MARK: - Streak
    enum Streak {
        static let title = "streak.title".localized
        static let dayStreak = "streak.dayStreak".localized
        static let calendar = "streak.calendar".localized
        static let missions = "streak.missions".localized
        static let proTips = "streak.proTips".localized
        static let keepItUp = "streak.keepItUp".localized
    }

    // MARK: - Units
    enum Units {
        static let kcal = "units.kcal".localized
        static let steps = "units.steps".localized
        static let minutes = "units.minutes".localized
        static let hours = "units.hours".localized
        static let bpm = "units.bpm".localized
        static let ms = "units.ms".localized
        static let percent = "units.percent".localized
        static let kg = "units.kg".localized
        static let cm = "units.cm".localized
        static let grams = "units.grams".localized
    }
}
