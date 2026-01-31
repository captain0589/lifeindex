import SwiftUI
import PhotosUI
import Combine

#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
class FoodLogViewModel: ObservableObject {
    // MARK: - Published State

    @Published var foodDescription: String = ""
    @Published var selectedMealType: MealType = .snack
    @Published var caloriesText: String = ""
    @Published var proteinText: String = ""
    @Published var carbsText: String = ""
    @Published var fatText: String = ""
    @Published var todayLogs: [FoodLog] = []
    @Published var todayTotal: Int = 0
    @Published var isSaving = false

    // AI estimation
    @Published var isEstimating = false
    @Published var estimationSource: String?
    @Published var selectedPhoto: PhotosPickerItem?
    @Published var selectedImage: UIImage?
    @Published var supportsAI: Bool = false

    // MARK: - Private

    private let nutritionManager: NutritionManager

    // MARK: - Computed

    var caloriesInt: Int? { Int(caloriesText) }

    var canSave: Bool {
        guard let cal = caloriesInt else { return false }
        return cal > 0 && cal <= 9999 && !isSaving
    }

    var canEstimate: Bool {
        !foodDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImage != nil
    }

    // MARK: - Init

    init(nutritionManager: NutritionManager) {
        self.nutritionManager = nutritionManager
        checkAIAvailability()
    }

    // MARK: - AI Availability

