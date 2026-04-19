import SwiftUI

// MARK: - Score Color Helper

private func scoreColor(for score: Int) -> Color {
    switch score {
    case 75...100: return .green
    case 50..<75:  return Color(red: 0.75, green: 0.72, blue: 0.18)
    case 25..<50:  return .orange
    default:        return .red
    }
}

// MARK: - Monthly Calendar Sheet

struct MonthlyCalendarSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @ObservedObject var viewModel: DashboardViewModel

    @State private var localMonth: Date
    @State private var detailSummary: DailyHealthSummary?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdaySymbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let greg = Calendar(identifier: .gregorian)

    init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
        _localMonth = State(initialValue: viewModel.displayedMonth)
    }

    // MARK: - Computed

    private var monthStart: Date {
        greg.date(from: greg.dateComponents([.year, .month], from: localMonth))!
    }

    private var monthTitle: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        fmt.calendar = greg
        return fmt.string(from: localMonth)
    }

    private var daysInMonth: [Date?] {
        guard let range = greg.range(of: .day, in: .month, for: monthStart) else { return [] }
        let firstWeekday = greg.component(.weekday, from: monthStart) - 1
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in range {
            days.append(greg.date(byAdding: .day, value: day - 1, to: monthStart))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private func score(for date: Date) -> Int? {
        viewModel.monthlyScores.first(where: { greg.isDate($0.date, inSameDayAs: date) })?.score
    }

    private var isCurrentMonth: Bool {
        greg.isDate(localMonth, equalTo: Date(), toGranularity: .month)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 16)

            // Month header
            HStack(spacing: 0) {
                Text(monthTitle)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 6)

                Spacer()

                Button { navigateMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }

                Button { navigateMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isCurrentMonth ? Color.secondary.opacity(0.35) : .primary)
                        .frame(width: 36, height: 36)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
                .disabled(isCurrentMonth)
                .padding(.leading, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            // Weekday labels
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            // Calendar grid
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, dateOrNil in
                    if let date = dateOrNil {
                        DayCell(
                            date: date,
                            score: score(for: date),
                            isToday: greg.isDateInToday(date),
                            isFuture: date > Date(),
                            isSelected: viewModel.selectedCalendarDate.map { greg.isDate($0, inSameDayAs: date) } ?? false
                        )
                        .onTapGesture {
                            guard date <= Date() else { return }
                            if let summary = viewModel.monthlyDetailData.first(where: { greg.isDate($0.date, inSameDayAs: date) }) {
                                detailSummary = summary
                            } else {
                                viewModel.selectedCalendarDate = greg.isDateInToday(date) ? nil : date
                                dismiss()
                            }
                        }
                    } else {
                        Color.clear.frame(height: 64)
                    }
                }
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 16)

            // Bottom row: Today button
            HStack {
                Button {
                    if !isCurrentMonth {
                        navigateToToday()
                    } else {
                        viewModel.selectedCalendarDate = nil
                        dismiss()
                    }
                } label: {
                    Text("Today")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(.label))
                        )
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .onChange(of: localMonth) { _, newMonth in
            Task { await viewModel.loadMonthlyData(for: newMonth) }
        }
        .sheet(item: $detailSummary) { summary in
            CalendarDayDetailSheet(summary: summary) {
                viewModel.selectedCalendarDate = greg.isDateInToday(summary.date) ? nil : summary.date
                dismiss()
            }
        }
    }

    // MARK: - Helpers

    private func navigateMonth(by value: Int) {
        guard let newMonth = greg.date(byAdding: .month, value: value, to: localMonth) else { return }
        let currentMonthStart = greg.date(from: greg.dateComponents([.year, .month], from: Date()))!
        if value > 0 && newMonth > currentMonthStart { return }
        localMonth = newMonth
    }

    private func navigateToToday() {
        localMonth = Date()
        Task { await viewModel.loadMonthlyData(for: Date()) }
    }
}

// MARK: - Day Cell

private struct DayCell: View {
    let date: Date
    let score: Int?
    let isToday: Bool
    let isFuture: Bool
    let isSelected: Bool

    private let greg = Calendar(identifier: .gregorian)

    private var dayNumber: String {
        "\(greg.component(.day, from: date))"
    }

    private var ringColor: Color {
        guard let s = score else { return Color.secondary.opacity(0.25) }
        return scoreColor(for: s)
    }

    private var ringProgress: Double {
        guard let s = score else { return 0 }
        return Double(s) / 100.0
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(
                        isFuture ? Color.secondary.opacity(0.08) : Color.secondary.opacity(0.18),
                        lineWidth: 3.5
                    )

                if !isFuture {
                    if score != nil {
                        Circle()
                            .trim(from: 0, to: ringProgress)
                            .stroke(ringColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    if isToday {
                        Circle()
                            .fill(ringColor.opacity(0.18))
                    }
                }

                // Selected ring overlay
                if isSelected {
                    Circle()
                        .stroke(Color.accentColor, lineWidth: 2)
                        .padding(2)
                }
            }
            .frame(width: 38, height: 38)

            Text(dayNumber)
                .font(.system(size: 12, weight: (isToday || isSelected) ? .bold : .regular, design: .rounded))
                .foregroundStyle(
                    isSelected ? Color.accentColor :
                    isToday ? ringColor :
                    isFuture ? Color.secondary.opacity(0.35) : .primary
                )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
    }
}

#Preview {
    MonthlyCalendarSheet(viewModel: DashboardViewModel())
        .preferredColorScheme(.dark)
}

