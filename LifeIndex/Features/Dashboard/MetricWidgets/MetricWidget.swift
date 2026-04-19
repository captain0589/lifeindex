import SwiftUI

struct MetricWidget: View {
    let type: HealthMetricType
    let value: Double

    private var color: Color {
        switch type {
        case .steps: return Theme.steps
        case .heartRate: return Theme.heartRate
        case .heartRateVariability: return Theme.hrv
        case .restingHeartRate: return Theme.heartRate
        case .bloodOxygen: return Theme.bloodOxygen
        case .activeCalories: return Theme.calories
        case .sleepDuration: return Theme.sleep
        case .mindfulMinutes: return Theme.mindfulness
        case .workoutMinutes: return Theme.activity
        }
    }

    private var formattedValue: String {
        HealthDataPoint(type: type, value: value, date: .now).formattedValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: type.icon)
                    .font(.system(size: Theme.IconSize.sm, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: Theme.IconFrame.sm)
                Spacer()
            }

            Text(type.displayName)
                .font(Theme.caption)
                .foregroundStyle(Theme.secondaryText)

            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                Text(formattedValue)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.primaryText)

                Text(type.unit)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
