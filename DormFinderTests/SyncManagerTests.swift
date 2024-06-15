import XCTest
@testable import DormFinder

@MainActor
final class SyncManagerTests: XCTestCase {
    private func makeSyncManager(bookings: [Booking] = []) -> (SyncManager, MockBookingService, PersistenceController) {
        let persistence = PersistenceController(inMemory: true)
        let listingService = MockListingService()
        let bookingService = MockBookingService()
        bookingService.bookingsToReturn = bookings
        let monitor = NetworkMonitor()

        let syncManager = SyncManager(
            persistence: persistence,
            listingService: listingService,
            bookingService: bookingService,
            networkMonitor: monitor
        )
        return (syncManager, bookingService, persistence)
    }

    /// A locally-edited booking with a stale version should be overwritten by the server's
    /// newer version — the documented last-write-wins-by-version merge policy.
    func test_refreshBookings_serverWithHigherVersion_overwritesPendingLocalEdit() async throws {
        let (syncManager, bookingService, persistence) = makeSyncManager()

        let context = persistence.newBackgroundContext()
        try await context.perform {
            let local = CachedBooking(context: context)
            local.applyServerState(.stub(id: "booking-1", status: .pending, version: 1))
            local.syncState = SyncState.pendingUpdate.rawValue
            try context.save()
        }

        bookingService.bookingsToReturn = [.stub(id: "booking-1", status: .confirmed, version: 3)]

        await syncManager.syncAll()

        let merged = syncManager.cachedBookings().first { $0.id == "booking-1" }
        XCTAssertEqual(merged?.status, .confirmed, "Server's higher-versioned state should win")
        XCTAssertEqual(merged?.version, 3)
    }

    /// A pending local edit with a version ahead of (or equal to) what the server returns
    /// should be preserved so it can be pushed up on the next sync pass.
    func test_refreshBookings_pendingLocalEditNewerThanServer_isPreserved() async throws {
        let (syncManager, bookingService, persistence) = makeSyncManager()

        let context = persistence.newBackgroundContext()
        try await context.perform {
            let local = CachedBooking(context: context)
            local.applyServerState(.stub(id: "booking-2", status: .cancelled, version: 5))
            local.syncState = SyncState.pendingUpdate.rawValue
            try context.save()
        }

        bookingService.bookingsToReturn = [.stub(id: "booking-2", status: .confirmed, version: 4)]

        await syncManager.syncAll()

        let merged = syncManager.cachedBookings().first { $0.id == "booking-2" }
        XCTAssertEqual(merged?.status, .cancelled, "Local edit should win until the server catches up")
    }

    func test_createBooking_queuesPendingCreate_whenOffline() async throws {
        let persistence = PersistenceController(inMemory: true)
        let listingService = MockListingService()
        let bookingService = MockBookingService()
        bookingService.errorToThrow = NetworkError.offline
        let monitor = NetworkMonitor()
        let syncManager = SyncManager(persistence: persistence, listingService: listingService, bookingService: bookingService, networkMonitor: monitor)

        let request = BookingRequest(listingID: "listing-1", checkIn: .now, checkOut: .now.addingTimeInterval(86_400))
        _ = try await syncManager.createBooking(request, listingTitle: "Test Listing", userID: "user-1")

        let cached = syncManager.cachedBookings()
        XCTAssertEqual(cached.count, 1)
        XCTAssertEqual(cached.first?.status, .pending)
    }

    func test_cancelBooking_marksForDeletionAndHidesFromCache() async throws {
        let (syncManager, _, persistence) = makeSyncManager()
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let local = CachedBooking(context: context)
            local.applyServerState(.stub(id: "booking-3", status: .confirmed, version: 1))
            try context.save()
        }
        XCTAssertEqual(syncManager.cachedBookings().count, 1)

        try await syncManager.cancelBooking(id: "booking-3")

        XCTAssertTrue(syncManager.cachedBookings().isEmpty, "Pending-deletion bookings should be hidden from the active list")
    }
}
