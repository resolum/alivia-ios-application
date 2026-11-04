import XCTest
@testable import Alivia

final class SignInRulesTests: XCTestCase {
    func testOnlyTechniciansAndCaregiversUseTheMobileApp() {
        XCTAssertTrue(UserRole.from("TECHNICIAN").canUseMobileApp)
        XCTAssertTrue(UserRole.from("CAREGIVER").canUseMobileApp)
        XCTAssertFalse(UserRole.from("SUBSCRIPTION_MANAGER").canUseMobileApp)
        XCTAssertFalse(UserRole.from("ADMINISTRATOR").canUseMobileApp)
        XCTAssertEqual(UserRole.unknown, UserRole.from("OTHER"))
        XCTAssertEqual(UserRole.unknown, UserRole.from(nil))
    }

    func testChecksTheCredentialsBeforeCallingTheBackend() async {
        let repository = FakeAuthRepository()
        let signIn = SignInUseCase(repository: repository)

        let empty = await signIn(email: "", password: "x")
        XCTAssertNotNil(empty.errorMessage)
        let invalid = await signIn(email: "tecnico", password: "x")
        XCTAssertEqual("Ingresa un correo válido.", invalid.errorMessage)
        XCTAssertEqual(0, repository.calls)

        let ok = await signIn(email: " tecnico@alivia.pe ", password: "secret")
        XCTAssertEqual("tecnico@alivia.pe", ok.value?.email)
        XCTAssertEqual(1, repository.calls)
    }

    func testKeepsTheSessionOnlyForTheRolesOfTheApp() async {
        let tokens = TokenStore(storage: InMemorySessionStorage())
        let session = StoredSession(accessToken: "a", refreshToken: "r", accountId: "1", email: "gestor@alivia.pe",
                                    role: "SUBSCRIPTION_MANAGER")
        XCTAssertEqual(UserRole.subscriptionManager, SignInMapper.toSession(session).role)
        tokens.save(session)
        let repository = AuthRepositoryImpl(facade: AuthFacadeService(client: APIClient(baseURL: URL(string: "http://localhost/")!,
                                                                                         tokens: tokens)), tokens: tokens)
        let restored = await repository.restoreSession()
        XCTAssertNil(restored)
        XCTAssertNil(tokens.session)
    }
}

private final class FakeAuthRepository: AuthRepository {
    var calls = 0

    func signIn(_ credentials: SignIn) async -> NetworkResult<Session> {
        calls += 1
        return .success(Session(accountId: "id", email: credentials.email, role: .technician))
    }

    func restoreSession() async -> Session? { nil }
    func signOut() async {}
}
