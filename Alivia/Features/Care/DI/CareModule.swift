import Foundation

enum CareModule {
    private static let repository: CareAgendaRepository = CareAgendaRepositoryImpl(
        facade: CareAgendaFacadeService(client: SharedModule.apiClient))

    static func getCareAgenda() -> GetCareAgendaUseCase { GetCareAgendaUseCase(repository: repository) }
    static func getReminders() -> GetRemindersUseCase { GetRemindersUseCase(repository: repository) }
    static func getMedicationAdministration() -> GetMedicationAdministrationUseCase { GetMedicationAdministrationUseCase(repository: repository) }
}
