import Foundation

/// Medication administration as `/api/v1/medication-administrations/{id}` returns it.
struct MedicationAdministrationDto: Decodable {
    var administrationId: String?
    var medication: String?
    var assistedPerson: CareActivityDto.AssistedPersonDto?
    var date: String?
    var startTime: String?
    var endTime: String?
    var responsible: CareActivityDto.ResponsibleDto?
    var status: String?
    var outcome: OutcomeDto?

    struct OutcomeDto: Decodable {
        var result: String?
        var occurredAt: String?
        var late: Bool?
        var reason: String?
        var notes: String?
    }
}

struct MedicationOutcomeRequestDto: Encodable {
    let result: String
    let occurredAt: String
    let reason: String?
    let notes: String?
}

enum MedicationAdministrationMapper {
    static func toDomain(_ dto: MedicationAdministrationDto) -> MedicationAdministration? {
        guard let id = dto.administrationId,
              let date = LocalDate(iso: dto.date),
              let start = LocalTime(iso: dto.startTime) else { return nil }
        return MedicationAdministration(
            id: id,
            medication: nonBlank(dto.medication) ?? "Medicamento",
            assistedPerson: nonBlank(dto.assistedPerson?.name) ?? "Persona asistida",
            responsible: nonBlank(dto.responsible?.name) ?? nonBlank(dto.responsible?.email) ?? "Sin responsable",
            date: date,
            startTime: start,
            endTime: LocalTime(iso: dto.endTime),
            status: dto.status.flatMap(AdministrationStatus.init(rawValue:)) ?? .pending,
            outcome: dto.outcome.flatMap { outcome($0) })
    }

    private static func outcome(_ dto: MedicationAdministrationDto.OutcomeDto) -> AdministrationOutcome? {
        guard let result = dto.result.flatMap(AdministrationResult.init(rawValue:)) else { return nil }
        // "2026-10-26T08:15:00" has no zone: it is the local moment, so read it as date and time.
        let parts = dto.occurredAt?.split(separator: "T", maxSplits: 1).map(String.init) ?? []
        return AdministrationOutcome(
            result: result,
            occurredDate: LocalDate(iso: parts.first),
            occurredTime: LocalTime(iso: parts.count > 1 ? parts[1] : nil),
            late: dto.late ?? false,
            reason: nonBlank(dto.reason),
            notes: nonBlank(dto.notes))
    }

    private static func nonBlank(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