    private func checkAIAvailability() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let availability = SystemLanguageModel.default.availability
            debugLog("[LifeIndex] Foundation Models availability: \(availability)")
            supportsAI = (availability == .available)
            debugLog("[LifeIndex] supportsAI = \(supportsAI)")
        } else {
            debugLog("[LifeIndex] iOS version < 26.0, Foundation Models not available")
        }
        #else
        debugLog("[LifeIndex] FoundationModels framework not available")
        #endif
    }

    // MARK: - Photo Handling

    func handlePhotoSelection() async {
        guard let item = selectedPhoto else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                selectedImage = image
            }
        } catch {
            debugLog("[LifeIndex] Photo load error: \(error)")
        }
    }

    // MARK: - AI Estimation (Text)

    func estimateCalories() async {
        let food = foodDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !food.isEmpty else {
            debugLog("[LifeIndex] estimateCalories: food description is empty")
            return
        }

        debugLog("[LifeIndex] estimateCalories: starting for '\(food)', supportsAI=\(supportsAI)")
        isEstimating = true
        estimationSource = nil

        // Small delay to show loading state
        try? await Task.sleep(for: .milliseconds(300))

        var didEstimate = false

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), supportsAI {
            do {
                let prompt = """
                Estimate the calories for this food item. Return ONLY a single integer number of kilocalories. No text, no range, just the number.

                Food: \(food)
                """
                debugLog("[LifeIndex] Creating LanguageModelSession...")
                let session = LanguageModelSession()
                debugLog("[LifeIndex] Sending prompt to AI...")
                let response = try await session.respond(to: prompt)
                debugLog("[LifeIndex] AI response: \(response.content)")
                if let cal = parseCalories(from: response.content) {
                    caloriesText = "\(cal)"
                    estimationSource = "AI estimate"
                    debugLog("[LifeIndex] Parsed calories: \(cal)")
                    didEstimate = true
                } else {
                    debugLog("[LifeIndex] Failed to parse calories from response")
                }
            } catch {
                debugLog("[LifeIndex] AI estimation error: \(error)")
            }
        }
        #endif

        // Always use fallback if AI didn't work
        if !didEstimate {
            debugLog("[LifeIndex] Using fallback estimation")
            useFallbackEstimation(for: food)
        }

        isEstimating = false
        debugLog("[LifeIndex] estimateCalories: completed, caloriesText=\(caloriesText)")
    }

    // MARK: - Fallback Estimation (Simple Lookup)

    private func useFallbackEstimation(for food: String) {
        let foodLower = food.lowercased()

        // Simple calorie lookup for common foods
        let calorieEstimates: [(keywords: [String], calories: Int)] = [
            // Breakfast
            (["egg", "fried egg", "scrambled egg"], 90),
            (["boiled egg"], 78),
            (["omelette", "omelet"], 180),
            (["toast", "bread slice"], 80),
            (["cereal", "cornflakes"], 150),
            (["oatmeal", "porridge"], 150),
            (["pancake"], 180),
            (["waffle"], 220),
            (["bacon"], 120),
            (["sausage"], 180),
            (["croissant"], 280),
            (["bagel"], 250),

            // Lunch/Dinner
            (["chicken breast", "grilled chicken"], 165),
            (["chicken thigh"], 210),
            (["fried chicken"], 320),
            (["chicken salad"], 350),
            (["steak", "beef steak"], 400),
            (["burger", "hamburger"], 450),
            (["cheeseburger"], 550),
            (["pizza slice"], 280),
            (["pizza"], 800),
            (["pasta", "spaghetti"], 400),
            (["rice bowl", "rice"], 200),
            (["fried rice"], 350),
            (["salmon"], 280),
            (["fish", "grilled fish"], 200),
            (["shrimp", "prawns"], 100),
            (["soup"], 150),
            (["salad"], 150),
            (["sandwich"], 350),
            (["wrap", "burrito"], 400),
            (["taco"], 200),
            (["sushi"], 300),
            (["ramen", "noodles"], 450),
            (["pad thai"], 400),
            (["curry"], 350),

            // Snacks
            (["apple"], 95),
            (["banana"], 105),
            (["orange"], 62),
            (["grapes"], 70),
            (["strawberries", "strawberry"], 50),
            (["watermelon"], 50),
            (["mango"], 100),
            (["avocado"], 240),
            (["nuts", "almonds", "cashews"], 170),
            (["chips", "crisps"], 150),
            (["chocolate", "candy bar"], 230),
            (["cookie", "biscuit"], 150),
            (["donut", "doughnut"], 250),
            (["muffin"], 350),
            (["protein bar"], 200),
            (["yogurt"], 150),
            (["ice cream"], 270),

            // Drinks
            (["coffee", "black coffee"], 5),
            (["latte", "cappuccino"], 150),
            (["tea"], 2),
            (["milk"], 150),
            (["orange juice", "juice"], 110),
            (["smoothie"], 250),
            (["soda", "cola", "coke"], 140),
            (["beer"], 150),
            (["wine"], 125),
            (["protein shake"], 200),
        ]

        // Find best match
        for (keywords, calories) in calorieEstimates {
            for keyword in keywords {
                if foodLower.contains(keyword) {
                    caloriesText = "\(calories)"
                    estimationSource = "Quick estimate"
                    debugLog("[LifeIndex] Fallback matched '\(keyword)' -> \(calories) kcal")
                    return
                }
            }
        }

        // Default estimate if no match
        caloriesText = "250"
        estimationSource = "Default estimate"
        debugLog("[LifeIndex] No match found, using default 250 kcal")
    }

    // MARK: - AI Estimation (Image)
    // Note: Foundation Models on iOS 26 currently only supports text input.
    // Image-based estimation is not yet available in the public API.
    // For now, photo is stored as visual reference; estimation uses food description text.

    // MARK: - Parse AI Response

    private func parseCalories(from text: String) -> Int? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Try direct integer parse first
        if let value = Int(cleaned) {
            return value > 0 && value <= 9999 ? value : nil
        }
        // Extract first number from response
        let pattern = #"(\d{1,5})"#
        if let match = cleaned.range(of: pattern, options: .regularExpression) {
            let numberStr = String(cleaned[match])
            if let value = Int(numberStr), value > 0, value <= 9999 {
                return value
            }
        }
        return nil
    }

    // MARK: - Data

    func loadTodayLogs() {
        todayLogs = CoreDataStack.shared.fetchFoodLogs(for: .now)
        todayTotal = todayLogs.reduce(0) { $0 + Int($1.calories) }
    }

    // MARK: - Save

    func saveEntry() async {
        guard let calories = caloriesInt, canSave else { return }
        isSaving = true

        // Save image if present
        var imageFileName: String?
        if let image = selectedImage {
            imageFileName = FoodImageManager.shared.saveImage(image)
            debugLog("[LifeIndex] Saved food image: \(imageFileName ?? "nil")")
        }

        let name = foodDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let log = CoreDataStack.shared.saveFoodLog(
            name: name.isEmpty ? nil : name,
            calories: calories,
            mealType: selectedMealType,
            protein: Double(proteinText) ?? 0,
            carbs: Double(carbsText) ?? 0,
            fat: Double(fatText) ?? 0,
            imageFileName: imageFileName
        )

        // Write to HealthKit
        do {
            try await nutritionManager.requestAuthorization()
            try await nutritionManager.saveDietaryCalories(calories)
            log.syncedToHealthKit = true
            CoreDataStack.shared.saveContext()
        } catch {
            debugLog("[LifeIndex] HealthKit dietary write error: \(error)")
        }

        // Refresh
        await nutritionManager.fetchTodayConsumedCalories()
        loadTodayLogs()

        // Play success sound
        SoundManager.shared.playStreakSuccess()

        // Reset form
        foodDescription = ""
        caloriesText = ""
        proteinText = ""
        carbsText = ""
        fatText = ""
        selectedImage = nil
        selectedPhoto = nil
        estimationSource = nil
        isSaving = false
    }

    // MARK: - Delete

    func deleteEntry(_ log: FoodLog) {
        CoreDataStack.shared.deleteFoodLog(log)
        loadTodayLogs()
    }
}
