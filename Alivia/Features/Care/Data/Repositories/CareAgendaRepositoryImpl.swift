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
}
