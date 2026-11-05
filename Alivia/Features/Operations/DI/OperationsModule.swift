import Foundation

enum OperationsModule {
    private static let repository: TechnicalOrderRepository = TechnicalOrderRepositoryImpl(
        facade: TechnicalOrderFacadeService(client: SharedModule.apiClient))

    static func getMyOrders() -> GetMyOrdersUseCase { GetMyOrdersUseCase(repository: repository) }
    static func getOrder() -> GetOrderUseCase { GetOrderUseCase(repository: repository) }
    static func startOrder() -> StartOrderUseCase { StartOrderUseCase(repository: repository) }
    static func recordEvaluation() -> RecordEvaluationUseCase { RecordEvaluationUseCase(repository: repository) }
    static func findInstallationOfRequest() -> FindInstallationOfRequestUseCase { FindInstallationOfRequestUseCase(repository: repository) }
    static func registerDevice() -> RegisterDeviceUseCase { RegisterDeviceUseCase(repository: repository) }
    static func removeDevice() -> RemoveDeviceUseCase { RemoveDeviceUseCase(repository: repository) }
    static func completeInstallation() -> CompleteInstallationUseCase { CompleteInstallationUseCase(repository: repository) }
    static func advanceIncident() -> AdvanceIncidentUseCase { AdvanceIncidentUseCase(repository: repository) }
    static func resolveIncident() -> ResolveIncidentUseCase { ResolveIncidentUseCase(repository: repository) }
}
