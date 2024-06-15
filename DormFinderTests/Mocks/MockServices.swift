import Foundation
import Combine
@testable import DormFinder

/// In-memory stand-ins for the protocol-based service layer, used across unit tests so
/// view models can be exercised without touching the network or CoreData.

final class MockNetworkService: NetworkServiceProtocol {
    var responses: [String: Any] = [:]
    var errorToThrow: Error?
    private(set) var requestedPaths: [String] = []

    func request<T>(_ endpoint: Endpoint, as type: T.Type) async throws -> T where T: Decodable {
        requestedPaths.append(endpoint.path)
        if let error = errorToThrow { throw error }
        guard let response = responses[endpoint.path] as? T else {
            throw NetworkError.decodingFailed
        }
        return response
    }

    func requestVoid(_ endpoint: Endpoint) async throws {
        requestedPaths.append(endpoint.path)
        if let error = errorToThrow { throw error }
    }
}

final class MockListingService: ListingServiceProtocol {
    var listingsToReturn: [Listing] = []
    var errorToThrow: Error?
    private(set) var fetchCallCount = 0

    func fetchListings(near coordinate: (latitude: Double, longitude: Double)?, page: Int) async throws -> [Listing] {
        fetchCallCount += 1
        if let error = errorToThrow { throw error }
        return listingsToReturn
    }

    func fetchListing(id: String) async throws -> Listing {
        if let error = errorToThrow { throw error }
        guard let listing = listingsToReturn.first(where: { $0.id == id }) else {
            throw NetworkError.requestFailed(statusCode: 404, message: "Not found")
        }
        return listing
    }
}

final class MockBookingService: BookingServiceProtocol {
    var bookingsToReturn: [Booking] = []
    var bookingToCreate: Booking?
    var errorToThrow: Error?
    private(set) var cancelledIDs: [String] = []

    func fetchBookings() async throws -> [Booking] {
        if let error = errorToThrow { throw error }
        return bookingsToReturn
    }

    func createBooking(_ request: BookingRequest) async throws -> Booking {
        if let error = errorToThrow { throw error }
        guard let booking = bookingToCreate else {
            throw NetworkError.requestFailed(statusCode: 500, message: "No booking configured")
        }
        return booking
    }

    func cancelBooking(id: String) async throws {
        if let error = errorToThrow { throw error }
        cancelledIDs.append(id)
    }
}

final class MockAuthService: AuthServiceProtocol {
    private let subject: CurrentValueSubject<Session?, Never>
    var userToReturn: User?
    var errorToThrow: Error?
    var tokenToReturn: String? = "mock-access-token"

    init(initialSession: Session? = nil) {
        subject = CurrentValueSubject(initialSession)
    }

    var sessionPublisher: AnyPublisher<Session?, Never> { subject.eraseToAnyPublisher() }
    var currentSession: Session? { subject.value }

    func login(email: String, password: String) async throws -> User {
        if let error = errorToThrow { throw error }
        guard let user = userToReturn else { throw NetworkError.unauthorized }
        subject.send(Session(accessToken: "token", refreshToken: "refresh", expiresAt: .now.addingTimeInterval(3600), userID: user.id))
        return user
    }

    func signup(email: String, password: String, fullName: String, university: String?) async throws -> User {
        try await login(email: email, password: password)
    }

    func logout() {
        subject.send(nil)
    }

    func validAccessToken() async -> String? {
        tokenToReturn
    }
}

extension Listing {
    static func stub(
        id: String = UUID().uuidString,
        title: String = "Test Listing",
        pricePerMonth: Decimal = 1000,
        roomType: RoomType = .studio,
        distanceToCampusMeters: Double = 500,
        isAvailable: Bool = true
    ) -> Listing {
        Listing(
            id: id,
            title: title,
            summary: "A test listing.",
            pricePerMonth: pricePerMonth,
            currencyCode: "USD",
            roomType: roomType,
            latitude: 37.0,
            longitude: -122.0,
            address: "1 Test St",
            distanceToCampusMeters: distanceToCampusMeters,
            amenities: [],
            photoURLs: [],
            isAvailable: isAvailable,
            availableFrom: .now,
            rating: 4.5,
            updatedAt: .now
        )
    }
}

extension Booking {
    static func stub(
        id: String = UUID().uuidString,
        listingID: String = "listing-1",
        status: BookingStatus = .pending,
        version: Int = 1
    ) -> Booking {
        Booking(
            id: id,
            listingID: listingID,
            listingTitle: "Test Listing",
            userID: "user-1",
            checkIn: .now,
            checkOut: .now.addingTimeInterval(7 * 24 * 3600),
            totalPrice: 700,
            currencyCode: "USD",
            status: status,
            createdAt: .now,
            updatedAt: .now,
            version: version
        )
    }
}

extension User {
    static func stub(id: String = "user-1", email: String = "student@university.edu") -> User {
        User(id: id, email: email, fullName: "Test Student", university: "Test University")
    }
}
