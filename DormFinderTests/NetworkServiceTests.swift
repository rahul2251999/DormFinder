import XCTest
@testable import DormFinder

final class NetworkServiceTests: XCTestCase {
    func test_jsonDecoder_decodesSnakeCaseListingPayload() throws {
        let json = """
        {
          "id": "listing-42",
          "title": "Lakeview Apartment",
          "summary": "Two bedroom apartment overlooking the lake.",
          "price_per_month": 1450.50,
          "currency_code": "USD",
          "room_type": "apartment",
          "latitude": 37.87,
          "longitude": -122.27,
          "address": "42 Lake Rd",
          "distance_to_campus_meters": 1200.0,
          "amenities": [{"id": "wifi", "name": "WiFi", "symbolName": "wifi"}],
          "photo_urls": ["https://example.com/a.jpg"],
          "is_available": true,
          "available_from": "2026-07-01T00:00:00.000Z",
          "rating": 4.8,
          "updated_at": "2026-06-01T12:30:00.000Z"
        }
        """.data(using: .utf8)!

        let listing = try NetworkService.jsonDecoder.decode(Listing.self, from: json)

        XCTAssertEqual(listing.id, "listing-42")
        XCTAssertEqual(listing.roomType, .apartment)
        XCTAssertEqual(listing.pricePerMonth, Decimal(string: "1450.50"))
        XCTAssertEqual(listing.amenities.first?.symbolName, "wifi")
        XCTAssertTrue(listing.isAvailable)
    }

    func test_jsonDecoder_decodesISO8601WithoutFractionalSeconds() throws {
        let json = """
        { "access_token": "abc", "refresh_token": "def", "expires_in": 3600,
          "user": { "id": "u1", "email": "a@b.edu", "full_name": "A B", "university": null } }
        """.data(using: .utf8)!

        let response = try NetworkService.jsonDecoder.decode(AuthResponse.self, from: json)
        XCTAssertEqual(response.accessToken, "abc")
        XCTAssertEqual(response.user.email, "a@b.edu")
    }

    func test_jsonEncoder_roundTripsBookingRequest() throws {
        let request = BookingRequest(listingID: "listing-1", checkIn: Date(timeIntervalSince1970: 1_700_000_000), checkOut: Date(timeIntervalSince1970: 1_700_600_000))
        let data = try NetworkService.jsonEncoder.encode(request)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["listing_id"] as? String, "listing-1")
        XCTAssertNotNil(json["check_in"])
        XCTAssertNotNil(json["check_out"])
    }

    func test_request_mapsHTTPStatusesToErrors() async throws {
        let session = URLSession(configuration: stubbedConfiguration(statusCode: 401, body: Data()))
        var unauthorizedCalled = false
        let service = NetworkService(
            baseURL: URL(string: "https://example.com/v1")!,
            session: session,
            tokenProvider: { "token" },
            unauthorizedHandler: { unauthorizedCalled = true }
        )

        do {
            _ = try await service.request(Endpoint(path: "listings"), as: [Listing].self)
            XCTFail("Expected unauthorized error")
        } catch NetworkError.unauthorized {
            // expected
        }

        XCTAssertTrue(unauthorizedCalled, "401 responses should trigger the unauthorized handler so the app can sign out")
    }

    // MARK: - Helpers

    private func stubbedConfiguration(statusCode: Int, body: Data) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.statusCode = statusCode
        StubURLProtocol.responseBody = body
        return configuration
    }
}

/// Minimal `URLProtocol` stub so `NetworkService` can be tested without hitting the network.
private final class StubURLProtocol: URLProtocol {
    static var statusCode = 200
    static var responseBody = Data()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.statusCode, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
