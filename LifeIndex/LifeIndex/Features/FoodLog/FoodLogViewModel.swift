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
    @Published var didSave = false

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
                Estimate the nutritional information for this food. Consider portion size if mentioned (e.g., "50g", "100 grams", "1 cup").

                Food: \(food)

                Return ONLY a JSON object with these integer values, no other text:
                {"calories": <number>, "protein": <grams>, "carbs": <grams>, "fat": <grams>}

                Be accurate based on standard nutritional databases. If a weight is specified, calculate accordingly.
                """
                debugLog("[LifeIndex] Creating LanguageModelSession...")
                let session = LanguageModelSession()
                debugLog("[LifeIndex] Sending prompt to AI...")
                let response = try await session.respond(to: prompt)
                debugLog("[LifeIndex] AI response: \(response.content)")
                if let nutrition = parseNutrition(from: response.content) {
                    caloriesText = "\(nutrition.calories)"
                    proteinText = "\(nutrition.protein)"
                    carbsText = "\(nutrition.carbs)"
                    fatText = "\(nutrition.fat)"
                    estimationSource = "AI estimate"
                    debugLog("[LifeIndex] Parsed nutrition: \(nutrition)")
                    didEstimate = true
                } else {
                    debugLog("[LifeIndex] Failed to parse nutrition from response")
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

    // MARK: - Nutrition Data Structure

    private struct NutritionEstimate {
        let calories: Int
        let protein: Int
        let carbs: Int
        let fat: Int
    }

    // MARK: - Fallback Estimation (With Macros)

    private func useFallbackEstimation(for food: String) {
        let foodLower = food.lowercased()

        // Extract weight if mentioned (e.g., "50g", "100 grams", "50 gram")
        let weightMultiplier = extractWeightMultiplier(from: foodLower)

        // Nutrition lookup: (keywords, calories per 100g, protein, carbs, fat)
        let nutritionDatabase: [(keywords: [String], per100g: NutritionEstimate)] = [
            // Breakfast
            (["egg", "fried egg", "scrambled egg"], NutritionEstimate(calories: 155, protein: 13, carbs: 1, fat: 11)),
            (["boiled egg"], NutritionEstimate(calories: 155, protein: 13, carbs: 1, fat: 11)),
            (["omelette", "omelet"], NutritionEstimate(calories: 154, protein: 11, carbs: 1, fat: 12)),
            (["toast", "bread"], NutritionEstimate(calories: 265, protein: 9, carbs: 49, fat: 3)),
            (["cereal", "cornflakes"], NutritionEstimate(calories: 357, protein: 8, carbs: 84, fat: 1)),
            (["oatmeal", "porridge", "oat"], NutritionEstimate(calories: 68, protein: 2, carbs: 12, fat: 1)),
            (["pancake"], NutritionEstimate(calories: 227, protein: 6, carbs: 28, fat: 10)),
            (["waffle"], NutritionEstimate(calories: 291, protein: 8, carbs: 33, fat: 14)),
            (["bacon"], NutritionEstimate(calories: 541, protein: 37, carbs: 1, fat: 42)),
            (["sausage"], NutritionEstimate(calories: 301, protein: 12, carbs: 2, fat: 27)),
            (["croissant"], NutritionEstimate(calories: 406, protein: 8, carbs: 46, fat: 21)),
            (["bagel"], NutritionEstimate(calories: 257, protein: 10, carbs: 50, fat: 1)),

            // Proteins
            (["chicken breast", "grilled chicken"], NutritionEstimate(calories: 165, protein: 31, carbs: 0, fat: 4)),
            (["chicken thigh"], NutritionEstimate(calories: 209, protein: 26, carbs: 0, fat: 11)),
            (["fried chicken"], NutritionEstimate(calories: 246, protein: 26, carbs: 10, fat: 12)),
            (["steak", "beef steak", "beef"], NutritionEstimate(calories: 271, protein: 26, carbs: 0, fat: 18)),
            (["salmon"], NutritionEstimate(calories: 208, protein: 20, carbs: 0, fat: 13)),
            (["fish", "grilled fish", "white fish"], NutritionEstimate(calories: 96, protein: 21, carbs: 0, fat: 1)),
            (["shrimp", "prawns"], NutritionEstimate(calories: 99, protein: 24, carbs: 0, fat: 0)),
            (["tuna"], NutritionEstimate(calories: 132, protein: 28, carbs: 0, fat: 1)),
            (["tofu"], NutritionEstimate(calories: 76, protein: 8, carbs: 2, fat: 5)),

            // Meals
            (["burger", "hamburger"], NutritionEstimate(calories: 295, protein: 17, carbs: 24, fat: 14)),
            (["cheeseburger"], NutritionEstimate(calories: 303, protein: 15, carbs: 26, fat: 14)),
            (["pizza slice", "pizza"], NutritionEstimate(calories: 266, protein: 11, carbs: 33, fat: 10)),
            (["pasta", "spaghetti"], NutritionEstimate(calories: 131, protein: 5, carbs: 25, fat: 1)),
            (["rice"], NutritionEstimate(calories: 130, protein: 3, carbs: 28, fat: 0)),
            (["fried rice"], NutritionEstimate(calories: 163, protein: 4, carbs: 20, fat: 7)),
            (["sandwich"], NutritionEstimate(calories: 250, protein: 10, carbs: 28, fat: 10)),
            (["wrap", "burrito"], NutritionEstimate(calories: 206, protein: 9, carbs: 24, fat: 8)),
            (["taco"], NutritionEstimate(calories: 226, protein: 9, carbs: 20, fat: 12)),
            (["sushi"], NutritionEstimate(calories: 150, protein: 6, carbs: 22, fat: 4)),
            (["ramen", "noodles"], NutritionEstimate(calories: 436, protein: 10, carbs: 60, fat: 17)),
            (["pad thai"], NutritionEstimate(calories: 168, protein: 6, carbs: 20, fat: 7)),
            (["curry"], NutritionEstimate(calories: 125, protein: 10, carbs: 8, fat: 6)),
            (["soup"], NutritionEstimate(calories: 45, protein: 2, carbs: 7, fat: 1)),
            (["salad"], NutritionEstimate(calories: 20, protein: 1, carbs: 4, fat: 0)),

            // Snacks
            (["potato chips", "chips", "crisps", "potato chip"], NutritionEstimate(calories: 536, protein: 7, carbs: 53, fat: 35)),
            (["tortilla chips"], NutritionEstimate(calories: 489, protein: 7, carbs: 63, fat: 24)),
            (["popcorn"], NutritionEstimate(calories: 375, protein: 11, carbs: 74, fat: 4)),
            (["nuts", "almonds"], NutritionEstimate(calories: 579, protein: 21, carbs: 22, fat: 50)),
            (["cashews", "cashew"], NutritionEstimate(calories: 553, protein: 18, carbs: 30, fat: 44)),
            (["peanuts", "peanut"], NutritionEstimate(calories: 567, protein: 26, carbs: 16, fat: 49)),
            (["chocolate", "candy bar"], NutritionEstimate(calories: 535, protein: 8, carbs: 60, fat: 30)),
            (["cookie", "biscuit", "cookies"], NutritionEstimate(calories: 488, protein: 5, carbs: 64, fat: 24)),
            (["donut", "doughnut"], NutritionEstimate(calories: 452, protein: 5, carbs: 51, fat: 25)),
            (["muffin"], NutritionEstimate(calories: 377, protein: 5, carbs: 52, fat: 17)),
            (["protein bar"], NutritionEstimate(calories: 350, protein: 20, carbs: 40, fat: 12)),
            (["yogurt"], NutritionEstimate(calories: 59, protein: 10, carbs: 4, fat: 0)),
            (["ice cream"], NutritionEstimate(calories: 207, protein: 4, carbs: 24, fat: 11)),
            (["cheese"], NutritionEstimate(calories: 402, protein: 25, carbs: 1, fat: 33)),

            // Fruits
            (["apple"], NutritionEstimate(calories: 52, protein: 0, carbs: 14, fat: 0)),
            (["banana"], NutritionEstimate(calories: 89, protein: 1, carbs: 23, fat: 0)),
            (["orange"], NutritionEstimate(calories: 47, protein: 1, carbs: 12, fat: 0)),
            (["grapes", "grape"], NutritionEstimate(calories: 69, protein: 1, carbs: 18, fat: 0)),
            (["strawberries", "strawberry"], NutritionEstimate(calories: 32, protein: 1, carbs: 8, fat: 0)),
            (["watermelon"], NutritionEstimate(calories: 30, protein: 1, carbs: 8, fat: 0)),
            (["mango"], NutritionEstimate(calories: 60, protein: 1, carbs: 15, fat: 0)),
            (["avocado"], NutritionEstimate(calories: 160, protein: 2, carbs: 9, fat: 15)),
            (["blueberries", "blueberry"], NutritionEstimate(calories: 57, protein: 1, carbs: 14, fat: 0)),

            // Drinks
            (["coffee", "black coffee"], NutritionEstimate(calories: 2, protein: 0, carbs: 0, fat: 0)),
            (["latte", "cappuccino"], NutritionEstimate(calories: 56, protein: 3, carbs: 5, fat: 3)),
            (["tea"], NutritionEstimate(calories: 1, protein: 0, carbs: 0, fat: 0)),
            (["milk"], NutritionEstimate(calories: 42, protein: 3, carbs: 5, fat: 1)),
            (["orange juice", "juice"], NutritionEstimate(calories: 45, protein: 1, carbs: 10, fat: 0)),
            (["smoothie"], NutritionEstimate(calories: 65, protein: 1, carbs: 14, fat: 1)),
            (["soda", "cola", "coke"], NutritionEstimate(calories: 41, protein: 0, carbs: 11, fat: 0)),
            (["beer"], NutritionEstimate(calories: 43, protein: 0, carbs: 4, fat: 0)),
            (["wine"], NutritionEstimate(calories: 83, protein: 0, carbs: 3, fat: 0)),
            (["protein shake"], NutritionEstimate(calories: 113, protein: 20, carbs: 5, fat: 2)),
        ]

        // Find best match
        for (keywords, nutrition) in nutritionDatabase {
            for keyword in keywords {
                if foodLower.contains(keyword) {
                    // Calculate based on weight or use standard serving
                    let multiplier = weightMultiplier ?? 1.0 // Default to 100g equivalent
                    let adjustedCalories = Int(Double(nutrition.calories) * multiplier)
                    let adjustedProtein = Int(Double(nutrition.protein) * multiplier)
                    let adjustedCarbs = Int(Double(nutrition.carbs) * multiplier)
                    let adjustedFat = Int(Double(nutrition.fat) * multiplier)

                    caloriesText = "\(adjustedCalories)"
                    proteinText = "\(adjustedProtein)"
                    carbsText = "\(adjustedCarbs)"
                    fatText = "\(adjustedFat)"
                    estimationSource = "Quick estimate"
                    debugLog("[LifeIndex] Fallback matched '\(keyword)' -> \(adjustedCalories) kcal (multiplier: \(multiplier))")
                    return
                }
            }
        }

        // Default estimate if no match
        caloriesText = "250"
        proteinText = "10"
        carbsText = "30"
        fatText = "10"
        estimationSource = "Default estimate"
        debugLog("[LifeIndex] No match found, using default values")
    }

    // MARK: - Extract Weight from Food Description

    private func extractWeightMultiplier(from text: String) -> Double? {
        // Match patterns like "50g", "50 g", "50 grams", "50gram", "100g"
        let patterns = [
            #"(\d+)\s*g(?:ram)?s?\b"#,  // 50g, 50 g, 50grams, 50 grams
            #"(\d+)\s*oz"#,              // 2oz, 2 oz (ounces)
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text),
               let weight = Double(text[range]) {

                if pattern.contains("oz") {
                    // Convert ounces to grams (1 oz = 28.35g), then to 100g ratio
                    return (weight * 28.35) / 100.0
                } else {
                    // Grams - return ratio to 100g
                    return weight / 100.0
                }
            }
        }

        return nil // No weight specified, will use default serving
    }

    // MARK: - AI Estimation (Image)
    // Note: Foundation Models on iOS 26 currently only supports text input.
    // Image-based estimation is not yet available in the public API.
    // For now, photo is stored as visual reference; estimation uses food description text.

    // MARK: - Parse AI Response

    private func parseNutrition(from text: String) -> NutritionEstimate? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to extract JSON from response
        guard let jsonStart = cleaned.firstIndex(of: "{"),
              let jsonEnd = cleaned.lastIndex(of: "}") else {
            debugLog("[LifeIndex] No JSON found in response")
            return nil
        }

        let jsonString = String(cleaned[jsonStart...jsonEnd])

        guard let jsonData = jsonString.data(using: .utf8) else {
            debugLog("[LifeIndex] Failed to convert JSON string to data")
            return nil
        }

        do {
            if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                let calories = (json["calories"] as? Int) ?? Int(json["calories"] as? Double ?? 0)
                let protein = (json["protein"] as? Int) ?? Int(json["protein"] as? Double ?? 0)
                let carbs = (json["carbs"] as? Int) ?? Int(json["carbs"] as? Double ?? 0)
                let fat = (json["fat"] as? Int) ?? Int(json["fat"] as? Double ?? 0)

                if calories > 0 && calories <= 9999 {
                    return NutritionEstimate(calories: calories, protein: protein, carbs: carbs, fat: fat)
                }
            }
        } catch {
            debugLog("[LifeIndex] JSON parsing error: \(error)")
        }

        return nil
    }

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

        // Signal save complete (sheet will dismiss)
        isSaving = false
        didSave = true
    }

    // MARK: - Delete

    func deleteEntry(_ log: FoodLog) {
        CoreDataStack.shared.deleteFoodLog(log)
        loadTodayLogs()
    }
}
