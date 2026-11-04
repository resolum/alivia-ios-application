import Foundation

struct SignInUseCase {
    let repository: AuthRepository

    private static let email = /^[^@\s]+@[^@\s]+\.[^@\s]+$/

    func callAsFunction(email: String, password: String) async -> NetworkResult<Session> {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanEmail.isEmpty || password.isEmpty { return .error("Ingresa tu correo y tu contraseña.") }
        if (try? SignInUseCase.email.wholeMatch(in: cleanEmail)) == nil { return .error("Ingresa un correo válido.") }
        return await repository.signIn(SignIn(email: cleanEmail, password: password))
    }
}

struct RestoreSessionUseCase {
    let repository: AuthRepository
    func callAsFunction() async -> Session? { await repository.restoreSession() }
}

struct SignOutUseCase {
    let repository: AuthRepository
    func callAsFunction() async { await repository.signOut() }
}
