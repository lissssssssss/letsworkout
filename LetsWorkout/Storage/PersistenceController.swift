import CoreData

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    private init() {
        container = NSPersistentContainer(name: "WorkoutRecord")

        let description = NSPersistentStoreDescription()
        let storeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("WorkoutRecord.sqlite")
        description.url = storeURL

        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error {
                print("[Persistence] Failed to load store: \(error)")
            }
        }
    }

    var context: NSManagedObjectContext {
        container.viewContext
    }

    func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("[Persistence] Save failed: \(error)")
        }
    }
}
