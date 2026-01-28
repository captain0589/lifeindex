import CoreData

@objc(MoodLog)
public class MoodLog: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var mood: Int16
    @NSManaged public var note: String?
    @NSManaged public var date: Date?
}

extension MoodLog {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MoodLog> {
        return NSFetchRequest<MoodLog>(entityName: "MoodLog")
    }

    var moodEmoji: String {
        switch mood {
        case 1: return "😞"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        case 5: return "😄"
        default: return "😐"
        }
    }

    var moodLabel: String {
        switch mood {
        case 1: return "Bad"
        case 2: return "Low"
        case 3: return "Okay"
        case 4: return "Good"
        case 5: return "Great"
        default: return "Unknown"
        }
    }
}
