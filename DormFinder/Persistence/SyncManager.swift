import CoreData
import Combine
import Foundation

/// Coordinates offline-first reads/writes against CoreData and reconciles them with the
/// backend when connectivity is available.
///
/// Strategy:
/// - **Listings** are read-through cached: every fetch writes through to CoreData, and the
///   cache is what views actually observe, so the UI works fully offline.
/// - **Bookings** are read/write: local creates and cancellations are queued with a
///   `syncState` and flushed to the server in `syncPendingBookings()`. Remote bookings are
///   merged with a **last-write-wins by `version`** policy — if the local row is `pendingUpdate`
///   but the server's `version` is higher, the server copy wins and the local edit is discarded,
///   since the server is the source of truth for booking status transitions (e.g. host
///   confirmations) that the client can't predict.
final class SyncManager {
    private let persistence: PersistenceController
    private let listingService: ListingServiceProtocol
    private let bookingService: BookingServiceProtocol
    private let networkMonitor: NetworkMonitor

    private var cancellables = Set<AnyCancellable>()
    private var isSyncing = false

    init(
        persistence: PersistenceController,
        listingService: ListingServiceProtocol,
        bookingService: BookingServiceProtocol,
        networkMonitor: NetworkMonitor
    ) {
        self.persistence = persistence
        self.listingService = listingService
        self.bookingService = bookingService
        self.networkMonitor = networkMonitor

        observeConnectivity()
    }

