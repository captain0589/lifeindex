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
            HKCategoryType(.sleepAnalysis),
            HKCategoryType(.mindfulSession),
            HKWorkoutType.workoutType(),
            HKObjectType.activitySummaryType()
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

    // MARK: - Fetch Today's Data

    func fetchTodaySummary() async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

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
        async let mindful = Self.fetchMindfulOffMain(healthStore: healthStore, start: startOfDay, end: endOfDay)
        async let workoutMins = Self.fetchWorkoutMinutesOffMain(healthStore: healthStore, start: startOfDay, end: endOfDay)

        let r = await (steps, calories, heartRate, hrv, restingHR, bloodOxygen, sleep, mindful, workoutMins)

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
            let workoutFallback = await Self.fetchWorkoutDerivedMetrics(healthStore: healthStore, start: startOfDay, end: endOfDay)
            if metrics[.activeCalories] == nil, let cal = workoutFallback.calories {
                metrics[.activeCalories] = cal
            }
            // Don't override HR from workout — it's exercise HR, not resting/average
        }

        print("[LifeIndex] Today's metrics: \(metrics.mapValues { String(format: "%.1f", $0) })")
        todaySummary = DailyHealthSummary(date: .now, metrics: metrics)
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

            let r = await (steps, hr, cal, sleep)
            if let v = r.0 { metrics[.steps] = v }
            if let v = r.1 { metrics[.heartRate] = v }
            if let v = r.2 { metrics[.activeCalories] = v }
            if let v = r.3 { metrics[.sleepDuration] = v }

            // Fallback: derive calories from workouts for that day
            if metrics[.activeCalories] == nil {
                let wf = await Self.fetchWorkoutDerivedMetrics(healthStore: healthStore, start: startOfDay, end: endOfDay)
                if let c = wf.calories { metrics[.activeCalories] = c }
            }

            dailySummaries.append(DailyHealthSummary(date: startOfDay, metrics: metrics))
        }

        weeklyData = dailySummaries
        print("[LifeIndex] Weekly data: \(weeklyData.map { "\($0.date.shortDayName): \($0.metrics.count) metrics" })")
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
            print("[LifeIndex] Fetched \(recentWorkouts.count) workouts")
        } catch {
            print("[LifeIndex] Error fetching workouts: \(error)")
        }
    }

    // MARK: - Debug: Log Available Data Sources

    func logAvailableSources() async {
        let typesToCheck: [(String, HKSampleType)] = [
            ("Steps", HKQuantityType(.stepCount)),
            ("Heart Rate", HKQuantityType(.heartRate)),
            ("HRV", HKQuantityType(.heartRateVariabilitySDNN)),
            ("Resting HR", HKQuantityType(.restingHeartRate)),
            ("Blood O2", HKQuantityType(.oxygenSaturation)),
            ("Calories", HKQuantityType(.activeEnergyBurned)),
            ("Sleep", HKCategoryType(.sleepAnalysis)),
            ("Workouts", HKWorkoutType.workoutType())
        ]

        for (name, sampleType) in typesToCheck {
            let count = await Self.countSamplesOffMain(healthStore: healthStore, type: sampleType, days: 7)
            print("[LifeIndex] \(name): \(count) samples in last 7 days")
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
