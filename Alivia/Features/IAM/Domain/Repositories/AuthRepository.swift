import Foundation

protocol AuthRepository: AnyObject {
    func signIn(_ credentials: SignIn) async -> NetworkResult<Session>
    func restoreSession() async -> Session?
    func signOut() async
}
