import SwiftUI

struct DailyScoresSection: View {
    let weeklyScores: [(date: Date, score: Int)]
    let weeklyData: [DailyHealthSummary]
    @State private var selectedDayForDetail: Date? = nil

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
            Label("lifeindex.dailyScores".localized, systemImage: "list.bullet")
                .font(.system(.headline, design: .rounded, weight: .semibold))

            ForEach(weeklyScores.reversed(), id: \ .date) { entry in
                Button {
                    selectedDayForDetail = entry.date
                } label: {
                    HStack {
                        Text(entry.date.relativeDescription)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.primaryText)
                            .frame(width: 90, alignment: .leading)

                        Spacer()

                        Text("\(entry.score)/100")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(scoreColor(entry.score))

                        Text(LifeIndexScoreEngine.label(for: entry.score))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.tertiaryText)
                    }
                }
                .buttonStyle(.plain)

                if entry.date != weeklyScores.first?.date {
                    Divider()
                }
            }
        }
        .cardStyle()
        .sheet(item: $selectedDayForDetail) { date in
            DayDetailSheet(date: date, weeklyData: weeklyData)
        }
    }
}