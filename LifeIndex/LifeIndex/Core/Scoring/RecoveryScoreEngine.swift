import Foundation

struct RecoveryScoreEngine {

    static func calculateScore(
        hrv: Double?,
        restingHeartRate: Double?,
        sleepMinutes: Double?,
        hrvBaseline: Double = 50,
        rhrBaseline: Double = 62
    ) -> Int? {
        var components: [(score: Double, weight: Double)] = []

        if let hrv {
            let ratio = hrv / hrvBaseline
            let hrvScore = min(1.0, ratio)
            components.append((hrvScore, 0.40))
        }

        if let restingHeartRate {
            let ratio = rhrBaseline / restingHeartRate
            let rhrScore = min(1.0, ratio)
            components.append((rhrScore, 0.30))
        }

        if let sleepMinutes {
            let idealRange: ClosedRange<Double> = 420...540
            let sleepScore: Double
            if idealRange.contains(sleepMinutes) {
                sleepScore = 1.0
            } else if sleepMinutes < idealRange.lowerBound {
                sleepScore = max(0, sleepMinutes / idealRange.lowerBound)
            } else {
                let excess = sleepMinutes - idealRange.upperBound
                sleepScore = max(0.5, 1.0 - (excess / 180.0))
            }
            components.append((sleepScore, 0.30))
        }

        guard !components.isEmpty else { return nil }

        let totalWeight = components.reduce(0) { $0 + $1.weight }
        let weightedSum = components.reduce(0) { $0 + ($1.score * $1.weight) }
        let normalized = (weightedSum / totalWeight) * 100

        return min(100, max(0, Int(normalized.rounded())))
    }

    static func label(for score: Int) -> String {
        switch score {
        case 80...100: return "recoveryLabel.fullyRecovered".localized
        case 60..<80: return "recoveryLabel.mostlyRecovered".localized
        case 40..<60: return "recoveryLabel.partiallyRecovered".localized
        default: return "recoveryLabel.restRecommended".localized
        }
    }

    static func shouldRest(score: Int) -> Bool {
        score < 40
    }
}
