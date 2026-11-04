import Foundation
import Security

/// Session tokens and the account that owns them, as the backend issued them.
struct StoredSession: Codable, Equatable, Sendable {
    var accessToken: String
    var refreshToken: String
    var accountId: String
    var email: String
    var role: String
}

/// Where the session is kept between launches.
protocol SessionStorage: AnyObject {
    func read() -> StoredSession?
    func write(_ session: StoredSession)
    func delete()
}

/// Keeps the session in the Keychain so the technician stays signed in between visits.
final class KeychainSessionStorage: SessionStorage {
    private let service = "pe.alivia.mobile.session"
    private let account = "current"

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    func read() -> StoredSession? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(StoredSession.self, from: data)
    }

    func write(_ session: StoredSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(item as CFDictionary, nil)
        }
    }

    func delete() {
        SecItemDelete(query as CFDictionary)
    }
}

/// In-memory storage for tests and previews.
final class InMemorySessionStorage: SessionStorage {
    private var stored: StoredSession?
    init(_ session: StoredSession? = nil) { stored = session }
    func read() -> StoredSession? { stored }
    func write(_ session: StoredSession) { stored = session }
    func delete() { stored = nil }
}

/// The current session; the network layer reads its tokens on every call.
final class TokenStore {
    private let storage: SessionStorage
    private(set) var session: StoredSession?

    init(storage: SessionStorage) {
        self.storage = storage
    }

    var accessToken: String? { session?.accessToken }

    /// Loads the saved session when the app starts.
    func restore() -> StoredSession? {
        session = storage.read()
        if let current = session, current.accessToken.isEmpty || current.refreshToken.isEmpty {
            clear()
        }
        return session
    }

    func save(_ session: StoredSession) {
        self.session = session
        storage.write(session)
    }

    func clear() {
        session = nil
        storage.delete()
    }
}
