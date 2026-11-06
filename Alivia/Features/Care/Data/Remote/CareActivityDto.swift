import Foundation

/// Activity of `/api/v1/care-agenda` as the backend returns it.
struct CareActivityDto: Decodable {
    var activity: ActivityDto?
    var assignmentId: Int64?
    var assistedPerson: AssistedPersonDto?
    var date: String?
    var startTime: String?
    var endTime: String?
    var responsible: ResponsibleDto?
    var recurring: Bool?
    var status: String?
    var priority: String?

    struct ActivityDto: Decodable {
        var id: Int64?
        var title: String?
        var type: String?
    }

    struct AssistedPersonDto: Decodable {
        var name: String?
    }

    struct ResponsibleDto: Decodable {
        var type: String?
        var name: String?
        var email: String?
    }
}

enum CareActivityMapper {
    static func toDomain(_ dto: CareActivityDto) -> CareActivity? {
        guard let date = LocalDate(iso: dto.date),
              let start = LocalTime(iso: dto.startTime) else { return nil }
        let title = dto.activity?.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let type = dto.activity?.type.flatMap(CareActivityType.init(rawValue:)) ?? .other
        let status = dto.status.flatMap(CareActivityStatus.init(rawValue:)) ?? .scheduled
        let key = [dto.assignmentId.map(String.init), dto.activity?.id.map(String.init), dto.date, dto.startTime]
            .compactMap { $0 }.joined(separator: "-")
        return CareActivity(
            id: key,
            assignmentId: dto.assignmentId,
            title: title.isEmpty ? "Actividad" : title,
            type: type,
            assistedPerson: nonBlank(dto.assistedPerson?.name) ?? "Persona asistida",
            responsible: nonBlank(dto.responsible?.name) ?? nonBlank(dto.responsible?.email) ?? "Sin responsable",
            date: date,
            startTime: start,
            endTime: LocalTime(iso: dto.endTime),
            status: status,
            recurring: dto.recurring ?? false,
            priority: dto.priority.flatMap(CarePriority.init(rawValue:)) ?? .routine)
    }

    private static func nonBlank(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

final class CareAgendaFacadeService {
    private let client: APIClient
    init(client: APIClient) { self.client = client }

    func agenda(from: LocalDate, to: LocalDate) async throws -> [CareActivityDto] {
        try await client.send("GET", "api/v1/care-agenda?from=\(from.iso)&to=\(to.iso)")
    }

    /// Scheduled or in-progress occurrences from yesterday on; same JSON as the agenda.
    func reminders() async throws -> [CareActivityDto] { try await client.send("GET", "api/v1/reminders") }

    func medicationAdministration(_ administrationId: String) async throws -> MedicationAdministrationDto {
        try await client.send("GET", "api/v1/medication-administrations/\(administrationId)")
    }
}

private extension LocalDate {
    /// "2026-11-03", the format the backend expects in query strings.
    var iso: String { String(format: "%04d-%02d-%02d", year, month, day) }
}
