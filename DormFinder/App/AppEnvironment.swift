import Foundation

/// Composition root: builds and wires every service/manager exactly once and hands them
/// out to view models. Keeping construction in one place is what makes the protocol-based
/// service layer swappable in tests and previews (see `AppEnvironment.preview`).
@MainActor
final class AppEnvironment: ObservableObject {
    let persistence: PersistenceController
    let networkMonitor: NetworkMonitor
    let authService: AuthServiceProtocol
    let listingService: ListingServiceProtocol
    let bookingService: BookingServiceProtocol
    let syncManager: SyncManager

    nonisolated static let apiBaseURL = URL(string: "https://api.dormfinder.app/v1")!

    init(
        persistence: PersistenceController = .shared,
        baseURL: URL = AppEnvironment.apiBaseURL
    ) {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("UI-TESTING")
        self.persistence = isUITesting ? PersistenceController(inMemory: true) : persistence
        self.networkMonitor = NetworkMonitor()

        #if DEBUG
        if isUITesting {
            let authService = UITestAuthService()
            self.authService = authService
            self.listingService = UITestListingService()
            self.bookingService = UITestBookingService()
            self.syncManager = SyncManager(
                persistence: self.persistence,
                listingService: listingService,
                bookingService: bookingService,
                networkMonitor: networkMonitor
            )
            return
        }
        #endif

        let authService = AuthService(baseURL: baseURL)
        self.authService = authService

        let network = NetworkService(
            baseURL: baseURL,
            tokenProvider: { await authService.validAccessToken() },
            unauthorizedHandler: { authService.logout() }
        )

        self.listingService = ListingService(network: network)
        self.bookingService = BookingService(network: network)
        self.syncManager = SyncManager(
            persistence: persistence,
            listingService: listingService,
            bookingService: bookingService,
            networkMonitor: networkMonitor
        )
    }

    /// Builds an environment backed by in-memory CoreData and mock services for previews and tests.
    static func preview() -> AppEnvironment {
        AppEnvironment(persistence: .preview)
    }
}
