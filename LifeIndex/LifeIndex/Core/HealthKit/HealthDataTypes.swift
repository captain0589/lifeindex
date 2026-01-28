import Foundation
import HealthKit

// MARK: - Health Metric Types

enum HealthMetricType: String, CaseIterable, Identifiable {
    case steps
    case heartRate
    case heartRateVariability
    case restingHeartRate
    case bloodOxygen
    case activeCalories
    case sleepDuration
    case mindfulMinutes
    case workoutMinutes

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .steps: return "Steps"
        case .heartRate: return "Heart Rate"
        case .heartRateVariability: return "HRV"
        case .restingHeartRate: return "Resting HR"
        case .bloodOxygen: return "Blood Oxygen"
        case .activeCalories: return "Active Calories"
        case .sleepDuration: return "Sleep"
        case .mindfulMinutes: return "Mindfulness"
        case .workoutMinutes: return "Workouts"
        }
    }

    var unit: String {
        switch self {
        case .steps: return "steps"
        case .heartRate, .restingHeartRate: return "bpm"
        case .heartRateVariability: return "ms"
        case .bloodOxygen: return "%"
        case .activeCalories: return "kcal"
        case .sleepDuration: return "hrs"
        case .mindfulMinutes, .workoutMinutes: return "min"
        }
    }

    var icon: String {
        switch self {
        case .steps: return "figure.walk"
        case .heartRate: return "heart.fill"
        case .heartRateVariability: return "waveform.path.ecg"
        case .restingHeartRate: return "heart.circle"
        case .bloodOxygen: return "lungs.fill"
        case .activeCalories: return "flame.fill"
        case .sleepDuration: return "bed.double.fill"
        case .mindfulMinutes: return "brain.head.profile"
        case .workoutMinutes: return "figure.run"
        }
    }

    var hkQuantityType: HKQuantityType? {
        switch self {
        case .steps:
            return HKQuantityType(.stepCount)
        case .heartRate:
            return HKQuantityType(.heartRate)
        case .heartRateVariability:
            return HKQuantityType(.heartRateVariabilitySDNN)
        case .restingHeartRate:
            return HKQuantityType(.restingHeartRate)
        case .bloodOxygen:
            return HKQuantityType(.oxygenSaturation)
        case .activeCalories:
            return HKQuantityType(.activeEnergyBurned)
        case .sleepDuration:
            return nil // Sleep uses HKCategoryType
        case .mindfulMinutes:
            return nil // Mindfulness uses HKCategoryType
        case .workoutMinutes:
            return nil // Workouts use HKWorkoutType
        }
    }

    var hkCategoryType: HKCategoryType? {
        switch self {
        case .sleepDuration:
            return HKCategoryType(.sleepAnalysis)
        case .mindfulMinutes:
            return HKCategoryType(.mindfulSession)
        default:
            return nil
        }
    }
}

// MARK: - Health Data Point

struct HealthDataPoint: Identifiable {
    let id = UUID()
    let type: HealthMetricType
    let value: Double
    let date: Date

    var formattedValue: String {
        switch type {
        case .steps:
            return String(format: "%.0f", value)
        case .heartRate, .restingHeartRate:
            return String(format: "%.0f", value)
        case .heartRateVariability:
            return String(format: "%.0f", value)
        case .bloodOxygen:
            return String(format: "%.0f", value * 100)
        case .activeCalories:
            return String(format: "%.0f", value)
        case .sleepDuration:
            let hours = Int(value) / 60
            let minutes = Int(value) % 60
            return "\(hours)h \(minutes)m"
        case .mindfulMinutes, .workoutMinutes:
            return String(format: "%.0f", value)
        }
    }
}

// MARK: - Daily Health Summary

struct DailyHealthSummary: Identifiable {
    let id = UUID()
    let date: Date
    var metrics: [HealthMetricType: Double]
    var lifeIndexScore: Int?

    func value(for metric: HealthMetricType) -> Double? {
        metrics[metric]
    }
}

// MARK: - Workout Data

struct WorkoutData: Identifiable {
    let id = UUID()
    let type: HKWorkoutActivityType
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let calories: Double?
    let distance: Double?
    let heartRateAvg: Double?

    var displayName: String {
        switch type {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .walking: return "Walking"
        case .hiking: return "Hiking"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Strength Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .coreTraining: return "Core Training"
        case .flexibility: return "Flexibility"
        default: return "Workout"
        }
    }

    var icon: String {
        switch type {
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        case .walking: return "figure.walk"
        case .hiking: return "figure.hiking"
        case .yoga: return "figure.yoga"
        case .functionalStrengthTraining: return "figure.strengthtraining.traditional"
        case .highIntensityIntervalTraining: return "figure.highintensity.intervaltraining"
        default: return "figure.mixed.cardio"
        }
    }

    var formattedDuration: String {
        let minutes = Int(duration / 60)
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes) min"
    }
}
