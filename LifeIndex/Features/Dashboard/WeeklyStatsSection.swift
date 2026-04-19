import SwiftUI

struct WeeklyStatsSection: View {
    let weeklyScores: [(date: Date, score: Int)]
    let weeklyAverage: Int?

    private var weeklyMin: Int? { weeklyScores.map(\ .score).min() }
    private var weeklyMax: Int? { weeklyScores.map(\ .score).max() }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label("Weekly Stats", systemImage: "chart.line.uptrend.xyaxis")
                .font(.system(.headline, design: .rounded, weight: .semibold))

            HStack(spacing: Theme.Spacing.xl) {
                if let avg = weeklyAverage {
                    StatTile(label: "Average", value: "\(avg)", color: scoreColor(avg))
                }
                if let min = weeklyMin {
                    StatTile(label: "Low", value: "\(min)", color: .orange)
                }
                if let max = weeklyMax {
                    StatTile(label: "High", value: "\(max)", color: .green)
                }
            }
        }
        .cardStyle()
    }
}