// MARK: - Calendar Day Detail Sheet

struct CalendarDayDetailSheet: View {
    let summary: DailyHealthSummary
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var score: Int {
        LifeIndexScoreEngine.calculateFinalScore(from: summary)
    }

    private var scoreColor: Color {
        switch score {
        case 75...100: return .green
        case 50..<75:  return Color(red: 0.75, green: 0.72, blue: 0.18)
        case 25..<50:  return .orange
        default:       return .red
        }
    }

    private var sleepMinutes: Double? {
        summary.sleepStages?.totalAsleepMinutes ?? summary.metrics[.sleepDuration]
    }

    private var sleepScore: Int? {
        guard let m = sleepMinutes else { return nil }
        return SleepScoreEngine.calculateScore(sleepMinutes: m, stages: summary.sleepStages)
    }

    private var sleepColor: Color {
        guard let s = sleepScore else { return Theme.sleep }
        switch s {
        case 80...100: return Theme.sleep
        case 60..<80:  return .yellow
        case 40..<60:  return .orange
        default:       return .red
        }
    }

    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.dateFormat = "EEEE, d MMMM yyyy"
        return fmt.string(from: summary.date)
    }

    private func formatSleep(_ minutes: Double) -> String {
        let h = Int(minutes) / 60
        let m = Int(minutes) % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Score ring
                    VStack(spacing: Theme.Spacing.sm) {
                        ZStack {
                            Circle()
                                .stroke(scoreColor.opacity(0.15), lineWidth: 12)
                                .frame(width: 100, height: 100)
                            Circle()
                                .trim(from: 0, to: Double(score) / 100.0)
                                .stroke(scoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                .frame(width: 100, height: 100)
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 2) {
                                Text("\(score)")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(scoreColor)
                                Text(LifeIndexScoreEngine.label(for: score))
                                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                        }
                        Text("LifeIndex Score")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .padding(.top, Theme.Spacing.sm)

                    // Metrics grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                        if let steps = summary.metrics[.steps] {
                            CalendarMetricTile(icon: HealthMetricType.steps.icon,
                                               value: "\(Int(steps))",
                                               title: HealthMetricType.steps.displayName,
                                               color: Theme.steps)
                        }
                        if let cal = summary.metrics[.activeCalories] {
                            CalendarMetricTile(icon: HealthMetricType.activeCalories.icon,
                                               value: "\(Int(cal)) kcal",
                                               title: HealthMetricType.activeCalories.displayName,
                                               color: Theme.calories)
                        }
                        if let hr = summary.metrics[.heartRate] {
                            CalendarMetricTile(icon: HealthMetricType.heartRate.icon,
                                               value: "\(Int(hr)) bpm",
                                               title: HealthMetricType.heartRate.displayName,
                                               color: Theme.heartRate)
                        }
                        if let sm = sleepMinutes {
                            CalendarMetricTile(icon: "moon.fill",
                                               value: formatSleep(sm),
                                               title: "tab.sleep".localized,
                                               color: Theme.sleep)
                        }
                        if let hrv = summary.metrics[.heartRateVariability] {
                            CalendarMetricTile(icon: HealthMetricType.heartRateVariability.icon,
                                               value: "\(Int(hrv)) ms",
                                               title: HealthMetricType.heartRateVariability.displayName,
                                               color: Theme.hrv)
                        }
                        if let spo2 = summary.metrics[.bloodOxygen] {
                            CalendarMetricTile(icon: HealthMetricType.bloodOxygen.icon,
                                               value: String(format: "%.1f%%", spo2 * 100),
                                               title: HealthMetricType.bloodOxygen.displayName,
                                               color: Theme.bloodOxygen)
                        }
                    }
                    .padding(.horizontal)

                    // Sleep stages — reuses SleepStagesBreakdown from SleepTabView
                    if let stages = summary.sleepStages, stages.hasStageData {
                        SleepStagesBreakdown(stages: stages, color: sleepColor)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: Theme.Spacing.lg)
                }
                .padding(.vertical, Theme.Spacing.lg)
            }
            .pageBackground()
            .navigationTitle(formattedDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.done".localized) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onConfirm()
                        dismiss()
                    } label: {
                        Text("calendar.selectDay".localized)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Calendar Metric Tile

private struct CalendarMetricTile: View {
    let icon: String
    let value: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(title)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))
        .shadow(color: Color.black.opacity(0.08), radius: 3, y: 1)
    }
}

