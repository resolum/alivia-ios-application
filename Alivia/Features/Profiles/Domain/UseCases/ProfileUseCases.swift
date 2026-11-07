import Foundation

struct GetMyProfileUseCase {
    let repository: ProfileRepository

    func callAsFunction() async -> NetworkResult<UserProfile> {
        let result = await repository.me()
        if case .error(_, 404) = result { return .error("Tu cuenta todavía no tiene un perfil.", code: 404) }
        return result
    }
}

/// Sends only what changed. Names cannot be empty and the phone is digits only (E.164 without the plus).
struct UpdateMyProfileUseCase {
    static let invalidData = "Revisa tus datos: hay información que no es válida."
    let repository: ProfileRepository

    func callAsFunction(current: UserProfile, firstName: String, lastName: String, phone: String) async -> NetworkResult<UserProfile> {
        let first = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = phone.filter { !$0.isWhitespace && $0 != "+" }
        if first.isEmpty { return .error("Escribe tus nombres.") }
        if last.isEmpty { return .error("Escribe tus apellidos.") }
        if !digits.allSatisfy(\.isASCIIDigit) { return .error("El teléfono solo puede tener números.") }
        if digits.isEmpty && current.phoneNumber != nil { return .error("El teléfono no puede quedar vacío.") }

        var changes = ProfileChanges()
        if first != current.firstName { changes.firstName = first }
        if last != current.lastName { changes.lastName = last }
        if !digits.isEmpty && digits != current.phoneNumber { changes.phoneNumber = digits }
        if changes.isEmpty { return .success(current) }
        return await send(changes)
    }

    func callAsFunction(photo: Data) async -> NetworkResult<UserProfile> {
        await send(ProfileChanges(photo: photo))
    }

    private func send(_ changes: ProfileChanges) async -> NetworkResult<UserProfile> {
        let result = await repository.update(changes)
        if case .error(_, 400) = result { return .error(Self.invalidData, code: 400) }
        return result
    }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
