import CoreData

/// Owns the CoreData stack. A single shared container is used app-wide; previews and tests
/// get an in-memory store so they never touch disk.
struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        SeedData.insertPreviewData(into: context)
        try? context.save()
        return controller
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Model")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        // Track our own pending-sync changes via `syncState`; remote changes always win on
        // the read side, so history tracking is unnecessary — keep the store lean.
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                // A failed store load is unrecoverable — surfacing it loudly is preferable to
                // silently running with no persistence (which would break offline mode).
                fatalError("Unresolved CoreData error \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// A background context for sync work, configured to merge into the view context automatically.
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
}

private enum SeedData {
    static func insertPreviewData(into context: NSManagedObjectContext) {
        let listing = CachedListing(context: context)
        listing.id = "preview-1"
        listing.title = "Sunny Studio Near Campus"
        listing.summary = "A bright studio five minutes from the quad, fully furnished."
        listing.pricePerMonth = 950
        listing.currencyCode = "USD"
        listing.roomType = RoomType.studio.rawValue
        listing.latitude = 37.8719
        listing.longitude = -122.2585
        listing.address = "123 University Ave, Berkeley, CA"
        listing.distanceToCampusMeters = 450
        listing.amenitiesData = (try? JSONEncoder().encode([Amenity(id: "wifi", name: "WiFi", symbolName: "wifi")])) ?? Data()
        listing.photoURLsData = (try? JSONEncoder().encode([URL(string: "https://example.com/photo.jpg")!])) ?? Data()
        listing.isAvailable = true
        listing.availableFrom = .now
        listing.rating = 4.6
        listing.updatedAt = .now
        listing.lastSyncedAt = .now
    }
}
