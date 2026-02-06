import Foundation
import HealthKit
import Combine

@MainActor
class HealthKitManager: ObservableObject {
    let healthStore = HKHealthStore()

    @Published var isAuthorized = false
    @Published var todaySummary = DailyHealthSummary(date: .now, metrics: [:])
    @Published var weeklyData: [DailyHealthSummary] = []
    @Published var recentWorkouts: [WorkoutData] = []

    // MARK: - Authorization

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private var readTypes: Set<HKObjectType> {
        let types: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.heartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.oxygenSaturation),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.height),
            HKQuantityType(.bodyMass),
            HKCategoryType(.sleepAnalysis),
            HKCategoryType(.mindfulSession),
            HKWorkoutType.workoutType(),
            HKObjectType.activitySummaryType(),
            HKCharacteristicType(.biologicalSex),
            HKCharacteristicType(.dateOfBirth)
        ]
        return types
    }

    func requestAuthorization() async throws {
        guard isHealthDataAvailable else {
            throw HealthKitError.notAvailable
        }

        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
        isAuthorized = true
    }

    // MARK: - User Characteristics

    struct UserCharacteristics {
        var age: Int?
        var isMale: Bool?
        var heightCm: Double?
        var weightKg: Double?
    }

    func fetchUserCharacteristics() async -> UserCharacteristics {
        var result = UserCharacteristics()

        debugLog("[LifeIndex] Fetching user characteristics from HealthKit...")

        // Biological sex
        do {
            let sexObject = try healthStore.biologicalSex()
            let sex = sexObject.biologicalSex
            debugLog("[LifeIndex] biologicalSex raw value: \(sex.rawValue) (.notSet=0, .female=1, .male=2, .other=3)")
            switch sex {
            case .male: result.isMale = true
            case .female: result.isMale = false
            default: debugLog("[LifeIndex] biologicalSex is .notSet or .other — skipping")
            }
        } catch {
            debugLog("[LifeIndex] ERROR reading biological sex: \(error.localizedDescription)")
        }

        // Date of birth → age
        do {
            let dob = try healthStore.dateOfBirthComponents()
            debugLog("[LifeIndex] dateOfBirthComponents: year=\(dob.year ?? -1), month=\(dob.month ?? -1), day=\(dob.day ?? -1)")
            debugLog("[LifeIndex] Raw DateComponents from HealthKit: \(dob)")

            if let year = dob.year, year > 0 {
                // IMPORTANT: Use Gregorian calendar explicitly!
                // HealthKit returns Gregorian years, but Calendar.current may be Buddhist (Thailand)
                // which would interpret 1994 as Buddhist year 1994 = Gregorian 1451
                var gregorianCalendar = Calendar(identifier: .gregorian)
                gregorianCalendar.timeZone = TimeZone.current

                debugLog("[LifeIndex] Using calendar: \(gregorianCalendar.identifier) (current system: \(Calendar.current.identifier))")

                // Build clean DateComponents
                var birthComponents = DateComponents()
                birthComponents.year = year
                birthComponents.month = dob.month ?? 1
                birthComponents.day = dob.day ?? 1
                debugLog("[LifeIndex] Clean birthComponents: year=\(birthComponents.year ?? -1), month=\(birthComponents.month ?? -1), day=\(birthComponents.day ?? -1)")

                if let birthDate = gregorianCalendar.date(from: birthComponents) {
                    debugLog("[LifeIndex] birthDate created: \(birthDate)")
                    let ageComponents = gregorianCalendar.dateComponents([.year], from: birthDate, to: Date())
                    debugLog("[LifeIndex] ageComponents.year: \(ageComponents.year ?? -999)")
                    if let age = ageComponents.year, age > 0 && age < 150 {
                        result.age = age
                        debugLog("[LifeIndex] ✓ Calculated age: \(age)")
                    } else {
                        debugLog("[LifeIndex] ✗ Age out of range or nil: \(ageComponents.year ?? -999)")
                    }
                } else {
                    debugLog("[LifeIndex] ✗ calendar.date(from: birthComponents) returned nil - using fallback")
                    let currentYear = gregorianCalendar.component(.year, from: Date())
                    let age = currentYear - year
                    debugLog("[LifeIndex] Fallback: currentYear=\(currentYear), birthYear=\(year), age=\(age)")
                    if age > 0 && age < 150 {
                        result.age = age
                        debugLog("[LifeIndex] ✓ Calculated age (year only fallback): \(age)")
                    } else {
                        debugLog("[LifeIndex] ✗ Fallback age out of range: \(age)")
                    }
                }
            } else {
                debugLog("[LifeIndex] Date of birth year is nil or 0 — not set in Health app")
            }
        } catch {
            debugLog("[LifeIndex] ERROR reading date of birth: \(error.localizedDescription)")
        }

        // Height (most recent sample)
        debugLog("[LifeIndex] Fetching height sample...")
        // Use Gregorian calendar for date calculations to avoid Buddhist calendar issues
        var gregorianCal = Calendar(identifier: .gregorian)
        gregorianCal.timeZone = TimeZone.current
        let heightStartDate = gregorianCal.date(byAdding: .year, value: -10, to: Date())!
        let heightEndDate = Date()
        debugLog("[LifeIndex] Height query range: \(heightStartDate) → \(heightEndDate)")

        // First, let's count how many height samples exist
        let heightSampleCount = await Self.countSamplesForTypeOffMain(
            healthStore: healthStore,
            type: HKQuantityType(.height),
            start: heightStartDate,
            end: heightEndDate
        )
        debugLog("[LifeIndex] Height samples found in range: \(heightSampleCount)")

        // Also try fetching ALL height samples (no date filter) to see if any exist
        let allHeightCount = await Self.countAllSamplesForTypeOffMain(
            healthStore: healthStore,
            type: HKQuantityType(.height)
        )
        debugLog("[LifeIndex] Total height samples in HealthKit (all time): \(allHeightCount)")

        if let height = await Self.fetchLatestSampleOffMain(
            healthStore: healthStore,
            type: .height,
            unit: .meterUnit(with: .centi),
            start: heightStartDate,
            end: heightEndDate
        ) {
            result.heightCm = height
            debugLog("[LifeIndex] ✓ Height: \(height) cm")
        } else {
            debugLog("[LifeIndex] ✗ No height sample found in HealthKit")
            debugLog("[LifeIndex]   Possible reasons: 1) No height data entered, 2) Permission not granted for height, 3) Data not synced yet")
        }

        // Weight (most recent sample)
        debugLog("[LifeIndex] Fetching weight sample...")
        let weightStartDate = gregorianCal.date(byAdding: .year, value: -5, to: Date())!
        let weightEndDate = Date()
        debugLog("[LifeIndex] Weight query range: \(weightStartDate) → \(weightEndDate)")

        let weightSampleCount = await Self.countSamplesForTypeOffMain(
            healthStore: healthStore,
            type: HKQuantityType(.bodyMass),
            start: weightStartDate,
            end: weightEndDate
        )
        debugLog("[LifeIndex] Weight samples found in range: \(weightSampleCount)")

        let allWeightCount = await Self.countAllSamplesForTypeOffMain(
            healthStore: healthStore,
            type: HKQuantityType(.bodyMass)
        )
        debugLog("[LifeIndex] Total weight samples in HealthKit (all time): \(allWeightCount)")

        if let weight = await Self.fetchLatestSampleOffMain(
            healthStore: healthStore,
            type: .bodyMass,
            unit: .gramUnit(with: .kilo),
            start: weightStartDate,
            end: weightEndDate
        ) {
            result.weightKg = weight
            debugLog("[LifeIndex] ✓ Weight: \(weight) kg")
        } else {
            debugLog("[LifeIndex] ✗ No weight sample found in HealthKit")
            debugLog("[LifeIndex]   Possible reasons: 1) No weight data entered, 2) Permission not granted for weight, 3) Data not synced yet")
        }

        debugLog("[LifeIndex] Final characteristics: age=\(result.age ?? -1), male=\(result.isMale.map(String.init) ?? "nil"), height=\(result.heightCm ?? -1)cm, weight=\(result.weightKg ?? -1)kg")
        return result
    }

    // MARK: - Fetch Today's Data

    func fetchTodaySummary() async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        debugLog("[LifeIndex] ═══════════════════════════════════════════════════════════")
        debugLog("[LifeIndex] FETCHING TODAY'S HEALTHKIT DATA")
        debugLog("[LifeIndex] Date range: \(startOfDay) → \(endOfDay)")
        debugLog("[LifeIndex] ═══════════════════════════════════════════════════════════")

        var metrics: [HealthMetricType: Double] = [:]

        // Fetch all metrics concurrently
        async let steps = Self.fetchSumOffMain(healthStore: healthStore, type: .stepCount, unit: .count(), start: startOfDay, end: endOfDay)
        async let calories = Self.fetchSumOffMain(healthStore: healthStore, type: .activeEnergyBurned, unit: .kilocalorie(), start: startOfDay, end: endOfDay)

        // For heart rate: try statistics first, fall back to sample query (Garmin writes samples)
        async let heartRate = Self.fetchHeartRateOffMain(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let hrv = Self.fetchLatestSampleOffMain(healthStore: healthStore, type: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), start: startOfDay, end: endOfDay)
        async let restingHR = Self.fetchLatestSampleOffMain(healthStore: healthStore, type: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), start: startOfDay, end: endOfDay)
        async let bloodOxygen = Self.fetchLatestSampleOffMain(healthStore: healthStore, type: .oxygenSaturation, unit: .percent(), start: startOfDay, end: endOfDay)

        async let sleep = Self.fetchSleepOffMain(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let sleepStages = Self.fetchSleepStagesOffMain(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let mindful = Self.fetchMindfulOffMain(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let workoutMins = Self.fetchWorkoutMinutesOffMain(healthStore: healthStore, start: startOfDay, end: endOfDay)

        let r = await (steps, calories, heartRate, hrv, restingHR, bloodOxygen, sleep, mindful, workoutMins)
        let stages = await sleepStages

        // Log raw API responses
        debugLog("[LifeIndex] ───────────────────────────────────────────────────────────")
        debugLog("[LifeIndex] RAW HEALTHKIT API RESPONSES:")
        debugLog("[LifeIndex]   Steps (sum):           \(r.0.map { String(format: "%.0f", $0) } ?? "nil")")
        debugLog("[LifeIndex]   Active Calories (sum): \(r.1.map { String(format: "%.1f", $0) } ?? "nil") kcal")
        debugLog("[LifeIndex]   Heart Rate (avg):      \(r.2.map { String(format: "%.1f", $0) } ?? "nil") bpm")
        debugLog("[LifeIndex]   HRV (latest):          \(r.3.map { String(format: "%.1f", $0) } ?? "nil") ms")
        debugLog("[LifeIndex]   Resting HR (latest):   \(r.4.map { String(format: "%.1f", $0) } ?? "nil") bpm")
        debugLog("[LifeIndex]   Blood O2 (latest):     \(r.5.map { String(format: "%.1f%%", $0 * 100) } ?? "nil")")
        debugLog("[LifeIndex]   Sleep (total):         \(r.6.map { String(format: "%.0f", $0) } ?? "nil") min")
        debugLog("[LifeIndex]   Mindful (total):       \(r.7.map { String(format: "%.1f", $0) } ?? "nil") min")
        debugLog("[LifeIndex]   Workout (total):       \(r.8.map { String(format: "%.1f", $0) } ?? "nil") min")
        debugLog("[LifeIndex] ───────────────────────────────────────────────────────────")

        if let v = r.0 { metrics[.steps] = v }
        if let v = r.1 { metrics[.activeCalories] = v }
        if let v = r.2 { metrics[.heartRate] = v }
        if let v = r.3 { metrics[.heartRateVariability] = v }
        if let v = r.4 { metrics[.restingHeartRate] = v }
        if let v = r.5 { metrics[.bloodOxygen] = v }
        if let v = r.6 { metrics[.sleepDuration] = v }
        if let v = r.7 { metrics[.mindfulMinutes] = v }
        if let v = r.8 { metrics[.workoutMinutes] = v }

        // Fallback: derive some metrics from today's workouts if not found via standard queries
        if metrics[.activeCalories] == nil || metrics[.heartRate] == nil {
            debugLog("[LifeIndex] Using workout fallback for missing metrics...")
            let workoutFallback = await Self.fetchWorkoutDerivedMetrics(healthStore: healthStore, start: startOfDay, end: endOfDay)
            debugLog("[LifeIndex]   Workout-derived calories: \(workoutFallback.calories.map { String(format: "%.1f", $0) } ?? "nil")")
            if metrics[.activeCalories] == nil, let cal = workoutFallback.calories {
                metrics[.activeCalories] = cal
            }
            // Don't override HR from workout — it's exercise HR, not resting/average
        }

        debugLog("[LifeIndex] ───────────────────────────────────────────────────────────")
        debugLog("[LifeIndex] FINAL METRICS MAP: \(metrics.mapValues { String(format: "%.1f", $0) })")
        debugLog("[LifeIndex] SLEEP STAGES: Awake=\(String(format: "%.0f", stages.awakeMinutes))min, REM=\(String(format: "%.0f", stages.remMinutes))min, Core=\(String(format: "%.0f", stages.coreMinutes))min, Deep=\(String(format: "%.0f", stages.deepMinutes))min")
        debugLog("[LifeIndex] ═══════════════════════════════════════════════════════════")
        todaySummary = DailyHealthSummary(date: .now, metrics: metrics, sleepStages: stages.hasStageData ? stages : nil)
    }

    // MARK: - Fetch Weekly Data

    func fetchWeeklyData() async {
        let calendar = Calendar.current
        var dailySummaries: [DailyHealthSummary] = []

        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            var metrics: [HealthMetricType: Double] = [:]

            // Run in parallel per day
            async let steps = Self.fetchSumOffMain(healthStore: healthStore, type: .stepCount, unit: .count(), start: startOfDay, end: endOfDay)
            async let hr = Self.fetchHeartRateOffMain(healthStore: healthStore, start: startOfDay, end: endOfDay)
            async let cal = Self.fetchSumOffMain(healthStore: healthStore, type: .activeEnergyBurned, unit: .kilocalorie(), start: startOfDay, end: endOfDay)
            async let sleep = Self.fetchSleepOffMain(healthStore: healthStore, start: startOfDay, end: endOfDay)
            async let sleepStages = Self.fetchSleepStagesOffMain(healthStore: healthStore, start: startOfDay, end: endOfDay)

            let r = await (steps, hr, cal, sleep)
            let stages = await sleepStages
            if let v = r.0 { metrics[.steps] = v }
            if let v = r.1 { metrics[.heartRate] = v }
            if let v = r.2 { metrics[.activeCalories] = v }
            if let v = r.3 { metrics[.sleepDuration] = v }

            // Fallback: derive calories from workouts for that day
            if metrics[.activeCalories] == nil {
                let wf = await Self.fetchWorkoutDerivedMetrics(healthStore: healthStore, start: startOfDay, end: endOfDay)
                if let c = wf.calories { metrics[.activeCalories] = c }
            }

            dailySummaries.append(DailyHealthSummary(date: startOfDay, metrics: metrics, sleepStages: stages.hasStageData ? stages : nil))
        }

        weeklyData = dailySummaries
        debugLog("[LifeIndex] Weekly data: \(weeklyData.map { "\($0.date.shortDayName): \($0.metrics.count) metrics" })")
    }

    // MARK: - Fetch Workouts

    func fetchRecentWorkouts(limit: Int = 10) async {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.date(byAdding: .month, value: -1, to: Date()),
            end: Date(),
            options: .strictStartDate
        )

        do {
            let samples: [HKSample] = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: HKWorkoutType.workoutType(),
                    predicate: predicate,
                    limit: limit,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: samples ?? [])
                    }
                }
                self.healthStore.execute(query)
            }

            recentWorkouts = samples.compactMap { sample -> WorkoutData? in
                guard let workout = sample as? HKWorkout else { return nil }
                return WorkoutData(
                    type: workout.workoutActivityType,
                    startDate: workout.startDate,
                    endDate: workout.endDate,
                    duration: workout.duration,
                    calories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                    distance: workout.totalDistance?.doubleValue(for: .meter()),
                    heartRateAvg: nil
                )
            }
            debugLog("[LifeIndex] Fetched \(recentWorkouts.count) workouts")
        } catch {
            debugLog("[LifeIndex] Error fetching workouts: \(error)")
        }
    }

    // MARK: - Debug: Log Available Data Sources

    func logAvailableSources() async {
        debugLog("[LifeIndex] ═══════════════════════════════════════════════════════════")
        debugLog("[LifeIndex] SAMPLE COUNTS (last 7 days):")
        debugLog("[LifeIndex] ═══════════════════════════════════════════════════════════")

        let typesToCheck: [(String, HKSampleType)] = [
            ("Steps", HKQuantityType(.stepCount)),
            ("Heart Rate", HKQuantityType(.heartRate)),
            ("HRV", HKQuantityType(.heartRateVariabilitySDNN)),
            ("Resting HR", HKQuantityType(.restingHeartRate)),
            ("Blood O2", HKQuantityType(.oxygenSaturation)),
            ("Calories", HKQuantityType(.activeEnergyBurned)),
            ("Sleep", HKCategoryType(.sleepAnalysis)),
            ("Mindful", HKCategoryType(.mindfulSession)),
            ("Workouts", HKWorkoutType.workoutType()),
            ("Height", HKQuantityType(.height)),
            ("Weight", HKQuantityType(.bodyMass))
        ]

        for (name, sampleType) in typesToCheck {
            let count = await Self.countSamplesOffMain(healthStore: healthStore, type: sampleType, days: 7)
            debugLog("[LifeIndex]   \(name.padding(toLength: 12, withPad: " ", startingAt: 0)): \(count) samples")
        }
        debugLog("[LifeIndex] ═══════════════════════════════════════════════════════════")
    }

    // MARK: - Debug: Log Raw Samples with Source Info

    func logRawSamplesWithSources() async {
        debugLog("[LifeIndex] ═══════════════════════════════════════════════════════════")
        debugLog("[LifeIndex] RAW SAMPLES WITH SOURCE INFO (today)")
        debugLog("[LifeIndex] ═══════════════════════════════════════════════════════════")

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        // Steps samples
        let stepSamples = await Self.fetchQuantitySamplesOffMain(healthStore: healthStore, type: .stepCount, start: startOfDay, end: endOfDay)
        debugLog("[LifeIndex] ─── STEPS (\(stepSamples.count) samples) ───")
        for sample in stepSamples.prefix(5) {
            let value = sample.quantity.doubleValue(for: .count())
            let source = sample.sourceRevision.source.name
            let device = sample.device?.name ?? "unknown device"
            debugLog("[LifeIndex]   \(Int(value)) steps | Source: \(source) | Device: \(device)")
        }
        if stepSamples.count > 5 {
            debugLog("[LifeIndex]   ... and \(stepSamples.count - 5) more samples")
        }

        // Heart Rate samples
        let hrSamples = await Self.fetchQuantitySamplesOffMain(healthStore: healthStore, type: .heartRate, start: startOfDay, end: endOfDay)
        debugLog("[LifeIndex] ─── HEART RATE (\(hrSamples.count) samples) ───")
        for sample in hrSamples.prefix(5) {
            let value = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            let source = sample.sourceRevision.source.name
            let time = sample.startDate.formatted(date: .omitted, time: .shortened)
            debugLog("[LifeIndex]   \(Int(value)) bpm @ \(time) | Source: \(source)")
        }
        if hrSamples.count > 5 {
            debugLog("[LifeIndex]   ... and \(hrSamples.count - 5) more samples")
        }

        // HRV samples
        let hrvSamples = await Self.fetchQuantitySamplesOffMain(healthStore: healthStore, type: .heartRateVariabilitySDNN, start: startOfDay, end: endOfDay)
        debugLog("[LifeIndex] ─── HRV (\(hrvSamples.count) samples) ───")
        for sample in hrvSamples {
            let value = sample.quantity.doubleValue(for: .secondUnit(with: .milli))
            let source = sample.sourceRevision.source.name
            let time = sample.startDate.formatted(date: .omitted, time: .shortened)
            debugLog("[LifeIndex]   \(String(format: "%.1f", value)) ms @ \(time) | Source: \(source)")
        }

        // Resting HR samples
        let restingHRSamples = await Self.fetchQuantitySamplesOffMain(healthStore: healthStore, type: .restingHeartRate, start: startOfDay, end: endOfDay)
        debugLog("[LifeIndex] ─── RESTING HR (\(restingHRSamples.count) samples) ───")
        for sample in restingHRSamples {
            let value = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            let source = sample.sourceRevision.source.name
            debugLog("[LifeIndex]   \(Int(value)) bpm | Source: \(source)")
        }

        // Blood Oxygen samples
        let o2Samples = await Self.fetchQuantitySamplesOffMain(healthStore: healthStore, type: .oxygenSaturation, start: startOfDay, end: endOfDay)
        debugLog("[LifeIndex] ─── BLOOD OXYGEN (\(o2Samples.count) samples) ───")
        for sample in o2Samples {
            let value = sample.quantity.doubleValue(for: .percent()) * 100
            let source = sample.sourceRevision.source.name
            debugLog("[LifeIndex]   \(String(format: "%.1f", value))% | Source: \(source)")
        }

        // Active Calories samples
        let calSamples = await Self.fetchQuantitySamplesOffMain(healthStore: healthStore, type: .activeEnergyBurned, start: startOfDay, end: endOfDay)
        debugLog("[LifeIndex] ─── ACTIVE CALORIES (\(calSamples.count) samples) ───")
        for sample in calSamples.prefix(5) {
            let value = sample.quantity.doubleValue(for: .kilocalorie())
            let source = sample.sourceRevision.source.name
            debugLog("[LifeIndex]   \(String(format: "%.1f", value)) kcal | Source: \(source)")
        }
        if calSamples.count > 5 {
            debugLog("[LifeIndex]   ... and \(calSamples.count - 5) more samples")
        }

        // Sleep samples (look back 12 hours)
        let sleepStart = calendar.date(byAdding: .hour, value: -12, to: startOfDay) ?? startOfDay
        let sleepSamples = await Self.fetchSleepSamplesWithSourceOffMain(healthStore: healthStore, start: sleepStart, end: endOfDay)
        debugLog("[LifeIndex] ─── SLEEP (\(sleepSamples.count) samples) ───")
        for sample in sleepSamples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60
            let source = sample.sourceRevision.source.name
            let valueType = Self.sleepValueName(sample.value)
            let startTime = sample.startDate.formatted(date: .omitted, time: .shortened)
            let endTime = sample.endDate.formatted(date: .omitted, time: .shortened)
            debugLog("[LifeIndex]   \(valueType): \(String(format: "%.0f", duration)) min (\(startTime)-\(endTime)) | Source: \(source)")
        }

        debugLog("[LifeIndex] ═══════════════════════════════════════════════════════════")
    }

    private static func sleepValueName(_ value: Int) -> String {
        switch value {
        case HKCategoryValueSleepAnalysis.inBed.rawValue: return "inBed"
        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue: return "asleepUnspecified"
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue: return "asleepCore"
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue: return "asleepDeep"
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue: return "asleepREM"
        case HKCategoryValueSleepAnalysis.awake.rawValue: return "awake"
        default: return "unknown(\(value))"
        }
    }

    nonisolated private static func fetchSleepSamplesWithSourceOffMain(
        healthStore: HKHealthStore,
        start: Date,
        end: Date
    ) async -> [HKCategorySample] {
        let sleepType = HKCategoryType(.sleepAnalysis)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                let categorySamples = (samples ?? []).compactMap { $0 as? HKCategorySample }
                continuation.resume(returning: categorySamples)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Nonisolated Static Fetch Helpers

    /// Standard sum query (steps, calories)
    nonisolated private static func fetchSumOffMain(
        healthStore: HKHealthStore,
        type: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async -> Double? {
        let quantityType = HKQuantityType(type)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    /// Heart rate: try statistics average first, fall back to sample query average
    /// Garmin writes individual HR samples, not aggregated statistics
    nonisolated private static func fetchHeartRateOffMain(
        healthStore: HKHealthStore,
        start: Date,
        end: Date
    ) async -> Double? {
        let hrType = HKQuantityType(.heartRate)
        let unit = HKUnit.count().unitDivided(by: .minute())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        // Try statistics first
        let statsResult: Double? = await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: hrType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, _ in
                let value = statistics?.averageQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }

        if let result = statsResult { return result }

        // Fallback: manually average HR samples (Garmin, Oura, etc.)
        let samples: [HKQuantitySample] = await fetchQuantitySamplesOffMain(
            healthStore: healthStore, type: .heartRate, start: start, end: end
        )

        guard !samples.isEmpty else { return nil }
        let sum = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: unit) }
        return sum / Double(samples.count)
    }

    /// Fetch the latest single sample for a type (useful for HRV, resting HR, blood O2)
    /// These are often written once per day by Garmin/Oura
    nonisolated private static func fetchLatestSampleOffMain(
        healthStore: HKHealthStore,
        type: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async -> Double? {
        // Try statistics first
        let quantityType = HKQuantityType(type)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let statsResult: Double? = await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, _ in
                let value = statistics?.averageQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }

        if let result = statsResult { return result }

        // Fallback: get the most recent sample
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    /// Fetch raw quantity samples (for manual averaging)
    nonisolated private static func fetchQuantitySamplesOffMain(
        healthStore: HKHealthStore,
        type: HKQuantityTypeIdentifier,
        start: Date,
        end: Date
    ) async -> [HKQuantitySample] {
        let quantityType = HKQuantityType(type)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let quantitySamples = (samples ?? []).compactMap { $0 as? HKQuantitySample }
                continuation.resume(returning: quantitySamples)
            }
            healthStore.execute(query)
        }
    }

    /// Sleep: include inBed (Garmin uses this) plus all asleep stages
    nonisolated private static func fetchSleepOffMain(
        healthStore: HKHealthStore,
        start: Date,
        end: Date
    ) async -> Double? {
        let sleepType = HKCategoryType(.sleepAnalysis)
        // Look back 12 hours — sleep that started the previous evening
        let adjustedStart = Calendar.current.date(byAdding: .hour, value: -12, to: start) ?? start
        let predicate = HKQuery.predicateForSamples(withStart: adjustedStart, end: end, options: .strictStartDate)

        let samples: [HKSample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: samples ?? [])
            }
            healthStore.execute(query)
        }

        let categorySamples = samples.compactMap { $0 as? HKCategorySample }

        // Prefer asleep stages (Apple Watch, some Garmin models)
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]

        let asleepMinutes = categorySamples
            .filter { asleepValues.contains($0.value) }
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 60.0 }

        if asleepMinutes > 0 { return asleepMinutes }

        // Fallback: use inBed samples (Garmin Connect typically writes these)
        let inBedMinutes = categorySamples
            .filter { $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue }
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 60.0 }

        return inBedMinutes > 0 ? inBedMinutes : nil
    }

    /// Sleep Stages: detailed breakdown of sleep phases
    nonisolated private static func fetchSleepStagesOffMain(
        healthStore: HKHealthStore,
        start: Date,
        end: Date
    ) async -> SleepStages {
        let sleepType = HKCategoryType(.sleepAnalysis)
        // Look back 12 hours — sleep that started the previous evening
        let adjustedStart = Calendar.current.date(byAdding: .hour, value: -12, to: start) ?? start
        let predicate = HKQuery.predicateForSamples(withStart: adjustedStart, end: end, options: .strictStartDate)

        let samples: [HKSample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: samples ?? [])
            }
            healthStore.execute(query)
        }

        let categorySamples = samples.compactMap { $0 as? HKCategorySample }

        var stages = SleepStages()

        for sample in categorySamples {
            let minutes = sample.endDate.timeIntervalSince(sample.startDate) / 60.0

            switch sample.value {
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                stages.awakeMinutes += minutes
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                stages.remMinutes += minutes
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                stages.coreMinutes += minutes
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                stages.deepMinutes += minutes
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                // If no stage data, count as core (light) sleep
                stages.coreMinutes += minutes
            default:
                break // Ignore inBed and other values for stages
            }
        }

        return stages
    }

    nonisolated private static func fetchMindfulOffMain(
        healthStore: HKHealthStore,
        start: Date,
        end: Date
    ) async -> Double? {
        let mindfulType = HKCategoryType(.mindfulSession)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let samples: [HKSample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: mindfulType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: samples ?? [])
            }
            healthStore.execute(query)
        }

        let totalMinutes = samples.reduce(0.0) {
            $0 + $1.endDate.timeIntervalSince($1.startDate) / 60.0
        }
        return totalMinutes > 0 ? totalMinutes : nil
    }

    nonisolated private static func fetchWorkoutMinutesOffMain(
        healthStore: HKHealthStore,
        start: Date,
        end: Date
    ) async -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let samples: [HKSample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: samples ?? [])
            }
            healthStore.execute(query)
        }

        let totalMinutes = samples.compactMap { $0 as? HKWorkout }
            .reduce(0.0) { $0 + $1.duration / 60.0 }
        return totalMinutes > 0 ? totalMinutes : nil
    }

    /// Derive calories from workout objects (fallback when activeEnergyBurned has no standalone samples)
    nonisolated private static func fetchWorkoutDerivedMetrics(
        healthStore: HKHealthStore,
        start: Date,
        end: Date
    ) async -> (calories: Double?, avgHR: Double?) {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let samples: [HKSample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: samples ?? [])
            }
            healthStore.execute(query)
        }

        let workouts = samples.compactMap { $0 as? HKWorkout }
        guard !workouts.isEmpty else { return (nil, nil) }

        let totalCalories = workouts.reduce(0.0) {
            $0 + ($1.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0)
        }

        return (
            calories: totalCalories > 0 ? totalCalories : nil,
            avgHR: nil
        )
    }

    /// Count samples for debugging
    nonisolated private static func countSamplesOffMain(
        healthStore: HKHealthStore,
        type: HKSampleType,
        days: Int
    ) async -> Int {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: samples?.count ?? 0)
            }
            healthStore.execute(query)
        }
    }

    /// Count samples with specific date range
    nonisolated private static func countSamplesForTypeOffMain(
        healthStore: HKHealthStore,
        type: HKSampleType,
        start: Date,
        end: Date
    ) async -> Int {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: samples?.count ?? 0)
            }
            healthStore.execute(query)
        }
    }

    /// Count ALL samples for a type (no date filter) - to check if any data exists at all
    nonisolated private static func countAllSamplesForTypeOffMain(
        healthStore: HKHealthStore,
        type: HKSampleType
    ) async -> Int {
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: samples?.count ?? 0)
            }
            healthStore.execute(query)
        }
    }
}

// MARK: - Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationFailed

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Health data is not available on this device."
        case .authorizationFailed:
            return "Failed to authorize HealthKit access."
        }
    }
}
