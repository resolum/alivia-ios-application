import Foundation

final class CareAgendaRepositoryImpl: CareAgendaRepository {
    private let facade: CareAgendaFacadeService

    init(facade: CareAgendaFacadeService) {
        self.facade = facade
    }

    func agenda(from: LocalDate, to: LocalDate) async -> NetworkResult<[CareActivity]> {
        await BaseRepository.safeCall {
            try await facade.agenda(from: from, to: to).compactMap { CareActivityMapper.toDomain($0) }
        }
    }

    func reminders() async -> NetworkResult<[CareActivity]> {
        await BaseRepository.safeCall { try await facade.reminders().compactMap { CareActivityMapper.toDomain($0) } }
    }

    func medicationAdministration(_ administrationId: String) async -> NetworkResult<MedicationAdministration> {
        switch await BaseRepository.safeCall({ try await facade.medicationAdministration(administrationId) }) {
        case .error(let message, let code): return .error(message, code: code)
        case .success(let dto):
            guard let administration = MedicationAdministrationMapper.toDomain(dto) else {
                return .error("La respuesta del servidor no es válida.")
            }
            return .success(administration)
        }
    }

    func recordOutcome(_ administrationId: String, result: AdministrationResult, occurredAt: Date,
                       reason: String?, notes: String?) async -> NetworkResult<MedicationAdministration> {
        let body = MedicationOutcomeRequestDto(result: result.rawValue, occurredAt: Self.limaMoment(occurredAt),
                                               reason: reason, notes: notes)
        return await updated { try await facade.recordOutcome(administrationId, body: body) }
    }

    private func updated(_ call: () async throws -> MedicationAdministrationDto) async -> NetworkResult<MedicationAdministration> {
        switch await BaseRepository.safeCall(call) {
        case .error(let message, let code): return .error(message, code: code)
        case .success(let dto):
            guard let administration = MedicationAdministrationMapper.toDomain(dto) else {
                return .error("La respuesta del servidor no es válida.")
            }
            return .success(administration)
        }
    }

    /// "2026-10-26T08:15:00" in Lima time, without a zone, as the backend expects it.
    private static func limaMoment(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = LocalDate.calendar
        formatter.timeZone = LocalDate.zone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.string(from: date)
    }
}
