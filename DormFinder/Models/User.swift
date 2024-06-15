import Foundation

/// Authenticated user profile.
struct User: Codable, Identifiable, Hashable {
    let id: String
    let email: String
    let fullName: String
    let university: String?

    enum CodingKeys: String, CodingKey {
        case id, email
        case fullName = "full_name"
        case university
    }
}

/// Request body for the login endpoint.
struct LoginRequest: Codable {
    let email: String
    let password: String
}

/// Request body for the signup endpoint.
struct SignupRequest: Codable {
    let email: String
    let password: String
    let fullName: String
    let university: String?

    enum CodingKeys: String, CodingKey {
        case email, password
        case fullName = "full_name"
        case university
    }
}

/// JWT-bearing response returned by login/signup; access token is short-lived,
/// refresh token is used by `AuthService` to silently re-authenticate.
struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: User

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }
}

/// Lightweight session wrapper persisted in the Keychain (token material only — never the password).
struct Session: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let userID: String

    var isExpired: Bool {
        Date() >= expiresAt
    }
}
