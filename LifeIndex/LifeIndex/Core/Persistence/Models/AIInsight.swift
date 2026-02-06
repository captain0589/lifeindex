import CoreData

/// Stores AI-generated insights for historical access and weekly summaries
@objc(AIInsight)
public class AIInsight: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var type: String?
    @NSManaged public var shortText: String?
    @NSManaged public var detailedText: String?
    @NSManaged public var score: Int16
    @NSManaged public var metricsJSON: String?
    @NSManaged public var createdAt: Date?
}

extension AIInsight {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<AIInsight> {
        return NSFetchRequest<AIInsight>(entityName: "AIInsight")
    }

    /// The insight type enum value
    var insightType: InsightType? {
        guard let typeString = type else { return nil }
        return InsightType(rawValue: typeString)
    }

    /// Decoded metrics from JSON storage
    var metrics: StoredMetrics? {
        guard let json = metricsJSON,
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(StoredMetrics.self, from: data) else {
            return nil
        }
        return decoded
    }

    /// Set metrics from struct
    func setMetrics(_ metrics: StoredMetrics) {
        if let data = try? JSONEncoder().encode(metrics),
           let json = String(data: data, encoding: .utf8) {
            metricsJSON = json
        }
    }
}

/// Codable metrics for JSON storage in AIInsight
struct StoredMetrics: Codable {
    var sleepMinutes: Double?
    var steps: Double?
    var activeCalories: Double?
    var restingHeartRate: Double?
    var recoveryScore: Int?
    var deepSleepPercent: Int?
    var remSleepPercent: Int?

    init(
        sleepMinutes: Double? = nil,
        steps: Double? = nil,
        activeCalories: Double? = nil,
        restingHeartRate: Double? = nil,
        recoveryScore: Int? = nil,
        deepSleepPercent: Int? = nil,
        remSleepPercent: Int? = nil
    ) {
        self.sleepMinutes = sleepMinutes
        self.steps = steps
        self.activeCalories = activeCalories
        self.restingHeartRate = restingHeartRate
        self.recoveryScore = recoveryScore
        self.deepSleepPercent = deepSleepPercent
        self.remSleepPercent = remSleepPercent
    }
}
