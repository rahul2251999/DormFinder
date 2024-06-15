import Foundation

/// Protocol-based facade over the bookings API.
protocol BookingServiceProtocol {
    func fetchBookings() async throws -> [Booking]
    func createBooking(_ request: BookingRequest) async throws -> Booking
    func cancelBooking(id: String) async throws
}

final class BookingService: BookingServiceProtocol {
    private let network: NetworkServiceProtocol

    init(network: NetworkServiceProtocol) {
        self.network = network
    }

    func fetchBookings() async throws -> [Booking] {
        try await network.request(Endpoint(path: "bookings", method: .get), as: [Booking].self)
    }

    func createBooking(_ request: BookingRequest) async throws -> Booking {
        let body = try NetworkService.jsonEncoder.encode(request)
        let endpoint = Endpoint(path: "bookings", method: .post, body: body)
        return try await network.request(endpoint, as: Booking.self)
    }

    func cancelBooking(id: String) async throws {
        try await network.requestVoid(Endpoint(path: "bookings/\(id)", method: .delete))
    }
}
