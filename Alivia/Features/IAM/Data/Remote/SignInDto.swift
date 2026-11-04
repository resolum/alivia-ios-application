import Foundation

struct SignInRequestDto: Encodable {
    let email: String
    let password: String
}

/// Body of `POST /api/v1/auth/sign-in`.
struct SignInResponseDto: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let tokenType: String?
    let expiresIn: Int64?
    let user: AccountDto?
}

struct AccountDto: Decodable {
    let id: String?
    let email: String?
    let role: String?
    let status: String?
    let profileId: Int64?
}

enum SignInMapper {
    static func toStoredSession(_ dto: SignInResponseDto) -> StoredSession? {
        guard let access = dto.accessToken, let refresh = dto.refreshToken, let user = dto.user else { return nil }
        return StoredSession(accessToken: access, refreshToken: refresh, accountId: user.id ?? "",
                             email: user.email ?? "", role: user.role ?? "")
    }

    static func toSession(_ stored: StoredSession) -> Session {
        Session(accountId: stored.accountId, email: stored.email, role: UserRole.from(stored.role))
    }
}

/// Calls of the IAM context.
final class AuthFacadeService {
    private let client: APIClient
    init(client: APIClient) { self.client = client }

    func signIn(email: String, password: String) async throws -> SignInResponseDto {
        try await client.send("POST", "api/v1/auth/sign-in", body: SignInRequestDto(email: email, password: password))
    }
}
