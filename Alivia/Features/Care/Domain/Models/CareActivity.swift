import Foundation

enum CareActivityType: String, CaseIterable, Sendable {
    case medication = "MEDICATION"
    case appointment = "APPOINTMENT"
    case therapy = "THERAPY"
    case meal = "MEAL"
    case bath = "BATH"
    case exercise = "EXERCISE"
    case other = "OTHER"
}

enum CareActivityStatus: String, Sendable {
    case scheduled = "SCHEDULED"
    case inProgress = "IN_PROGRESS"
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"
    case missed = "MISSED"
    case omitted = "OMITTED"
}

enum CarePriority: String, Sendable {
    case high = "HIGH"
    case medium = "MEDIUM"
    case low = "LOW"
    case routine = "ROUTINE"
}

/// One activity of the care agenda assigned to a day, as the caregiver sees it in the list.
struct CareActivity: Identifiable, Hashable, Sendable {
    let id: String
    let assignmentId: Int64?
    let title: String
    let type: CareActivityType
    let assistedPerson: String
    let responsible: String
    let date: LocalDate
    let startTime: LocalTime
    let endTime: LocalTime?
    let status: CareActivityStatus
    let recurring: Bool
    let priority: CarePriority

    /// Id of the medication administration of this occurrence: "<assignmentId>-<yyyyMMdd>".
    var administrationId: String? {
        guard type == .medication, let assignmentId else { return nil }
        return String(format: "%lld-%04d%02d%02d", assignmentId, date.year, date.month, date.day)
    }
}
