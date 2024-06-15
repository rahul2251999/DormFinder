import XCTest
@testable import DormFinder

@MainActor
final class ListingListViewModelTests: XCTestCase {
    private func makeSyncManager(listings: [Listing] = [], bookingsError: Error? = NetworkError.offline) -> (SyncManager, MockListingService) {
        let persistence = PersistenceController(inMemory: true)
        let listingService = MockListingService()
        listingService.listingsToReturn = listings
        let bookingService = MockBookingService()
        bookingService.errorToThrow = bookingsError
        let monitor = NetworkMonitor()

        let syncManager = SyncManager(
            persistence: persistence,
            listingService: listingService,
            bookingService: bookingService,
            networkMonitor: monitor
        )
        return (syncManager, listingService)
    }

    func test_loadListings_populatesListingsFromService() async {
        let listings = [Listing.stub(id: "a", title: "Alpha"), Listing.stub(id: "b", title: "Beta")]
        let (syncManager, _) = makeSyncManager(listings: listings)
        let viewModel = ListingListViewModel(syncManager: syncManager)

        await viewModel.loadListings()

        XCTAssertEqual(Set(viewModel.listings.map(\.id)), Set(["a", "b"]))
        XCTAssertEqual(viewModel.loadState, .loaded)
    }

    func test_filter_byMaxPrice_excludesExpensiveListings() async {
        let cheap = Listing.stub(id: "cheap", pricePerMonth: 600)
        let pricey = Listing.stub(id: "pricey", pricePerMonth: 2500)
        let (syncManager, _) = makeSyncManager(listings: [cheap, pricey])
        let viewModel = ListingListViewModel(syncManager: syncManager)
        await viewModel.loadListings()

        viewModel.filter.maxPricePerMonth = 1000
        try? await Task.sleep(nanoseconds: 300_000_000) // allow the debounced pipeline to settle

        XCTAssertEqual(viewModel.filteredListings.map(\.id), ["cheap"])
    }

    func test_filter_byRoomType_onlyMatchesSelectedTypes() async {
        let studio = Listing.stub(id: "studio", roomType: .studio)
        let apartment = Listing.stub(id: "apartment", roomType: .apartment)
        let (syncManager, _) = makeSyncManager(listings: [studio, apartment])
        let viewModel = ListingListViewModel(syncManager: syncManager)
        await viewModel.loadListings()

        viewModel.filter.roomTypes = [.apartment]
        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(viewModel.filteredListings.map(\.id), ["apartment"])
    }

    func test_searchText_matchesTitleCaseInsensitively() async {
        let sunny = Listing.stub(id: "sunny", title: "Sunny Studio")
        let cozy = Listing.stub(id: "cozy", title: "Cozy Apartment")
        let (syncManager, _) = makeSyncManager(listings: [sunny, cozy])
        let viewModel = ListingListViewModel(syncManager: syncManager)
        await viewModel.loadListings()

        viewModel.filter.searchText = "sunny"
        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(viewModel.filteredListings.map(\.id), ["sunny"])
    }

    func test_clearFilters_resetsToDefault() {
        let (syncManager, _) = makeSyncManager()
        let viewModel = ListingListViewModel(syncManager: syncManager)
        viewModel.filter.searchText = "something"
        viewModel.filter.maxPricePerMonth = 500

        viewModel.clearFilters()

        XCTAssertEqual(viewModel.filter, .default)
    }
}
