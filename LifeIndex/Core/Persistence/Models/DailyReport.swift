import CoreData

/// Stores daily health report data including insights and AI summaries
@objc(DailyReport)
public class DailyReport: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var score: Int16
    @NSManaged public var insightsJSON: String?
    @NSManaged public var aiShortSummary: String?
    @NSManaged public var aiDetailedSummary: String?
}

extension DailyReport {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DailyReport> {
        return NSFetchRequest<DailyReport>(entityName: "DailyReport")
    }

    /// Decoded insights from JSON storage
    var insights: [StoredInsight] {
        get {
            guard let json = insightsJSON,
                  let data = json.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([StoredInsight].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                insightsJSON = json
            }
        }
    }
}

/// Codable insight for JSON storage
struct StoredInsight: Codable, Identifiable {
    var id = UUID()
    let icon: String
    let text: String
    let colorName: String
    let priority: Int

    init(icon: String, text: String, colorName: String, priority: Int) {
        self.icon = icon
        self.text = text
        self.colorName = colorName
        self.priority = priority
    }
}
