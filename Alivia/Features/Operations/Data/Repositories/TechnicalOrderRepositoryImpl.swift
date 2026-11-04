import Foundation

final class TechnicalOrderRepositoryImpl: TechnicalOrderRepository {
    private let facade: TechnicalOrderFacadeService

    init(facade: TechnicalOrderFacadeService) {
        self.facade = facade
    }

    func myOrders() async -> NetworkResult<[TechnicalOrder]> {
        await BaseRepository.safeCall { try await facade.mine().compactMap { TechnicalOrderMapper.toDomain($0) } }
    }

    func order(_ orderId: Int64) async -> NetworkResult<TechnicalOrder> { await one { try await facade.get(orderId) } }

    func start(_ orderId: Int64) async -> NetworkResult<TechnicalOrder> { await one { try await facade.start(orderId) } }

    func recordEvaluation(_ orderId: Int64, result: EvaluationResult, notes: String?) async -> NetworkResult<TechnicalOrder> {
        await one { try await facade.recordEvaluation(orderId, result: result.rawValue, notes: notes) }
    }

    func registerDevice(_ orderId: Int64, alias: String, macAddress: String, type: DeviceType) async -> NetworkResult<TechnicalOrder> {
        await one { try await facade.registerDevice(orderId, alias: alias, macAddress: macAddress, type: type.rawValue) }
    }

    func removeDevice(_ orderId: Int64, macAddress: String) async -> NetworkResult<TechnicalOrder> {
        await one { try await facade.removeDevice(orderId, macAddress: macAddress) }
    }

    func recordInstallation(_ orderId: Int64, result: InstallationResult, notes: String?) async -> NetworkResult<TechnicalOrder> {
        await one { try await facade.recordInstallation(orderId, result: result.rawValue, notes: notes) }
    }

    private func one(_ call: () async throws -> TechnicalOrderDto) async -> NetworkResult<TechnicalOrder> {
        switch await BaseRepository.safeCall(call) {
        case .error(let message, let code): return .error(message, code: code)
        case .success(let dto):
            guard let order = TechnicalOrderMapper.toDomain(dto) else { return .error("La respuesta del servidor no es válida.") }
            return .success(order)
        }
    }
}
