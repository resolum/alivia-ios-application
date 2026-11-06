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
}
