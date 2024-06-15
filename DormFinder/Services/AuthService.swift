import Foundation
import Combine

/// Owns the authentication session lifecycle: login, signup, logout, token refresh,
/// and Keychain persistence. Published `currentUser`/`isAuthenticated` drive app-wide UI state.
protocol AuthServiceProtocol {
    var sessionPublisher: AnyPublisher<Session?, Never> { get }
    var currentSession: Session? { get }

    func login(email: String, password: String) async throws -> User
    func signup(email: String, password: String, fullName: String, university: String?) async throws -> User
    func logout()
    /// Returns a valid bearer token, refreshing it first if it has expired.
    func validAccessToken() async -> String?
}

final class AuthService: AuthServiceProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let keychain: KeychainServiceProtocol

    private let sessionSubject: CurrentValueSubject<Session?, Never>

    var sessionPublisher: AnyPublisher<Session?, Never> {
        sessionSubject.eraseToAnyPublisher()
    }

    var currentSession: Session? { sessionSubject.value }

    init(baseURL: URL, session: URLSession = .shared, keychain: KeychainServiceProtocol = KeychainService()) {
        self.baseURL = baseURL
        self.session = session
        self.keychain = keychain
        self.sessionSubject = CurrentValueSubject(keychain.loadSession())
    }

    func login(email: String, password: String) async throws -> User {
        let body = try NetworkService.jsonEncoder.encode(LoginRequest(email: email, password: password))
        let response: AuthResponse = try await send(path: "auth/login", body: body)
        try persist(response)
        return response.user
    }

    func signup(email: String, password: String, fullName: String, university: String?) async throws -> User {
        let request = SignupRequest(email: email, password: password, fullName: fullName, university: university)
        let body = try NetworkService.jsonEncoder.encode(request)
        let response: AuthResponse = try await send(path: "auth/signup", body: body)
        try persist(response)
        return response.user
    }

    func logout() {
        keychain.clear()
        sessionSubject.send(nil)
    }

    func validAccessToken() async -> String? {
        guard let session = sessionSubject.value else { return nil }
        if !session.isExpired {
            return session.accessToken
        }
        return await refresh(using: session.refreshToken)
    }

    // MARK: - Private

    private func persist(_ response: AuthResponse) throws {
        let session = Session(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn)),
            userID: response.user.id
        )
        try keychain.save(session)
        sessionSubject.send(session)
    }

    private func refresh(using refreshToken: String) async -> String? {
        struct RefreshBody: Encodable { let refreshToken: String
            enum CodingKeys: String, CodingKey { case refreshToken = "refresh_token" }
        }
        guard let body = try? NetworkService.jsonEncoder.encode(RefreshBody(refreshToken: refreshToken)) else { return nil }
        guard let response: AuthResponse = try? await send(path: "auth/refresh", body: body) else {
            logout()
            return nil
        }
        try? persist(response)
        return response.accessToken
    }

    private func send<T: Decodable>(path: String, body: Data) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = HTTPMethod.post.rawValue
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown("Missing HTTP response.")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, message: nil)
        }
        do {
            return try NetworkService.jsonDecoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed
        }
    }
}
