import Foundation

final class AuthRepositoryImpl: AuthRepository {
    static let notAllowed = "Esta aplicación es para técnicos y cuidadores. Ingresa desde la web de Alivia."

    private let facade: AuthFacadeService
    private let tokens: TokenStore

    init(facade: AuthFacadeService, tokens: TokenStore) {
        self.facade = facade
        self.tokens = tokens
    }

    /// Signs in and keeps the session only for the roles that use the mobile app.
    func signIn(_ credentials: SignIn) async -> NetworkResult<Session> {
        let result = await BaseRepository.safeCall { try await facade.signIn(email: credentials.email, password: credentials.password) }
        switch result {
        case .error(let message, let code):
            return code == 401 ? .error("Correo o contraseña incorrectos.", code: 401) : .error(message, code: code)
        case .success(let dto):
            guard let stored = SignInMapper.toStoredSession(dto) else { return .error("La respuesta del servidor no es válida.") }
            let session = SignInMapper.toSession(stored)
            guard session.role.canUseMobileApp else { return .error(AuthRepositoryImpl.notAllowed, code: 403) }
            tokens.save(stored)
            return .success(session)
        }
    }

    func restoreSession() async -> Session? {
        guard let stored = tokens.restore() else { return nil }
        let session = SignInMapper.toSession(stored)
        guard session.role != .unknown, session.role.canUseMobileApp else {
            tokens.clear()
            return nil
        }
        return session
    }

    func signOut() async {
        tokens.clear()
    }
}
