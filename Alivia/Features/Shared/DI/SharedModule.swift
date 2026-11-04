import Foundation

/// Objects shared by every feature: the stored session and the backend client.
enum SharedModule {
    static let tokenStore = TokenStore(storage: KeychainSessionStorage())
    static let apiClient = APIClient(baseURL: AppConfig.apiBaseURL, tokens: tokenStore)
}
