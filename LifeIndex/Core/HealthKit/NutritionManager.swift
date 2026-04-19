import Foundation
import HealthKit
import Combine

@MainActor
class NutritionManager: ObservableObject {
    private let healthStore: HKHealthStore

    @Published var todayConsumedCalories: Double = 0

    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }

    // MARK: - Authorization

    private var writeTypes: Set<HKSampleType> {
        [HKQuantityType(.dietaryEnergyConsumed)]
    }

    private var readTypes: Set<HKObjectType> {
        [HKQuantityType(.dietaryEnergyConsumed)]
    }

    func requestAuthorization() async throws {
        try await healthStore.requestAuthorization(
            toShare: writeTypes,
            read: readTypes
        )
    }

    // MARK: - Write

    func saveDietaryCalories(_ calories: Int, date: Date = .now) async throws {
        let type = HKQuantityType(.dietaryEnergyConsumed)
        let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: Double(calories))
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        try await healthStore.save(sample)
    }

    // MARK: - Read Today's Total

    func fetchTodayConsumedCalories() async {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        let result = await Self.fetchSumOffMain(
            healthStore: healthStore,
            start: start,
            end: end
        )
        todayConsumedCalories = result ?? 0
    }

    nonisolated private static func fetchSumOffMain(
        healthStore: HKHealthStore,
        start: Date,
        end: Date
    ) async -> Double? {
        let type = HKQuantityType(.dietaryEnergyConsumed)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie())
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }
}
