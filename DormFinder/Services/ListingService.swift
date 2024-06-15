import Foundation

/// Protocol-based facade over the listings API, mockable for view-model unit tests.
protocol ListingServiceProtocol {
    func fetchListings(near coordinate: (latitude: Double, longitude: Double)?, page: Int) async throws -> [Listing]
    func fetchListing(id: String) async throws -> Listing
}

final class ListingService: ListingServiceProtocol {
    private let network: NetworkServiceProtocol

    init(network: NetworkServiceProtocol) {
        self.network = network
    }

    func fetchListings(near coordinate: (latitude: Double, longitude: Double)?, page: Int) async throws -> [Listing] {
        var queryItems = [URLQueryItem(name: "page", value: String(page))]
        if let coordinate {
            queryItems.append(URLQueryItem(name: "lat", value: String(coordinate.latitude)))
            queryItems.append(URLQueryItem(name: "lng", value: String(coordinate.longitude)))
        }
        let endpoint = Endpoint(path: "listings", method: .get, queryItems: queryItems, requiresAuth: false)
        return try await network.request(endpoint, as: [Listing].self)
    }

    func fetchListing(id: String) async throws -> Listing {
        let endpoint = Endpoint(path: "listings/\(id)", method: .get, requiresAuth: false)
        return try await network.request(endpoint, as: Listing.self)
    }
}
