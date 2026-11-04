import Foundation

enum AuthModule {
    private static let repository: AuthRepository = AuthRepositoryImpl(
        facade: AuthFacadeService(client: SharedModule.apiClient), tokens: SharedModule.tokenStore)

    static func signInUseCase() -> SignInUseCase { SignInUseCase(repository: repository) }
    static func restoreSessionUseCase() -> RestoreSessionUseCase { RestoreSessionUseCase(repository: repository) }
    static func signOutUseCase() -> SignOutUseCase { SignOutUseCase(repository: repository) }
}
