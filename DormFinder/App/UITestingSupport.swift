#if DEBUG
import Foundation
import Combine

/// Deterministic in-memory services used only when the app is launched with `UI-TESTING`
/// (see `BookingFlowUITests`). Keeps UI tests fast and independent of a live backend while
/// still exercising the real view/view-model/sync stack end to end.
enum UITestFixtures {
    static let user = User(id: "ui-test-user", email: "student@university.edu", fullName: "Jamie Rivera", university: "Test University")

    static let listings: [Listing] = [
        Listing(
            id: "fixture-1",
            title: "Sunny Studio Near Campus",
            summary: "A bright studio five minutes from the quad, fully furnished.",
            pricePerMonth: 950,
            currencyCode: "USD",
            roomType: .studio,
            latitude: 37.8719,
            longitude: -122.2585,
            address: "123 University Ave, Berkeley, CA",
            distanceToCampusMeters: 450,
            amenities: [Amenity(id: "wifi", name: "WiFi", symbolName: "wifi")],
            photoURLs: [],
            isAvailable: true,
            availableFrom: .now,
            rating: 4.6,
            updatedAt: .now
        ),
        Listing(
            id: "fixture-2",
            title: "Spacious Shared Apartment",
            summary: "Three-bedroom apartment a short bus ride from campus.",
            pricePerMonth: 700,
            currencyCode: "USD",
            roomType: .sharedRoom,
            latitude: 37.8651,
            longitude: -122.2601,
            address: "456 College St, Berkeley, CA",
            distanceToCampusMeters: 1800,
            amenities: [Amenity(id: "laundry", name: "Laundry", symbolName: "washer")],
            photoURLs: [],
            isAvailable: true,
            availableFrom: .now,
            rating: 4.2,
            updatedAt: .now
        )
    ]
}

final class UITestAuthService: AuthServiceProtocol {
    private let subject = CurrentValueSubject<Session?, Never>(nil)
    var sessionPublisher: AnyPublisher<Session?, Never> { subject.eraseToAnyPublisher() }
    var currentSession: Session? { subject.value }

    func login(email: String, password: String) async throws -> User {
        let session = Session(accessToken: "fixture-token", refreshToken: "fixture-refresh", expiresAt: .now.addingTimeInterval(3600), userID: UITestFixtures.user.id)
        subject.send(session)
        return UITestFixtures.user
    }

    func signup(email: String, password: String, fullName: String, university: String?) async throws -> User {
        try await login(email: email, password: password)
    }

    func logout() { subject.send(nil) }
    func validAccessToken() async -> String? { "fixture-token" }
}

final class UITestListingService: ListingServiceProtocol {
    func fetchListings(near coordinate: (latitude: Double, longitude: Double)?, page: Int) async throws -> [Listing] {
        UITestFixtures.listings
    }

    func fetchListing(id: String) async throws -> Listing {
        guard let listing = UITestFixtures.listings.first(where: { $0.id == id }) else {
            throw NetworkError.requestFailed(statusCode: 404, message: "Not found")
        }
        return listing
    }
}

final class UITestBookingService: BookingServiceProtocol {
    private var bookings: [Booking] = []

    func fetchBookings() async throws -> [Booking] { bookings }

    func createBooking(_ request: BookingRequest) async throws -> Booking {
        let listingTitle = UITestFixtures.listings.first(where: { $0.id == request.listingID })?.title ?? "Listing"
        let booking = Booking(
            id: "fixture-booking-\(bookings.count + 1)",
            listingID: request.listingID,
            listingTitle: listingTitle,
            userID: UITestFixtures.user.id,
            checkIn: request.checkIn,
            checkOut: request.checkOut,
            totalPrice: 700,
            currencyCode: "USD",
            status: .pending,
            createdAt: .now,
            updatedAt: .now,
            version: 1
        )
        bookings.append(booking)
        return booking
    }

    func cancelBooking(id: String) async throws {
        bookings.removeAll { $0.id == id }
    }
}
#endif
