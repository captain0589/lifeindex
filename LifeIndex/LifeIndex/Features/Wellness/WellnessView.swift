import SwiftUI

struct WellnessView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var todayMood: Int? = nil
    @State private var moodNote: String = ""
    @State private var showMoodLogger = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
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
                .padding(.bottom, 20)
            }
            .navigationTitle("Wellness")
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
    private let moodLabels = ["Bad", "Low", "Okay", "Good", "Great"]

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("How are you feeling?")
                    .font(Theme.headline)
                Spacer()
                if todayMood != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            HStack(spacing: 16) {
                ForEach(0..<5, id: \.self) { index in
                    Button {
                        todayMood = index + 1
                        showLogger = true
                    } label: {
                        VStack(spacing: 4) {
                            Text(moodEmojis[index])
                                .font(.system(size: 32))
                            Text(moodLabels[index])
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            todayMood == index + 1
                                ? Theme.mood.opacity(0.2)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
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
            VStack(spacing: 24) {
                if let mood = selectedMood {
                    Text(moodEmojis[mood - 1])
                        .font(.system(size: 64))
                }

                Text("Add a note (optional)")
                    .font(Theme.headline)

                TextEditor(text: $note)
                    .frame(height: 120)
                    .padding(8)
                    .background(Theme.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Spacer()
            }
            .padding()
            .navigationTitle("Mood Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
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
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text("Mindful Minutes")
                    .font(Theme.headline)
                Text("Today's mindfulness sessions")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer()

            Text("\(Int(minutes)) min")
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
        case 60...: return "Low Stress"
        case 40..<60: return "Moderate"
        case 20..<40: return "Elevated"
        default: return "High Stress"
        }
    }

    private var stressColor: Color {
        switch hrv {
        case 60...: return .green
        case 40..<60: return .yellow
        case 20..<40: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stress Level")
                .font(Theme.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stressLevel)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(stressColor)
                    Text("Based on HRV: \(Int(hrv)) ms")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(stressColor.opacity(0.2), lineWidth: 8)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: min(1.0, hrv / 100.0))
                        .stroke(stressColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))

                    Image(systemName: "brain")
                        .foregroundStyle(stressColor)
                }
            }
        }
        .cardStyle()
    }
}
