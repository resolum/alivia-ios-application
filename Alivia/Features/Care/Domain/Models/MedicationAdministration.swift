import Foundation

enum AdministrationStatus: String, Sendable {
    case pending = "PENDING"
    case administered = "ADMINISTERED"
    case omitted = "OMITTED"
    case missed = "MISSED"
    case cancelled = "CANCELLED"
}

enum AdministrationResult: String, Sendable {
    case administered = "ADMINISTERED"
    case omitted = "OMITTED"
}

/// What the caregiver registered for the dose: given or omitted, when, and why.
struct AdministrationOutcome: Hashable, Sendable {
    let result: AdministrationResult
    let occurredDate: LocalDate?
    let occurredTime: LocalTime?
    let late: Bool
    let reason: String?
    let notes: String?
}

struct MedicationAdministration: Hashable, Sendable {
    let id: String
    let medication: String
    let assistedPerson: String
    let responsible: String
    let date: LocalDate
    let startTime: LocalTime
    let endTime: LocalTime?
    let status: AdministrationStatus
    let outcome: AdministrationOutcome?
}
