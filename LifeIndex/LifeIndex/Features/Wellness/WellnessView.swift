import SwiftUI

struct WellnessView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var todayMood: Int? = nil
    @State private var moodNote: String = ""
    @State private var showMoodLogger = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    MoodCheckInCard(
                        todayMood: $todayMood,
                        showLogger: $showMoodLogger
                    )

                    if let mindful = healthKitManager.todaySummary.metrics[.mindfulMinutes] {
                        MindfulnessCard(minutes: mindful)
                    }

                    if let hrv = healthKitManager.todaySummary.metrics[.heartRateVariability] {
                        StressIndicatorCard(hrv: hrv)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, Theme.Spacing.lg)
            }
            .pageBackground(showGradient: true, gradientHeight: 300)
            .navigationTitle("wellness.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showMoodLogger) {
                MoodLoggerSheet(
                    selectedMood: $todayMood,
                    note: $moodNote,
                    isPresented: $showMoodLogger
                )
            }
        }
    }
}

struct MoodCheckInCard: View {
    @Binding var todayMood: Int?
    @Binding var showLogger: Bool

    private let moodEmojis = ["😞", "😕", "😐", "🙂", "😄"]
    private var moodLabels: [String] {
        [
            "wellness.mood.bad".localized,
            "wellness.mood.low".localized,
            "wellness.mood.okay".localized,
            "wellness.mood.good".localized,
            "wellness.mood.great".localized
        ]
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            HStack {
                Text("wellness.howAreYouFeeling".localized)
                    .font(Theme.headline)
                Spacer()
                if todayMood != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.success)
                }
            }

            HStack(spacing: Theme.Spacing.lg) {
                ForEach(0..<5, id: \.self) { index in
                    Button {
                        todayMood = index + 1
                        showLogger = true
                    } label: {
                        VStack(spacing: Theme.Spacing.xs) {
                            Text(moodEmojis[index])
                                .font(.system(size: 32))
                            Text(moodLabels[index])
                                .font(.system(size: Theme.FontSize.tiny))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(
                            todayMood == index + 1
                                ? Theme.mood.opacity(0.2)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .cardStyle()
    }
}

struct MoodLoggerSheet: View {
    @Binding var selectedMood: Int?
    @Binding var note: String
    @Binding var isPresented: Bool

    private let moodEmojis = ["😞", "😕", "😐", "🙂", "😄"]

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.xl) {
                if let mood = selectedMood {
                    Text(moodEmojis[mood - 1])
                        .font(.system(size: Theme.FontSize.massive))
                }

                Text("wellness.addNote".localized)
                    .font(Theme.headline)

                TextEditor(text: $note)
                    .frame(height: 120)
                    .padding(Theme.Spacing.sm)
                    .background(Theme.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))

                Spacer()
            }
            .padding()
            .navigationTitle("wellness.moodLog".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel".localized) {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.save".localized) {
                        // TODO: Persist mood log to Core Data
                        isPresented = false
                    }
                    .bold()
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct MindfulnessCard: View {
    let minutes: Double

    var body: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .font(.title2)
                .foregroundStyle(Theme.mindfulness)
                .frame(width: Theme.IconFrame.lg)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("wellness.mindfulMinutes".localized)
                    .font(Theme.headline)
                Text("wellness.todaysMindfulness".localized)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer()

            Text("\(Int(minutes)) " + "units.minutes".localized)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.mindfulness)
        }
        .cardStyle()
    }
}

struct StressIndicatorCard: View {
    let hrv: Double

    private var stressLevel: String {
        switch hrv {
        case 60...: return "wellness.lowStress".localized
        case 40..<60: return "wellness.moderateStress".localized
        case 20..<40: return "wellness.elevatedStress".localized
        default: return "wellness.highStress".localized
        }
    }

    private var stressColor: Color {
        switch hrv {
        case 60...: return Theme.success
        case 40..<60: return Theme.warning
        case 20..<40: return .orange
        default: return Theme.error
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("wellness.stressLevel".localized)
                .font(Theme.headline)

            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(stressLevel)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(stressColor)
                    Text(String(format: "wellness.basedOnHRV".localized, "\(Int(hrv))"))
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(stressColor.opacity(0.2), lineWidth: 8)
                        .frame(width: Theme.ComponentSize.ringMedium, height: Theme.ComponentSize.ringMedium)

                    Circle()
                        .trim(from: 0, to: min(1.0, hrv / 100.0))
                        .stroke(stressColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: Theme.ComponentSize.ringMedium, height: Theme.ComponentSize.ringMedium)
                        .rotationEffect(.degrees(-90))

                    Image(systemName: "brain")
                        .foregroundStyle(stressColor)
                }
            }
        }
        .cardStyle()
    }
}
