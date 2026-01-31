import SwiftUI

struct NutritionCard: View {
    let consumedCalories: Double
    let burnedCalories: Double
    let calorieGoal: Double
    let todayLogs: [FoodLog]
    let onLogFood: () -> Void

    private var netCalories: Double {
        consumedCalories - burnedCalories
    }

    private var progress: Double {
        guard calorieGoal > 0 else { return 0 }
        return min(1.0, consumedCalories / calorieGoal)
    }

    private var statusColor: Color {
        if consumedCalories == 0 { return Theme.secondaryText }
        if netCalories <= -100 { return .green }
        if netCalories <= 200 { return .yellow }
        return .red
    }

    private var statusLabel: String {
        if consumedCalories == 0 { return "No meals logged" }
        if netCalories <= -100 { return "Deficit" }
        if netCalories <= 200 { return "On Track" }
        return "Surplus"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            SectionHeader(title: "Nutrition", icon: "fork.knife", color: Theme.calories)

            HStack(spacing: Theme.Spacing.xl) {
                // Calorie ring
                ZStack {
                    Circle()
                        .stroke(Theme.calories.opacity(0.15), lineWidth: 10)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            Theme.calories,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.6), value: progress)

                    VStack(spacing: 2) {
                        Text("\(Int(consumedCalories))")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                        Text("kcal")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .frame(width: 80, height: 80)

                // Stats
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    NutritionStatRow(label: "Consumed", value: "\(Int(consumedCalories))", unit: "kcal", color: Theme.calories)
                    NutritionStatRow(label: "Burned", value: "\(Int(burnedCalories))", unit: "kcal", color: Theme.activity)
                    NutritionStatRow(label: "Net", value: "\(Int(netCalories))", unit: "kcal", color: statusColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Status + goal
            HStack(spacing: Theme.Spacing.sm) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusLabel)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(statusColor)
                Spacer()
                Text("Goal: \(Int(calorieGoal)) kcal")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }

            // Recent entries preview
            if !todayLogs.isEmpty {
                VStack(spacing: Theme.Spacing.xs) {
                    ForEach(todayLogs.prefix(3)) { log in
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: log.mealTypeEnum.icon)
                                .font(.system(size: Theme.IconSize.sm))
                                .foregroundStyle(Theme.calories.opacity(0.7))
                                .frame(width: Theme.IconFrame.sm)
                            Text(log.name ?? log.mealTypeEnum.displayName)
                                .font(.system(.caption, design: .rounded))
                                .lineLimit(1)
                            Spacer()
                            Text("\(log.calories) kcal")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    if todayLogs.count > 3 {
                        Text("+\(todayLogs.count - 3) more")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }

            // Log Food button
            Button(action: onLogFood) {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 11))
                    Text("Log Food")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(Theme.calories)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.calories.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.sm))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// NutritionStatRow is defined in FoodView.swift
