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

/// What the family reported from the web; unknown values from the backend read as `.other`.
enum IncidentProblem: String, CaseIterable {
    case battery = "BATTERY", noResponse = "NO_RESPONSE", falseAlarm = "FALSE_ALARM", connectivity = "CONNECTIVITY",
         physicalDamage = "PHYSICAL_DAMAGE", other = "OTHER"

    var label: String {
        switch self {
        case .battery: return "Batería baja o agotada"
        case .noResponse: return "Sin respuesta"
        case .falseAlarm: return "Falsa alarma"
        case .connectivity: return "Problema de conexión"
        case .physicalDamage: return "Daño físico"
        case .other: return "Otro problema"
        }
    }
}

/// Incident stage as the family follows it on the web.
enum IncidentStatus: String, CaseIterable {
    case open = "OPEN", inEvaluation = "IN_EVALUATION", scheduled = "SCHEDULED", inProgress = "IN_PROGRESS",
         resolved = "RESOLVED", canceled = "CANCELED"

    var label: String {
        switch self {
        case .open: return "Registrada"
        case .inEvaluation: return "En evaluación"
        case .scheduled: return "Visita programada"
        case .inProgress: return "En atención"
        case .resolved: return "Resuelta"
        case .canceled: return "Cancelada"
        }
    }
}

/// What the technician does next with the incident of a maintenance order, step by step.
enum IncidentAction: Equatable { case evaluate, confirmVisit, start, resolve }

/// The incident behind a maintenance order, with the device the family pointed at.
struct IncidentSummary: Equatable {
    let id: Int64
    let code: String
    let status: IncidentStatus?
    let problem: IncidentProblem
    let description: String
    let occurredAt: Date?
    let device: InstalledDevice?
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
    var incident: IncidentSummary? = nil

    /// Name of the home in the lists; the backend keeps who receives the visit, not a home name.
    var homeName: String { contactName.map { "Hogar de \($0)" } ?? "Hogar de la solicitud" }

    var isOpen: Bool { progress == .scheduled || progress == .inProgress }

    /// Next step of a maintenance order: evaluate the report, confirm the visit, start it at the home and resolve it.
    /// Nil for other orders, and once the order is closed.
    var incidentAction: IncidentAction? {
        guard serviceType == .maintenance else { return nil }
        if progress == .inProgress { return .resolve }
        guard progress == .scheduled else { return nil }
        switch incident?.status {
        case .open: return .evaluate
        case .inEvaluation: return .confirmVisit
        default: return .start
        }
    }

    /// A maintenance order the technician already started: its incident is waiting for the resolution.
    var awaitsResolution: Bool { serviceType == .maintenance && progress == .inProgress }
}