    /// Triggers a sync the moment the device transitions from offline to online.
    private func observeConnectivity() {
        networkMonitor.$isConnected
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in
                Task { await self?.syncAll() }
            }
            .store(in: &cancellables)
    }

    /// Runs a full sync pass: flush local booking changes first (so the server sees them),
    /// then pull the latest bookings and listings. Safe to call repeatedly — re-entrancy guarded.
    @discardableResult
    func syncAll() async -> Bool {
        guard !isSyncing, networkMonitor.isConnected else { return false }
        isSyncing = true
        defer { isSyncing = false }

        await syncPendingBookings()
        await refreshBookingsFromServer()
        return true
    }

    // MARK: - Listings (read-through cache)

    /// Fetches listings from the network, writes them into the cache, and returns the
    /// merged set. On failure (e.g. offline) it falls back to whatever is cached.
    func fetchListings(near coordinate: (latitude: Double, longitude: Double)?) async -> (listings: [Listing], servedFromCache: Bool) {
        do {
            let remote = try await listingService.fetchListings(near: coordinate, page: 1)
            await writeThrough(remote)
            return (remote, false)
        } catch {
            return (cachedListings(), true)
        }
    }

    func cachedListings() -> [Listing] {
        let context = persistence.container.viewContext
        let request = CachedListing.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedListing.distanceToCampusMeters, ascending: true)]
        let cached = (try? context.fetch(request)) ?? []
        return cached.compactMap { $0.toDomain() }
    }

    private func writeThrough(_ listings: [Listing]) async {
        let context = persistence.newBackgroundContext()
        await context.perform {
            for listing in listings {
                let request = CachedListing.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", listing.id)
                request.fetchLimit = 1
                let entity = (try? context.fetch(request))?.first ?? CachedListing(context: context)
                entity.apply(listing)
            }
            try? context.save()
        }
    }

    // MARK: - Bookings (offline-capable read/write)

    func cachedBookings() -> [Booking] {
        let context = persistence.container.viewContext
        let request = CachedBooking.fetchRequest()
        request.predicate = NSPredicate(format: "isPendingDeletion == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedBooking.checkIn, ascending: false)]
        let cached = (try? context.fetch(request)) ?? []
        return cached.compactMap { $0.toDomain() }
    }

    /// Optimistically writes a new booking locally (so it shows up immediately and survives
    /// app relaunch while offline), then attempts to push it to the server right away.
    func createBooking(_ request: BookingRequest, listingTitle: String, userID: String) async throws -> Booking {
        let context = persistence.newBackgroundContext()
        let localID = "local-\(UUID().uuidString)"

        let placeholder = Booking(
            id: localID,
            listingID: request.listingID,
            listingTitle: listingTitle,
            userID: userID,
            checkIn: request.checkIn,
            checkOut: request.checkOut,
            totalPrice: 0,
            currencyCode: "USD",
            status: .pending,
            createdAt: .now,
            updatedAt: .now,
            version: 0
        )

        await context.perform {
            let entity = CachedBooking(context: context)
            entity.applyServerState(placeholder)
            entity.syncState = SyncState.pendingCreate.rawValue
            entity.localUpdatedAt = .now
            try? context.save()
        }

        guard networkMonitor.isConnected else { return placeholder }

        do {
            let created = try await bookingService.createBooking(request)
            await replaceLocalBooking(localID: localID, with: created)
            return created
        } catch {
            // Stays queued as `pendingCreate`; `syncPendingBookings` retries later.
            return placeholder
        }
    }

    /// Marks a booking for deletion locally and attempts to push the cancellation immediately.
    func cancelBooking(id: String) async throws {
        let context = persistence.newBackgroundContext()
        await context.perform {
            let request = CachedBooking.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id)
            request.fetchLimit = 1
            guard let entity = (try? context.fetch(request))?.first else { return }

            if entity.resolvedSyncState == .pendingCreate {
                // Never made it to the server — safe to delete outright.
                context.delete(entity)
            } else {
                entity.isPendingDeletion = true
                entity.syncState = SyncState.pendingDelete.rawValue
                entity.localUpdatedAt = .now
            }
            try? context.save()
        }

        guard networkMonitor.isConnected else { return }
        await syncPendingBookings()
    }

    /// Pushes every locally-queued booking change to the server in turn.
    func syncPendingBookings() async {
        let context = persistence.newBackgroundContext()
        let pending: [(objectID: NSManagedObjectID, state: SyncState, id: String, request: BookingRequest)] = await context.perform {
            let request = CachedBooking.fetchRequest()
            request.predicate = NSPredicate(format: "syncState != %@", SyncState.synced.rawValue)
            let rows = (try? context.fetch(request)) ?? []
            return rows.compactMap { row -> (NSManagedObjectID, SyncState, String, BookingRequest)? in
                guard let id = row.id, let listingID = row.listingID,
                      let checkIn = row.checkIn, let checkOut = row.checkOut else { return nil }
                return (row.objectID, row.resolvedSyncState, id, BookingRequest(listingID: listingID, checkIn: checkIn, checkOut: checkOut))
            }
        }

        for item in pending {
            switch item.state {
            case .pendingCreate:
                if let created = try? await bookingService.createBooking(item.request) {
                    await replaceLocalBooking(localID: item.id, with: created)
                }
            case .pendingDelete:
                if (try? await bookingService.cancelBooking(id: item.id)) != nil {
                    await deleteLocalBooking(objectID: item.objectID)
                }
            case .pendingUpdate, .synced:
                continue
            }
        }
    }

    /// Pulls the authoritative booking list and merges it with local rows using
    /// last-write-wins-by-version: a remote row always overwrites a `synced` local row,
    /// and overwrites a `pendingUpdate` row only if its `version` is >= the local one
    /// (meaning the server already saw a newer state than what we're trying to push).
    private func refreshBookingsFromServer() async {
        guard let remote = try? await bookingService.fetchBookings() else { return }
        let context = persistence.newBackgroundContext()

        await context.perform {
            for booking in remote {
                let request = CachedBooking.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", booking.id)
                request.fetchLimit = 1
                let existing = (try? context.fetch(request))?.first

                guard let existing else {
                    let entity = CachedBooking(context: context)
                    entity.applyServerState(booking)
                    continue
                }

                switch existing.resolvedSyncState {
                case .synced, .pendingDelete:
                    existing.applyServerState(booking)
                case .pendingCreate:
                    continue // Local row hasn't been matched to a server ID yet.
                case .pendingUpdate:
                    if booking.version >= Int(existing.version) {
                        existing.applyServerState(booking)
                    }
                    // else: keep the local edit; it'll be pushed on the next sync pass.
                }
            }
            try? context.save()
        }
    }

    private func replaceLocalBooking(localID: String, with serverBooking: Booking) async {
        let context = persistence.newBackgroundContext()
        await context.perform {
            let request = CachedBooking.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", localID)
            request.fetchLimit = 1
            guard let entity = (try? context.fetch(request))?.first else { return }
            entity.applyServerState(serverBooking)
            try? context.save()
        }
    }

    private func deleteLocalBooking(objectID: NSManagedObjectID) async {
        let context = persistence.newBackgroundContext()
        await context.perform {
            guard let entity = try? context.existingObject(with: objectID) else { return }
            context.delete(entity)
            try? context.save()
        }
    }
}
