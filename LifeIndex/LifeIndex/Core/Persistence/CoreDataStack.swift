import CoreData

class CoreDataStack {
    static let shared = CoreDataStack()

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "LifeIndex")
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()

    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    func saveContext() {
        let context = viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Core Data save error: \(error.localizedDescription)")
            }
        }
    }

    func saveMoodLog(mood: Int, note: String?, date: Date = .now) {
        let context = viewContext
        let log = MoodLog(context: context)
        log.id = UUID()
        log.mood = Int16(mood)
        log.note = note
        log.date = date
        saveContext()
    }

    func fetchMoodLogs(for date: Date) -> [MoodLog] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let request: NSFetchRequest<MoodLog> = MoodLog.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        do {
            return try viewContext.fetch(request)
        } catch {
            print("Fetch mood logs error: \(error)")
            return []
        }
    }
}
