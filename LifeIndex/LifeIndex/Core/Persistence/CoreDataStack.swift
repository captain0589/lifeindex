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
                debugLog("Core Data save error: \(error.localizedDescription)")
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
            debugLog("Fetch mood logs error: \(error)")
            return []
        }
    }

    // MARK: - Food Log

    @discardableResult
    func saveFoodLog(name: String?, calories: Int, mealType: MealType, protein: Double = 0, carbs: Double = 0, fat: Double = 0, imageFileName: String? = nil, date: Date = .now) -> FoodLog {
        let context = viewContext
        let log = FoodLog(context: context)
        log.id = UUID()
        log.name = name
        log.calories = Int32(calories)
        log.mealType = mealType.rawValue
        log.protein = protein
        log.carbs = carbs
        log.fat = fat
        log.imageFileName = imageFileName
        log.date = date
        log.syncedToHealthKit = false
        saveContext()
        return log
    }

    func fetchFoodLogs(for date: Date) -> [FoodLog] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let request: NSFetchRequest<FoodLog> = FoodLog.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        do {
            return try viewContext.fetch(request)
        } catch {
            debugLog("Fetch food logs error: \(error)")
            return []
        }
    }

    func deleteFoodLog(_ log: FoodLog) {
        // Delete associated image if exists
        if let imageFileName = log.imageFileName {
            FoodImageManager.shared.deleteImage(fileName: imageFileName)
        }
        viewContext.delete(log)
        saveContext()
    }

    // MARK: - Daily Report

    @discardableResult
    func saveDailyReport(
        date: Date,
        score: Int,
        insights: [StoredInsight],
        aiShortSummary: String? = nil,
        aiDetailedSummary: String? = nil
    ) -> DailyReport {
        let context = viewContext
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        // Check if report already exists for this date
        if let existing = fetchDailyReport(for: startOfDay) {
            existing.score = Int16(score)
            existing.insights = insights
            existing.aiShortSummary = aiShortSummary
            existing.aiDetailedSummary = aiDetailedSummary
            saveContext()
            return existing
        }

        // Create new report
        let report = DailyReport(context: context)
        report.id = UUID()
        report.date = startOfDay
        report.score = Int16(score)
        report.insights = insights
        report.aiShortSummary = aiShortSummary
        report.aiDetailedSummary = aiDetailedSummary
        saveContext()
        return report
    }

    func fetchDailyReport(for date: Date) -> DailyReport? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let request: NSFetchRequest<DailyReport> = DailyReport.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        request.fetchLimit = 1

        do {
            return try viewContext.fetch(request).first
        } catch {
            debugLog("Fetch daily report error: \(error)")
            return nil
        }
    }

    func updateDailyReportAISummary(for date: Date, short: String?, detailed: String?) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        if let report = fetchDailyReport(for: startOfDay) {
            if let short = short {
                report.aiShortSummary = short
            }
            if let detailed = detailed {
                report.aiDetailedSummary = detailed
            }
            saveContext()
        }
    }
}
