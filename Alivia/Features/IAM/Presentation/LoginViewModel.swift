import Foundation
import Observation

@Observable
final class LoginViewModel {
    var email = ""
    var password = ""
    var showPassword = false
    private(set) var loading = false
    private(set) var error: String?

    private let signIn: SignInUseCase

    init(signIn: SignInUseCase) {
        self.signIn = signIn
    }

    var canSubmit: Bool { !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty }

    func clearError() { error = nil }

    func submit(onSignedIn: @escaping (Session) -> Void) {
        guard !loading else { return }
        loading = true
        error = nil
        Task {
            switch await signIn(email: email, password: password) {
            case .success(let session):
                loading = false
                password = ""
                onSignedIn(session)
            case .error(let message, _):
                loading = false
                error = message
            }
        }
    }
}
