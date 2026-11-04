import Foundation

protocol TechnicalOrderRepository: AnyObject {
    func myOrders() async -> NetworkResult<[TechnicalOrder]>
    func order(_ orderId: Int64) async -> NetworkResult<TechnicalOrder>
    func start(_ orderId: Int64) async -> NetworkResult<TechnicalOrder>
    func recordEvaluation(_ orderId: Int64, result: EvaluationResult, notes: String?) async -> NetworkResult<TechnicalOrder>
    func registerDevice(_ orderId: Int64, alias: String, macAddress: String, type: DeviceType) async -> NetworkResult<TechnicalOrder>
    func removeDevice(_ orderId: Int64, macAddress: String) async -> NetworkResult<TechnicalOrder>
    func recordInstallation(_ orderId: Int64, result: InstallationResult, notes: String?) async -> NetworkResult<TechnicalOrder>
}
