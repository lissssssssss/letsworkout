import Foundation
import CoreData

final class WorkoutStore {
    static let shared = WorkoutStore()
    private let persistence = PersistenceController.shared

    func save(duration: TimeInterval, averageScore: Float) {
        let context = persistence.context
        let entity = NSEntityDescription.entity(forEntityName: "WorkoutRecordEntity", in: context)!
        let record = NSManagedObject(entity: entity, insertInto: context)

        record.setValue(UUID(), forKey: "id")
        record.setValue(Date(), forKey: "date")
        record.setValue(duration, forKey: "duration")
        record.setValue(averageScore, forKey: "averageScore")

        persistence.save()
    }

    func fetchAll() -> [WorkoutRecordItem] {
        let context = persistence.context
        let request = NSFetchRequest<NSManagedObject>(entityName: "WorkoutRecordEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        do {
            let results = try context.fetch(request)
            return results.compactMap { obj in
                guard let id = obj.value(forKey: "id") as? UUID,
                      let date = obj.value(forKey: "date") as? Date,
                      let duration = obj.value(forKey: "duration") as? TimeInterval,
                      let score = obj.value(forKey: "averageScore") as? Float else { return nil }
                return WorkoutRecordItem(id: id, date: date, duration: duration, averageScore: score)
            }
        } catch {
            return []
        }
    }

    func deleteAll() {
        let context = persistence.context
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "WorkoutRecordEntity")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        try? context.execute(deleteRequest)
        persistence.save()
    }
}
