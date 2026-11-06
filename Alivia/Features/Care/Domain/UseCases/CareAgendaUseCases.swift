import Foundation

/// Activities of the care agenda from a week back to two weeks ahead of today.
struct GetCareAgendaUseCase {
    static let daysBack = 7
    static let daysAhead = 14
    let repository: CareAgendaRepository

    func callAsFunction(today: LocalDate) async -> NetworkResult<[CareActivity]> {
        await repository.agenda(from: today.plusDays(-Self.daysBack), to: today.plusDays(Self.daysAhead))
    }
}

/// Pending reminders of the caregiver, as the backend orders them (by start and priority).
struct GetRemindersUseCase {
    let repository: CareAgendaRepository
    func callAsFunction() async -> NetworkResult<[CareActivity]> { await repository.reminders() }
}

struct GetMedicationAdministrationUseCase {
    let repository: CareAgendaRepository
    func callAsFunction(_ administrationId: String) async -> NetworkResult<MedicationAdministration> {
        await repository.medicationAdministration(administrationId)
    }
}

/// Registers whether the dose was given or omitted, and when. The backend rejects future times, times before
/// the scheduled start and omissions without a reason; the checks here save the round trip.
struct RecordMedicationOutcomeUseCase {
    static let invalidData = "Revisa la hora y el motivo: la hora no puede ser futura ni anterior al horario programado."
    let repository: CareAgendaRepository

    func callAsFunction(_ administration: MedicationAdministration, result: AdministrationResult, occurredAt: Date,
                        reason: String, notes: String, now: Date) async -> NetworkResult<MedicationAdministration> {
        let cleanReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !administration.canRecord { return .error("Esta administración ya tiene un resultado registrado.", code: 409) }
        if result == .omitted && cleanReason.isEmpty { return .error("Indica el motivo de la omisión.") }
        if occurredAt > now || occurredAt < administration.scheduledStart { return .error(Self.invalidData, code: 400) }
        let outcome = await repository.recordOutcome(
            administration.id, result: result, occurredAt: occurredAt,
            reason: result == .omitted ? cleanReason : nil, notes: cleanNotes.isEmpty ? nil : cleanNotes)
        guard case .error(_, let code) = outcome else { return outcome }
        switch code {
        case 400: return .error(Self.invalidData, code: 400)
        case 403: return .error("Solo el cuidador responsable o un familiar pueden registrar esta administración.", code: 403)
        case 404: return .error("No encontramos la administración.", code: 404)
        case 409: return .error("Esta administración ya tiene un resultado registrado.", code: 409)
        default: return outcome
        }
    }
}
