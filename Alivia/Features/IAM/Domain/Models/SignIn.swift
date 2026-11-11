import Foundation

/// Roles of the Alivia accounts, as the backend names them.
enum UserRole: String, CaseIterable {
    case administrator = "ADMINISTRATOR"
    case caregiver = "CAREGIVER"
    case technician = "TECHNICIAN"
    case subscriptionManager = "SUBSCRIPTION_MANAGER"
    case assistedPerson = "ASSISTED_PERSON"
    case unknown = "UNKNOWN"

    /// The mobile app is for the technicians in the field and for the families (caregivers).
    var canUseMobileApp: Bool { self == .technician || self == .caregiver }

    static func from(_ value: String?) -> UserRole {
        guard let value, value != UserRole.unknown.rawValue else { return .unknown }
        return UserRole(rawValue: value) ?? .unknown
    }
}

/// Credentials typed in the sign-in screen.
struct SignIn: Equatable {
    let email: String
    let password: String
}

/// Signed-in account.
struct Session: Equatable {
    let accountId: String
    let email: String
    let role: UserRole
}
