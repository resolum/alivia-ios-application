import Foundation

/// Personal profile of the signed-in account. Email, DNI and birth date are read-only.
struct UserProfile: Hashable, Sendable {
    let firstName: String
    let lastName: String
    let email: String
    /// E.164 without the plus sign, as the backend keeps it.
    let phoneNumber: String?
    let dni: String?
    let birthDate: LocalDate?
    let photoURL: URL?

    var fullName: String { [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ") }

    var initials: String {
        let letters = [firstName, lastName].compactMap { $0.first }.prefix(2)
        return String(letters).uppercased(with: Formats.locale)
    }
}

/// Fields the user changed; the ones left nil stay as they are.
struct ProfileChanges: Sendable {
    var firstName: String?
    var lastName: String?
    var phoneNumber: String?
    var photo: Data?

    var isEmpty: Bool { firstName == nil && lastName == nil && phoneNumber == nil && photo == nil }
}
