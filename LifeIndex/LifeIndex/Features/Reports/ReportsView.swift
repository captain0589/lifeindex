import SwiftUI

struct ReportsView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var selectedRange: ReportRange = .weekly
    @State private var isGenerating = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Report Range", selection: $selectedRange) {
                        ForEach(ReportRange.allCases) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    ReportPreviewCard(
                        range: selectedRange,
                        summary: healthKitManager.todaySummary
                    )

                    VStack(spacing: 12) {
                        Text("Export")
                            .font(Theme.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            // TODO: Implement PDF generation
                        } label: {
                            Label("Generate PDF Report", systemImage: "doc.richtext")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Theme.tertiaryBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        Button {
                            // TODO: Implement CSV export
                        } label: {
                            Label("Export as CSV", systemImage: "tablecells")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Theme.tertiaryBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Reports")
        }
    }
}

enum ReportRange: String, CaseIterable, Identifiable {
    case weekly, monthly, custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .custom: return "Custom"
        }
    }
}

struct ReportPreviewCard: View {
    let range: ReportRange
    let summary: DailyHealthSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\(range.displayName) Summary")
                    .font(Theme.title)
                Spacer()
                Image(systemName: "doc.text.chart")
                    .foregroundStyle(Theme.accentColor)
            }

            VStack(spacing: 12) {
                ReportMetricRow(icon: "figure.walk", label: "Avg Steps",
                    value: formatMetric(summary.metrics[.steps], format: "%.0f"), color: Theme.steps)
                ReportMetricRow(icon: "heart.fill", label: "Avg Heart Rate",
                    value: formatMetric(summary.metrics[.heartRate], format: "%.0f bpm"), color: Theme.heartRate)
                ReportMetricRow(icon: "bed.double.fill", label: "Avg Sleep",
                    value: formatSleep(summary.metrics[.sleepDuration]), color: Theme.sleep)
                ReportMetricRow(icon: "flame.fill", label: "Avg Calories",
                    value: formatMetric(summary.metrics[.activeCalories], format: "%.0f kcal"), color: Theme.calories)
            }
        }
        .cardStyle()
        .padding(.horizontal)
    }

    private func formatMetric(_ value: Double?, format: String) -> String {
        guard let value else { return "—" }
        return String(format: format, value)
    }

    private func formatSleep(_ minutes: Double?) -> String {
        guard let minutes else { return "—" }
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        return "\(hours)h \(mins)m"
    }
}

struct ReportMetricRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(label)
                .font(Theme.body)
                .foregroundStyle(Theme.secondaryText)

            Spacer()

            Text(value)
                .font(.system(.body, design: .rounded, weight: .semibold))
        }
    }
}
