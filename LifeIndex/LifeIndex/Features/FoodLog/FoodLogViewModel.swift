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
    @Published var estimationReason: String?  // AI explanation for the estimate
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
        estimationReason = nil

        // Small delay to show loading state
        try? await Task.sleep(for: .milliseconds(300))

        var didEstimate = false

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), supportsAI {
            do {
                let prompt = """
                You are a precise nutrition calculator. Estimate the nutritional content for this food item.

                Food: \(food)

                IMPORTANT GUIDELINES:
                1. If a quantity/portion is specified (e.g., "50g", "1 cup", "2 pieces", "1 serving", "large", "small"), calculate based on that exact amount.
                2. If NO quantity is specified, assume a typical single serving size:
                   - Rice/pasta/noodles: 1 cup cooked (~150g)
                   - Meat/fish: 1 palm-sized portion (~100g)
                   - Fruits: 1 medium piece (~120g)
                   - Drinks: 1 cup/glass (~240ml)
                   - Snacks: 1 small bag/handful (~30g)
                3. For combination meals (e.g., "rice with chicken"), sum up all components.
                4. Consider cooking method: fried adds ~50-100 cal, grilled/steamed is leaner.
                5. For Thai/Asian foods, use authentic nutritional data.

                COMMON PORTION REFERENCES:
                - 1 cup = 240ml liquid, ~150g cooked grain, ~30g dry cereal
                - 1 tablespoon = 15ml/15g
                - 1 teaspoon = 5ml/5g
                - 1 oz = 28g
                - "Large" = 1.5x standard, "Small" = 0.7x standard

                Return ONLY a valid JSON object with this exact format:
                {"calories": <integer>, "protein": <integer grams>, "carbs": <integer grams>, "fat": <integer grams>, "reason": "<brief 1-sentence explanation of the estimate, e.g. 'Based on 1 cup cooked rice (150g) at 130 cal/100g'>"}
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
                    estimationReason = nutrition.reason
                    debugLog("[LifeIndex] Parsed nutrition: \(nutrition), reason: \(nutrition.reason ?? "none")")
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
        var reason: String? = nil
    }

    // MARK: - Fallback Estimation (With Macros)

    private func useFallbackEstimation(for food: String) {
        let foodLower = food.lowercased()

        // Extract weight if mentioned (e.g., "50g", "100 grams", "50 gram")
        let weightMultiplier = extractWeightMultiplier(from: foodLower)

        // Nutrition lookup: (keywords, calories per 100g, protein, carbs, fat)
        let nutritionDatabase: [(keywords: [String], per100g: NutritionEstimate)] = [
            // Breakfast
            (["egg", "fried egg", "scrambled egg", "ไข่ดาว", "ไข่เจียว"], NutritionEstimate(calories: 155, protein: 13, carbs: 1, fat: 11)),
            (["boiled egg", "ไข่ต้ม"], NutritionEstimate(calories: 155, protein: 13, carbs: 1, fat: 11)),
            (["omelette", "omelet"], NutritionEstimate(calories: 154, protein: 11, carbs: 1, fat: 12)),
            (["toast", "bread", "ขนมปัง"], NutritionEstimate(calories: 265, protein: 9, carbs: 49, fat: 3)),
            (["cereal", "cornflakes"], NutritionEstimate(calories: 357, protein: 8, carbs: 84, fat: 1)),
            (["oatmeal", "porridge", "oat", "ข้าวโอ๊ต"], NutritionEstimate(calories: 68, protein: 2, carbs: 12, fat: 1)),
            (["pancake"], NutritionEstimate(calories: 227, protein: 6, carbs: 28, fat: 10)),
            (["waffle"], NutritionEstimate(calories: 291, protein: 8, carbs: 33, fat: 14)),
            (["bacon"], NutritionEstimate(calories: 541, protein: 37, carbs: 1, fat: 42)),
            (["sausage", "ไส้กรอก"], NutritionEstimate(calories: 301, protein: 12, carbs: 2, fat: 27)),
            (["croissant"], NutritionEstimate(calories: 406, protein: 8, carbs: 46, fat: 21)),
            (["bagel"], NutritionEstimate(calories: 257, protein: 10, carbs: 50, fat: 1)),
            (["congee", "โจ๊ก", "ข้าวต้ม"], NutritionEstimate(calories: 46, protein: 1, carbs: 10, fat: 0)),

            // Proteins
            (["chicken breast", "grilled chicken", "อกไก่"], NutritionEstimate(calories: 165, protein: 31, carbs: 0, fat: 4)),
            (["chicken thigh", "สะโพกไก่"], NutritionEstimate(calories: 209, protein: 26, carbs: 0, fat: 11)),
            (["fried chicken", "ไก่ทอด"], NutritionEstimate(calories: 246, protein: 26, carbs: 10, fat: 12)),
            (["steak", "beef steak", "beef", "เนื้อ", "สเต็ก"], NutritionEstimate(calories: 271, protein: 26, carbs: 0, fat: 18)),
            (["salmon", "แซลมอน"], NutritionEstimate(calories: 208, protein: 20, carbs: 0, fat: 13)),
            (["fish", "grilled fish", "white fish", "ปลา"], NutritionEstimate(calories: 96, protein: 21, carbs: 0, fat: 1)),
            (["shrimp", "prawns", "กุ้ง"], NutritionEstimate(calories: 99, protein: 24, carbs: 0, fat: 0)),
            (["tuna", "ทูน่า"], NutritionEstimate(calories: 132, protein: 28, carbs: 0, fat: 1)),
            (["tofu", "เต้าหู้"], NutritionEstimate(calories: 76, protein: 8, carbs: 2, fat: 5)),
            (["pork", "หมู"], NutritionEstimate(calories: 242, protein: 27, carbs: 0, fat: 14)),
            (["ground beef", "minced meat"], NutritionEstimate(calories: 250, protein: 26, carbs: 0, fat: 15)),
            (["duck", "เป็ด"], NutritionEstimate(calories: 337, protein: 19, carbs: 0, fat: 28)),

            // Thai Food / อาหารไทย
            (["pad thai", "ผัดไทย"], NutritionEstimate(calories: 168, protein: 6, carbs: 20, fat: 7)),
            (["tom yum", "ต้มยำ"], NutritionEstimate(calories: 45, protein: 5, carbs: 4, fat: 2)),
            (["green curry", "แกงเขียวหวาน"], NutritionEstimate(calories: 110, protein: 8, carbs: 5, fat: 7)),
            (["red curry", "แกงเผ็ด", "แกงแดง"], NutritionEstimate(calories: 115, protein: 8, carbs: 6, fat: 7)),
            (["massaman curry", "แกงมัสมั่น"], NutritionEstimate(calories: 140, protein: 9, carbs: 10, fat: 8)),
            (["papaya salad", "som tam", "ส้มตำ"], NutritionEstimate(calories: 60, protein: 2, carbs: 12, fat: 1)),
            (["larb", "ลาบ"], NutritionEstimate(calories: 120, protein: 15, carbs: 5, fat: 5)),
            (["kai pad med mamuang", "ไก่ผัดเม็ดมะม่วง"], NutritionEstimate(calories: 180, protein: 15, carbs: 10, fat: 10)),
            (["pad kra pao", "กะเพรา", "ผัดกะเพรา"], NutritionEstimate(calories: 150, protein: 12, carbs: 8, fat: 8)),
            (["pad see ew", "ผัดซีอิ๊ว"], NutritionEstimate(calories: 165, protein: 8, carbs: 22, fat: 5)),
            (["khao pad", "ข้าวผัด"], NutritionEstimate(calories: 163, protein: 4, carbs: 20, fat: 7)),
            (["kao man gai", "ข้าวมันไก่"], NutritionEstimate(calories: 155, protein: 12, carbs: 18, fat: 5)),
            (["moo ping", "หมูปิ้ง"], NutritionEstimate(calories: 220, protein: 22, carbs: 5, fat: 12)),
            (["satay", "สะเต๊ะ"], NutritionEstimate(calories: 200, protein: 20, carbs: 5, fat: 11)),
            (["pad prik", "ผัดพริก"], NutritionEstimate(calories: 140, protein: 12, carbs: 6, fat: 8)),
            (["tom kha", "ต้มข่า"], NutritionEstimate(calories: 90, protein: 6, carbs: 5, fat: 6)),
            (["mango sticky rice", "ข้าวเหนียวมะม่วง"], NutritionEstimate(calories: 200, protein: 3, carbs: 42, fat: 4)),
            (["boat noodles", "ก๋วยเตี๋ยวเรือ"], NutritionEstimate(calories: 130, protein: 8, carbs: 18, fat: 3)),
            (["kuay teow", "ก๋วยเตี๋ยว"], NutritionEstimate(calories: 120, protein: 6, carbs: 20, fat: 2)),

            // Meals (International)
            (["burger", "hamburger", "เบอร์เกอร์"], NutritionEstimate(calories: 295, protein: 17, carbs: 24, fat: 14)),
            (["cheeseburger"], NutritionEstimate(calories: 303, protein: 15, carbs: 26, fat: 14)),
            (["pizza slice", "pizza", "พิซซ่า"], NutritionEstimate(calories: 266, protein: 11, carbs: 33, fat: 10)),
            (["pasta", "spaghetti", "พาสต้า"], NutritionEstimate(calories: 131, protein: 5, carbs: 25, fat: 1)),
            (["rice", "ข้าว", "ข้าวสวย"], NutritionEstimate(calories: 130, protein: 3, carbs: 28, fat: 0)),
            (["fried rice", "ข้าวผัด"], NutritionEstimate(calories: 163, protein: 4, carbs: 20, fat: 7)),
            (["sticky rice", "ข้าวเหนียว"], NutritionEstimate(calories: 97, protein: 2, carbs: 21, fat: 0)),
            (["brown rice", "ข้าวกล้อง"], NutritionEstimate(calories: 111, protein: 3, carbs: 23, fat: 1)),
            (["sandwich", "แซนด์วิช"], NutritionEstimate(calories: 250, protein: 10, carbs: 28, fat: 10)),
            (["wrap", "burrito"], NutritionEstimate(calories: 206, protein: 9, carbs: 24, fat: 8)),
            (["taco"], NutritionEstimate(calories: 226, protein: 9, carbs: 20, fat: 12)),
            (["sushi", "ซูชิ"], NutritionEstimate(calories: 150, protein: 6, carbs: 22, fat: 4)),
            (["ramen", "noodles", "ราเมน"], NutritionEstimate(calories: 436, protein: 10, carbs: 60, fat: 17)),
            (["curry", "แกง"], NutritionEstimate(calories: 125, protein: 10, carbs: 8, fat: 6)),
            (["soup", "ซุป"], NutritionEstimate(calories: 45, protein: 2, carbs: 7, fat: 1)),
            (["salad", "สลัด"], NutritionEstimate(calories: 20, protein: 1, carbs: 4, fat: 0)),
            (["stir fry", "ผัด"], NutritionEstimate(calories: 120, protein: 10, carbs: 8, fat: 6)),
            (["dim sum", "ติ่มซำ"], NutritionEstimate(calories: 160, protein: 7, carbs: 18, fat: 7)),
            (["spring roll", "ปอเปี๊ยะ"], NutritionEstimate(calories: 200, protein: 5, carbs: 25, fat: 9)),
            (["gyoza", "dumpling", "เกี๊ยว"], NutritionEstimate(calories: 180, protein: 7, carbs: 20, fat: 8)),

            // Snacks
            (["potato chips", "chips", "crisps", "potato chip", "มันฝรั่งทอด"], NutritionEstimate(calories: 536, protein: 7, carbs: 53, fat: 35)),
            (["tortilla chips"], NutritionEstimate(calories: 489, protein: 7, carbs: 63, fat: 24)),
            (["popcorn", "ป็อปคอร์น"], NutritionEstimate(calories: 375, protein: 11, carbs: 74, fat: 4)),
            (["nuts", "almonds", "ถั่ว", "อัลมอนด์"], NutritionEstimate(calories: 579, protein: 21, carbs: 22, fat: 50)),
            (["cashews", "cashew", "มะม่วงหิมพานต์"], NutritionEstimate(calories: 553, protein: 18, carbs: 30, fat: 44)),
            (["peanuts", "peanut", "ถั่วลิสง"], NutritionEstimate(calories: 567, protein: 26, carbs: 16, fat: 49)),
            (["chocolate", "candy bar", "ช็อคโกแลต"], NutritionEstimate(calories: 535, protein: 8, carbs: 60, fat: 30)),
            (["cookie", "biscuit", "cookies", "คุกกี้"], NutritionEstimate(calories: 488, protein: 5, carbs: 64, fat: 24)),
            (["donut", "doughnut", "โดนัท"], NutritionEstimate(calories: 452, protein: 5, carbs: 51, fat: 25)),
            (["muffin", "มัฟฟิน"], NutritionEstimate(calories: 377, protein: 5, carbs: 52, fat: 17)),
            (["protein bar"], NutritionEstimate(calories: 350, protein: 20, carbs: 40, fat: 12)),
            (["yogurt", "โยเกิร์ต"], NutritionEstimate(calories: 59, protein: 10, carbs: 4, fat: 0)),
            (["ice cream", "ไอศกรีม"], NutritionEstimate(calories: 207, protein: 4, carbs: 24, fat: 11)),
            (["cheese", "ชีส"], NutritionEstimate(calories: 402, protein: 25, carbs: 1, fat: 33)),
            (["granola bar"], NutritionEstimate(calories: 471, protein: 10, carbs: 64, fat: 20)),
            (["crackers"], NutritionEstimate(calories: 484, protein: 10, carbs: 74, fat: 16)),

            // Fruits
            (["apple", "แอปเปิ้ล"], NutritionEstimate(calories: 52, protein: 0, carbs: 14, fat: 0)),
            (["banana", "กล้วย"], NutritionEstimate(calories: 89, protein: 1, carbs: 23, fat: 0)),
            (["orange", "ส้ม"], NutritionEstimate(calories: 47, protein: 1, carbs: 12, fat: 0)),
            (["grapes", "grape", "องุ่น"], NutritionEstimate(calories: 69, protein: 1, carbs: 18, fat: 0)),
            (["strawberries", "strawberry", "สตรอว์เบอร์รี่"], NutritionEstimate(calories: 32, protein: 1, carbs: 8, fat: 0)),
            (["watermelon", "แตงโม"], NutritionEstimate(calories: 30, protein: 1, carbs: 8, fat: 0)),
            (["mango", "มะม่วง"], NutritionEstimate(calories: 60, protein: 1, carbs: 15, fat: 0)),
            (["avocado", "อะโวคาโด"], NutritionEstimate(calories: 160, protein: 2, carbs: 9, fat: 15)),
            (["blueberries", "blueberry"], NutritionEstimate(calories: 57, protein: 1, carbs: 14, fat: 0)),
            (["pineapple", "สับปะรด"], NutritionEstimate(calories: 50, protein: 1, carbs: 13, fat: 0)),
            (["papaya", "มะละกอ"], NutritionEstimate(calories: 43, protein: 0, carbs: 11, fat: 0)),
            (["durian", "ทุเรียน"], NutritionEstimate(calories: 147, protein: 1, carbs: 27, fat: 5)),
            (["longan", "ลำไย"], NutritionEstimate(calories: 60, protein: 1, carbs: 15, fat: 0)),
            (["lychee", "ลิ้นจี่"], NutritionEstimate(calories: 66, protein: 1, carbs: 17, fat: 0)),
            (["rambutan", "เงาะ"], NutritionEstimate(calories: 68, protein: 1, carbs: 16, fat: 0)),
            (["mangosteen", "มังคุด"], NutritionEstimate(calories: 73, protein: 0, carbs: 18, fat: 1)),
            (["dragon fruit", "แก้วมังกร"], NutritionEstimate(calories: 50, protein: 1, carbs: 11, fat: 0)),
            (["coconut", "มะพร้าว"], NutritionEstimate(calories: 354, protein: 3, carbs: 15, fat: 33)),

            // Drinks
            (["coffee", "black coffee", "กาแฟ"], NutritionEstimate(calories: 2, protein: 0, carbs: 0, fat: 0)),
            (["latte", "cappuccino", "ลาเต้", "คาปูชิโน่"], NutritionEstimate(calories: 56, protein: 3, carbs: 5, fat: 3)),
            (["tea", "ชา"], NutritionEstimate(calories: 1, protein: 0, carbs: 0, fat: 0)),
            (["thai tea", "ชาไทย", "ชาเย็น"], NutritionEstimate(calories: 150, protein: 2, carbs: 30, fat: 3)),
            (["milk", "นม"], NutritionEstimate(calories: 42, protein: 3, carbs: 5, fat: 1)),
            (["soy milk", "นมถั่วเหลือง"], NutritionEstimate(calories: 33, protein: 3, carbs: 2, fat: 2)),
            (["orange juice", "juice", "น้ำส้ม"], NutritionEstimate(calories: 45, protein: 1, carbs: 10, fat: 0)),
            (["smoothie", "สมูทตี้"], NutritionEstimate(calories: 65, protein: 1, carbs: 14, fat: 1)),
            (["soda", "cola", "coke", "โค้ก", "น้ำอัดลม"], NutritionEstimate(calories: 41, protein: 0, carbs: 11, fat: 0)),
            (["beer", "เบียร์"], NutritionEstimate(calories: 43, protein: 0, carbs: 4, fat: 0)),
            (["wine", "ไวน์"], NutritionEstimate(calories: 83, protein: 0, carbs: 3, fat: 0)),
            (["protein shake", "เวย์โปรตีน"], NutritionEstimate(calories: 113, protein: 20, carbs: 5, fat: 2)),
            (["bubble tea", "boba", "ชานมไข่มุก"], NutritionEstimate(calories: 160, protein: 2, carbs: 35, fat: 2)),
            (["coconut water", "น้ำมะพร้าว"], NutritionEstimate(calories: 19, protein: 0, carbs: 4, fat: 0)),
            (["energy drink", "เครื่องดื่มชูกำลัง"], NutritionEstimate(calories: 45, protein: 0, carbs: 11, fat: 0)),

            // Vegetables (commonly tracked)
            (["broccoli", "บร็อคโคลี่"], NutritionEstimate(calories: 34, protein: 3, carbs: 7, fat: 0)),
            (["spinach", "ผักโขม"], NutritionEstimate(calories: 23, protein: 3, carbs: 4, fat: 0)),
            (["carrot", "แครอท"], NutritionEstimate(calories: 41, protein: 1, carbs: 10, fat: 0)),
            (["potato", "มันฝรั่ง"], NutritionEstimate(calories: 77, protein: 2, carbs: 17, fat: 0)),
            (["sweet potato", "มันเทศ"], NutritionEstimate(calories: 86, protein: 2, carbs: 20, fat: 0)),
            (["corn", "ข้าวโพด"], NutritionEstimate(calories: 86, protein: 3, carbs: 19, fat: 1)),
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

                    // Provide reason for the estimate
                    let portionDesc = weightMultiplier != nil ? "specified portion" : "~100g serving"
                    estimationReason = "Based on \(portionDesc) of \(keyword) (\(nutrition.calories) cal/100g)"

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
        estimationReason = "Generic estimate for unrecognized food item"
        debugLog("[LifeIndex] No match found, using default values")
    }

    // MARK: - Extract Weight from Food Description

    private func extractWeightMultiplier(from text: String) -> Double? {
        // Patterns with their conversion to 100g ratio
        let patterns: [(pattern: String, converter: (Double) -> Double)] = [
            // Grams: 50g, 50 g, 50grams → weight / 100
            (#"(\d+(?:\.\d+)?)\s*g(?:ram)?s?\b"#, { $0 / 100.0 }),

            // Ounces: 2oz, 2 oz → weight * 28.35 / 100
            (#"(\d+(?:\.\d+)?)\s*oz"#, { $0 * 28.35 / 100.0 }),

            // Cups (cooked grains ~150g, liquids ~240ml): 1 cup, 2 cups
            (#"(\d+(?:\.\d+)?)\s*cups?\b"#, { $0 * 1.5 }),

            // Tablespoons (~15g): 2 tbsp, 1 tablespoon
            (#"(\d+(?:\.\d+)?)\s*(?:tbsp|tablespoons?)\b"#, { $0 * 0.15 }),

            // Teaspoons (~5g): 1 tsp, 2 teaspoons
            (#"(\d+(?:\.\d+)?)\s*(?:tsp|teaspoons?)\b"#, { $0 * 0.05 }),

            // Pieces/servings (assume ~100g each): 2 pieces, 1 serving
            (#"(\d+)\s*(?:pieces?|servings?|portions?)\b"#, { $0 * 1.0 }),

            // Slices (assume ~30g each for bread, ~100g for pizza)
            (#"(\d+)\s*slices?\b"#, { $0 * 0.5 }),

            // Large/medium/small modifiers
            (#"\blarge\b"#, { _ in 1.5 }),
            (#"\bsmall\b"#, { _ in 0.7 }),
            (#"\bmedium\b"#, { _ in 1.0 }),
            (#"\bhalf\b"#, { _ in 0.5 }),
            (#"\bdouble\b"#, { _ in 2.0 }),

            // Thai portions: จาน (plate), ชาม (bowl), ถ้วย (cup)
            (#"(\d+)\s*(?:จาน|plate)"#, { $0 * 2.0 }),   // 1 plate ~200g
            (#"(\d+)\s*(?:ชาม|bowl)"#, { $0 * 2.5 }),    // 1 bowl ~250g
            (#"(\d+)\s*(?:ถ้วย)"#, { $0 * 1.5 }),        // 1 cup ~150g
        ]

        for (pattern, converter) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {

                // For modifiers without capture groups (large, small, etc.)
                if match.numberOfRanges == 1 {
                    return converter(1.0)
                }

                // For patterns with number capture
                if let range = Range(match.range(at: 1), in: text),
                   let value = Double(text[range]) {
                    return converter(value)
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
                let reason = json["reason"] as? String

                if calories > 0 && calories <= 9999 {
                    return NutritionEstimate(calories: calories, protein: protein, carbs: carbs, fat: fat, reason: reason)
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
