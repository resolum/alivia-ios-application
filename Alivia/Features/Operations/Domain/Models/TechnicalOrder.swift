import Foundation

enum ServiceType: String, CaseIterable { case evaluation = "EVALUATION", installation = "INSTALLATION", maintenance = "MAINTENANCE" }

/// Status the technician sees: a scheduled order is in progress once it was started at the home.
enum OrderProgress { case scheduled, inProgress, completed, canceled }

enum EvaluationResult: String, CaseIterable { case viable = "VIABLE", viableWithAdaptation = "VIABLE_WITH_ADAPTATION", notViable = "NOT_VIABLE" }

enum InstallationResult: String, CaseIterable { case approved = "APPROVED", rejected = "REJECTED" }

enum DeviceType: String, CaseIterable { case microphone = "MICROPHONE", actuator = "ACTUATOR", sensor = "SENSOR", hub = "HUB" }

struct InstalledDevice: Equatable {
    let alias: String
    let macAddress: String
    let type: DeviceType
}

struct TechnicalOrder: Equatable, Identifiable {
    var id: Int64
    var code: String
    var draftId: String
    var serviceType: ServiceType
    var incidentId: Int64?
    var progress: OrderProgress
    var date: LocalDate
    var startTime: LocalTime
    var endTime: LocalTime
    var technicianName: String
    var contactName: String?
    var contactPhone: String?
    var directions: String?
    var evaluationResult: EvaluationResult?
    var installationResult: InstallationResult?
    var completionNotes: String?
    var startedAt: Date?
    var completedAt: Date?
    var installedDevices: [InstalledDevice]

    /// Name of the home in the lists; the backend keeps who receives the visit, not a home name.
    var homeName: String { contactName.map { "Hogar de \($0)" } ?? "Hogar de la solicitud" }

    var isOpen: Bool { progress == .scheduled || progress == .inProgress }
}
