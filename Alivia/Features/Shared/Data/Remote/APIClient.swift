import Foundation

/// Failure of a backend call before it becomes a message for the screen.
enum APIError: Error {
    case http(status: Int, detail: String?)
    case transport
    case invalidResponse
}

/// Text fields and an optional file sent as `multipart/form-data`.
struct MultipartForm {
    struct File {
        let field: String
        let filename: String
        let mimeType: String
        let data: Data
    }

    var fields: [String: String] = [:]
    var file: File?
    let boundary = "alivia-\(UUID().uuidString)"

    var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    func encoded() -> Data {
        var body = Data()
        func append(_ text: String) { body.append(Data(text.utf8)) }
        for (name, value) in fields.sorted(by: { $0.key < $1.key }) {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        if let file {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(file.field)\"; filename=\"\(file.filename)\"\r\n")
            append("Content-Type: \(file.mimeType)\r\n\r\n")
            body.append(file.data)
            append("\r\n")
        }
        append("--\(boundary)--\r\n")
        return body
    }
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

    private enum Payload {
        case none
        case json(any Encodable)
        case multipart(MultipartForm)
    }

    func send<Response: Decodable>(_ method: String, _ path: String, body: (any Encodable)? = nil,
                                   as type: Response.Type = Response.self) async throws -> Response {
        try await request(method, path, payload: body.map(Payload.json) ?? .none)
    }

    /// Same call as `send` for endpoints that answer without a body (202, 204).
    func sendWithoutResponse(_ method: String, _ path: String, body: (any Encodable)? = nil) async throws {
        _ = try await perform(method, path, payload: body.map(Payload.json) ?? .none)
    }

    /// Same call as `send` with a `multipart/form-data` body: session token, renewal and errors work the same.
    func sendMultipart<Response: Decodable>(_ method: String, _ path: String, form: MultipartForm,
                                            as type: Response.Type = Response.self) async throws -> Response {
        try await request(method, path, payload: .multipart(form))
    }

    private func request<Response: Decodable>(_ method: String, _ path: String, payload: Payload) async throws -> Response {
        let data = try await perform(method, path, payload: payload)
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.invalidResponse
        }
    }

    private func perform(_ method: String, _ path: String, payload: Payload) async throws -> Data {
        let (data, status, sentToken) = try await execute(method, path, payload: payload)
        guard status == 401, !path.contains("api/v1/auth/"), tokens.session != nil else {
            return try check(data, status)
        }
        // Another call may have renewed the session while this one waited.
        if let sentToken, sentToken != tokens.accessToken {
            let (retryData, retryStatus, _) = try await execute(method, path, payload: payload)
            return try check(retryData, retryStatus)
        }
        guard await renewSession() else {
            tokens.clear()
            onSessionExpired()
            throw APIError.http(status: 401, detail: nil)
        }
        let (retryData, retryStatus, _) = try await execute(method, path, payload: payload)
        return try check(retryData, retryStatus)
    }

    private func execute(_ method: String, _ path: String, payload: Payload) async throws -> (Data, Int, String?) {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw APIError.transport }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let token = tokens.accessToken
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        switch payload {
        case .none:
            break
        case .json(let body):
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONEncoder().encode(body)
        case .multipart(let form):
            request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
            request.httpBody = form.encoded()
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
                                                              payload: .json(RefreshRequest(refreshToken: current.refreshToken))),
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
