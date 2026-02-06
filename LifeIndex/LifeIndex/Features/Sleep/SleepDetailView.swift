import SwiftUI

struct SleepDetailView: View {
    let sleepStages: SleepStages

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sleep Stages Detail")
                .font(.headline)
                .padding(.bottom, 8)

            HStack {
                Text("Awake")
                Spacer()
                Text("\(Int(sleepStages.awakeMinutes)) min (\(sleepStages.awakePercent)%)")
            }
            HStack {
                Text("REM")
                Spacer()
                Text("\(Int(sleepStages.remMinutes)) min (\(sleepStages.remPercent)%)")
            }
            HStack {
                Text("Core")
                Spacer()
                Text("\(Int(sleepStages.coreMinutes)) min (\(sleepStages.corePercent)%)")
            }
            HStack {
                Text("Deep")
                Spacer()
                Text("\(Int(sleepStages.deepMinutes)) min (\(sleepStages.deepPercent)%)")
            }
            Divider()
            HStack {
                Text("Total Asleep")
                Spacer()
                Text("\(Int(sleepStages.totalAsleepMinutes)) min")
            }
            HStack {
                Text("Total Time in Bed")
                Spacer()
                Text("\(Int(sleepStages.totalMinutes)) min")
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 2))
        .padding(.horizontal)
    }
}
