import Foundation
import Combine

/// Drives "My Bookings": loads the cached/synced reservation list, exposes a connectivity
/// banner, and handles cancellation through the offline-aware `SyncManager`.
@MainActor
final class MyBookingsViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case empty
    }

    @Published private(set) var bookings: [Booking] = []
    @Published private(set) var loadState: LoadState = .idle
    @Published private(set) var isOffline = false
    @Published private(set) var cancellationError: String?

    private let syncManager: SyncManager
    private let networkMonitor: NetworkMonitor
    private var cancellables = Set<AnyCancellable>()

    init(syncManager: SyncManager, networkMonitor: NetworkMonitor) {
        self.syncManager = syncManager
        self.networkMonitor = networkMonitor

        networkMonitor.$isConnected
            .map { !$0 }
            .receive(on: DispatchQueue.main)
            .assign(to: &$isOffline)
    }

    func loadBookings() async {
        loadState = .loading
        await syncManager.syncAll()
        bookings = syncManager.cachedBookings()
        loadState = bookings.isEmpty ? .empty : .loaded
    }

    func refresh() async {
        await loadBookings()
    }

    func cancelBooking(_ booking: Booking) async {
        cancellationError = nil
        do {
            try await syncManager.cancelBooking(id: booking.id)
            bookings = syncManager.cachedBookings()
        } catch {
            cancellationError = "Couldn't cancel right now — it'll be retried automatically."
        }
    }
}
