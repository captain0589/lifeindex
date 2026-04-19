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
        case .steps: return "metric.steps".localized
        case .heartRate: return "metric.heartRate".localized
        case .heartRateVariability: return "metric.hrv".localized
        case .restingHeartRate: return "metric.restingHR".localized
        case .bloodOxygen: return "metric.bloodOxygen".localized
        case .activeCalories: return "metric.activeCalories".localized
        case .sleepDuration: return "metric.sleep".localized
        case .mindfulMinutes: return "metric.mindfulness".localized
        case .workoutMinutes: return "metric.workouts".localized
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

// MARK: - Sleep Stages Data

struct SleepStages {
    var awakeMinutes: Double = 0
    var remMinutes: Double = 0
    var coreMinutes: Double = 0
    var deepMinutes: Double = 0

    var totalAsleepMinutes: Double {
        remMinutes + coreMinutes + deepMinutes
    }

    var totalMinutes: Double {
        awakeMinutes + totalAsleepMinutes
    }

    var awakePercent: Int {
        guard totalMinutes > 0 else { return 0 }
        return Int((awakeMinutes / totalMinutes) * 100)
    }

    var remPercent: Int {
        guard totalMinutes > 0 else { return 0 }
        return Int((remMinutes / totalMinutes) * 100)
    }

    var corePercent: Int {
        guard totalMinutes > 0 else { return 0 }
        return Int((coreMinutes / totalMinutes) * 100)
    }

    var deepPercent: Int {
        guard totalMinutes > 0 else { return 0 }
        return Int((deepMinutes / totalMinutes) * 100)
    }

    var hasStageData: Bool {
        remMinutes > 0 || coreMinutes > 0 || deepMinutes > 0
    }

    func formattedDuration(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if hours > 0 {
            return "\(hours)hr \(mins)min"
        }
        return "\(mins)min"
    }
}

// MARK: - Daily Health Summary

struct DailyHealthSummary: Identifiable {
    let id = UUID()
    let date: Date
    var metrics: [HealthMetricType: Double]
    var lifeIndexScore: Int?
    var sleepStages: SleepStages?

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
        case .running: return "workout.type.running".localized
        case .cycling: return "workout.type.cycling".localized
        case .swimming: return "workout.type.swimming".localized
        case .walking: return "workout.type.walking".localized
        case .hiking: return "workout.type.hiking".localized
        case .yoga: return "workout.type.yoga".localized
        case .functionalStrengthTraining: return "workout.type.strength".localized
        case .highIntensityIntervalTraining: return "workout.type.hiit".localized
        case .coreTraining: return "workout.type.core".localized
        case .flexibility: return "workout.type.flexibility".localized
        default: return "workout.type.default".localized
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
