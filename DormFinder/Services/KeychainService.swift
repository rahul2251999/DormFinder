import Foundation
import Security

/// Minimal Keychain wrapper used to persist the JWT `Session` securely across launches.
/// Tokens are stored as a single JSON blob under one generic-password item.
protocol KeychainServiceProtocol {
    func save(_ session: Session) throws
    func loadSession() -> Session?
    func clear()
}

final class KeychainService: KeychainServiceProtocol {
    private let account = "com.dormfinder.session"
    private let service = "com.dormfinder.auth"

    func save(_ session: Session) throws {
        let data = try JSONEncoder.dormFinderKeychainEncoder.encode(session)

        var query = baseQuery()
        SecItemDelete(query as CFDictionary)

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }
    }

    func loadSession() -> Session? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder.dormFinderKeychainDecoder.decode(Session.self, from: data)
    }

    func clear() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    enum KeychainError: Error {
        case unhandled(OSStatus)
    }
}

private extension JSONEncoder {
    static let dormFinderKeychainEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

private extension JSONDecoder {
    static let dormFinderKeychainDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
