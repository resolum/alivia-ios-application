import Foundation

enum CareModule {
    private static let repository: CareAgendaRepository = CareAgendaRepositoryImpl(
        facade: CareAgendaFacadeService(client: SharedModule.apiClient))

    static func getCareAgenda() -> GetCareAgendaUseCase { GetCareAgendaUseCase(repository: repository) }
}
