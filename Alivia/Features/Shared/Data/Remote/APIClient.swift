import Foundation

/// Failure of a backend call before it becomes a message for the screen.
enum APIError: Error {
    case http(status: Int, detail: String?)
    case transport
    case invalidResponse
}

/// HTTP access to the Alivia backend. Adds the session token and, when the backend answers 401, renews the
/// session once with the refresh token and repeats the call; if the renewal fails the session is closed.
final class APIClient {
    private let baseURL: URL
    private let tokens: TokenStore
    private let session: URLSession
    var onSessionExpired: () -> Void = {}
    private var renewal: Task<Bool, Never>?

    init(baseURL: URL, tokens: TokenStore, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.tokens = tokens
        self.session = session
    }

    func send<Response: Decodable>(_ method: String, _ path: String, body: (any Encodable)? = nil,
                                   as type: Response.Type = Response.self) async throws -> Response {
        let data = try await perform(method, path, body: body)
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.invalidResponse
        }
    }

    private func perform(_ method: String, _ path: String, body: (any Encodable)?) async throws -> Data {
        let (data, status, sentToken) = try await execute(method, path, body: body)
        guard status == 401, !path.contains("api/v1/auth/"), tokens.session != nil else {
            return try check(data, status)
        }
        // Another call may have renewed the session while this one waited.
        if let sentToken, sentToken != tokens.accessToken {
            let (retryData, retryStatus, _) = try await execute(method, path, body: body)
            return try check(retryData, retryStatus)
        }
        guard await renewSession() else {
            tokens.clear()
            onSessionExpired()
            throw APIError.http(status: 401, detail: nil)
        }
        let (retryData, retryStatus, _) = try await execute(method, path, body: body)
        return try check(retryData, retryStatus)
    }

    private func execute(_ method: String, _ path: String, body: (any Encodable)?) async throws -> (Data, Int, String?) {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw APIError.transport }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let token = tokens.accessToken
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONEncoder().encode(body)
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.transport }
            return (data, http.statusCode, token)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport
        }
    }

    private func check(_ data: Data, _ status: Int) throws -> Data {
        guard (200..<300).contains(status) else {
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String
            throw APIError.http(status: status, detail: detail)
        }
        return data
    }

    /// One renewal at a time; concurrent 401s wait for the same one.
    private func renewSession() async -> Bool {
        if let renewal { return await renewal.value }
        let task = Task { () -> Bool in
            guard let current = tokens.session else { return false }
            struct RefreshRequest: Encodable { let refreshToken: String }
            struct RefreshResponse: Decodable { let accessToken: String?; let refreshToken: String? }
            guard let (data, status, _) = try? await execute("POST", "api/v1/auth/refresh",
                                                              body: RefreshRequest(refreshToken: current.refreshToken)),
                  (200..<300).contains(status),
                  let reply = try? JSONDecoder().decode(RefreshResponse.self, from: data),
                  let access = reply.accessToken, let refresh = reply.refreshToken else { return false }
            var renewed = current
            renewed.accessToken = access
            renewed.refreshToken = refresh
            tokens.save(renewed)
            return true
        }
        renewal = task
        let renewed = await task.value
        renewal = nil
        return renewed
    }
}
