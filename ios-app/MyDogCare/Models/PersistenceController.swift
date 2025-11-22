import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        let exampleDogs: [(String, String)] = [
            ("Milo", "Shiba Inu"),
            ("Bella", "Golden Retriever")
        ]

        for dog in exampleDogs {
            let newDog = Dog(context: context)
            newDog.name = dog.0
            newDog.breed = dog.1
            newDog.createdAt = Date()
            newDog.photoId = UUID().uuidString
        }

        do {
            try context.save()
        } catch {
            fatalError("Unresolved error \(error)")
        }

        return controller
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "MyDogCare")

        if inMemory {
            if let description = container.persistentStoreDescriptions.first {
                description.url = URL(fileURLWithPath: "/dev/null")
            }
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
