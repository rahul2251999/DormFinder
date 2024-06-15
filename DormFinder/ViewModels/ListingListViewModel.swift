import Foundation
import Combine

/// Drives the browse/search screen: loads listings (cache-first, then network refresh),
/// and applies the active `ListingFilter` reactively as the user types or adjusts filters.
@MainActor
final class ListingListViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published private(set) var listings: [Listing] = []
    @Published private(set) var filteredListings: [Listing] = []
    @Published private(set) var loadState: LoadState = .idle
    @Published private(set) var isShowingCachedData = false
    @Published var filter: ListingFilter = .default

    private let syncManager: SyncManager
    private var cancellables = Set<AnyCancellable>()

    init(syncManager: SyncManager) {
        self.syncManager = syncManager
        observeFilterChanges()
    }

    /// Recomputes `filteredListings` whenever the source list or filter criteria change,
    /// debounced so rapid typing in the search field doesn't thrash the UI.
    private func observeFilterChanges() {
        Publishers.CombineLatest($listings, $filter.debounce(for: .milliseconds(200), scheduler: DispatchQueue.main))
            .map { listings, filter in
                listings.filter(filter.matches)
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$filteredListings)
    }

    func loadListings(near coordinate: (latitude: Double, longitude: Double)? = nil) async {
        if listings.isEmpty {
            loadState = .loading
        }

        let cached = syncManager.cachedListings()
        if !cached.isEmpty {
            listings = cached
            isShowingCachedData = true
            loadState = .loaded
        }

        let result = await syncManager.fetchListings(near: coordinate)
        listings = result.listings
        isShowingCachedData = result.servedFromCache

        if result.listings.isEmpty && cached.isEmpty {
            loadState = .failed("No listings available. Pull to refresh once you're back online.")
        } else {
            loadState = .loaded
        }
    }

    func refresh(near coordinate: (latitude: Double, longitude: Double)? = nil) async {
        await loadListings(near: coordinate)
    }

    func clearFilters() {
        filter = .default
    }
}
