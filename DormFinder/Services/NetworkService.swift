import Foundation

/// Errors surfaced by the networking layer; view models map these to user-facing messages.
enum NetworkError: Error, Equatable, LocalizedError {
    case invalidURL
    case requestFailed(statusCode: Int, message: String?)
    case decodingFailed
    case unauthorized
    case offline
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request URL was invalid."
        case .requestFailed(let statusCode, let message):
            return message ?? "The server returned an error (\(statusCode))."
        case .decodingFailed:
            return "The server response could not be read."
        case .unauthorized:
            return "Your session has expired. Please log in again."
        case .offline:
            return "You're offline. Showing cached results."
        case .unknown(let message):
            return message
        }
    }
}

/// HTTP verbs supported by `Endpoint`.
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

/// Describes a single REST call: path, method, query items, body and whether it requires auth.
struct Endpoint {
    var path: String
    var method: HTTPMethod = .get
    var queryItems: [URLQueryItem] = []
    var body: Data? = nil
    var requiresAuth: Bool = true
}

/// Abstraction over the networking transport so view models and services can be tested
/// against a mock without touching `URLSession`.
protocol NetworkServiceProtocol {
    /// Performs a request and decodes the JSON response body into `T`.
    func request<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T
    /// Performs a request that returns no meaningful body (e.g. DELETE).
    func requestVoid(_ endpoint: Endpoint) async throws
}

/// Default `URLSession`-backed implementation using async/await.
///
/// Decoding uses snake_case JSON keys mapped to camelCase Swift properties and ISO-8601
/// dates with fractional seconds, matching the FastAPI backend's serialization.
final class NetworkService: NetworkServiceProtocol {
    private let session: URLSession
    private let baseURL: URL
    private let tokenProvider: () async -> String?
    private let unauthorizedHandler: () async -> Void

    static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = DormFinderDateFormatters.iso8601WithFractionalSeconds.date(from: string) {
                return date
            }
            if let date = DormFinderDateFormatters.iso8601.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized date format: \(string)")
        }
        return decoder
    }()

    static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(DormFinderDateFormatters.iso8601WithFractionalSeconds.string(from: date))
        }
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    /// - Parameters:
    ///   - baseURL: API root, e.g. `https://api.dormfinder.app/v1`.
    ///   - session: Injectable for testing; defaults to `.shared`.
    ///   - tokenProvider: Async closure returning the current bearer token, or `nil` if signed out.
    ///   - unauthorizedHandler: Invoked when the server responds 401, so the app can sign the user out.
    init(
        baseURL: URL,
        session: URLSession = .shared,
        tokenProvider: @escaping () async -> String?,
        unauthorizedHandler: @escaping () async -> Void
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
        self.unauthorizedHandler = unauthorizedHandler
    }

    func request<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        let data = try await performRequest(endpoint)
        do {
            return try Self.jsonDecoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed
        }
    }

    func requestVoid(_ endpoint: Endpoint) async throws {
        _ = try await performRequest(endpoint)
    }

    // MARK: - Private

    private func performRequest(_ endpoint: Endpoint) async throws -> Data {
        let request = try await buildRequest(for: endpoint)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
            throw NetworkError.offline
        } catch {
            throw NetworkError.unknown(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown("Missing HTTP response.")
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return data
        case 401:
            await unauthorizedHandler()
            throw NetworkError.unauthorized
        default:
            let message = (try? Self.jsonDecoder.decode(APIErrorBody.self, from: data))?.detail
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }
    }

    private func buildRequest(for endpoint: Endpoint) async throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidURL
        }
        if !endpoint.queryItems.isEmpty {
            components.queryItems = endpoint.queryItems
        }
        guard let url = components.url else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if endpoint.body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if endpoint.requiresAuth, let token = await tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}

/// Shape of error bodies returned by the FastAPI backend, e.g. `{"detail": "Invalid credentials"}`.
private struct APIErrorBody: Decodable {
    let detail: String?
}

/// Shared date formatters for encoding/decoding API payloads consistently.
enum DormFinderDateFormatters {
    static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
