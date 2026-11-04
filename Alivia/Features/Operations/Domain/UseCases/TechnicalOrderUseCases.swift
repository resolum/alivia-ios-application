import Foundation

struct GetMyOrdersUseCase {
    let repository: TechnicalOrderRepository
    func callAsFunction() async -> NetworkResult<[TechnicalOrder]> { await repository.myOrders() }
}

struct GetOrderUseCase {
    let repository: TechnicalOrderRepository
    func callAsFunction(_ orderId: Int64) async -> NetworkResult<TechnicalOrder> { await repository.order(orderId) }
}

struct StartOrderUseCase {
    let repository: TechnicalOrderRepository
    func callAsFunction(_ orderId: Int64) async -> NetworkResult<TechnicalOrder> { await repository.start(orderId) }
}

/// Records the technician's decision at the home. A viable home moves the request to the family's confirmation
/// on the web; the installation order opens only after the family confirms.
struct RecordEvaluationUseCase {
    let repository: TechnicalOrderRepository

    func callAsFunction(_ order: TechnicalOrder, result: EvaluationResult, notes: String) async -> NetworkResult<TechnicalOrder> {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNotes = trimmed.isEmpty ? nil : trimmed
        if result == .viableWithAdaptation && cleanNotes == nil {
            return .error("Describe la adaptación que necesita el hogar.")
        }
        if (cleanNotes?.count ?? 0) > 300 { return .error("Las notas no pueden pasar de 300 caracteres.") }
        return await repository.recordEvaluation(order.id, result: result, notes: cleanNotes)
    }
}

/// The open installation order of the same request, once the family confirmed and the backend opened it.
struct FindInstallationOfRequestUseCase {
    let repository: TechnicalOrderRepository

    func callAsFunction(_ draftId: String) async -> NetworkResult<TechnicalOrder?> {
        switch await repository.myOrders() {
        case .success(let orders):
            return .success(orders.first { $0.draftId == draftId && $0.serviceType == .installation && $0.isOpen })
        case .error(let message, let code):
            return .error(message, code: code)
        }
    }
}

struct RegisterDeviceUseCase {
    let repository: TechnicalOrderRepository

    func callAsFunction(_ order: TechnicalOrder, alias: String, macAddress: String, type: DeviceType?) async -> NetworkResult<TechnicalOrder> {
        let cleanAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        let mac = MacAddress.format(macAddress)
        if cleanAlias.isEmpty { return .error("Asigna un alias al dispositivo.") }
        if cleanAlias.count > 60 { return .error("El alias no puede pasar de 60 caracteres.") }
        if !MacAddress.isValid(mac) { return .error("La dirección MAC necesita 12 dígitos hexadecimales.") }
        if order.installedDevices.contains(where: { $0.macAddress == mac }) { return .error("Ese dispositivo ya está registrado en esta orden.") }
        guard let type else { return .error("Elige el tipo de dispositivo.") }
        return await repository.registerDevice(order.id, alias: cleanAlias, macAddress: mac, type: type)
    }
}

struct RemoveDeviceUseCase {
    let repository: TechnicalOrderRepository
    func callAsFunction(_ orderId: Int64, macAddress: String) async -> NetworkResult<TechnicalOrder> {
        await repository.removeDevice(orderId, macAddress: macAddress)
    }
}

struct CompleteInstallationUseCase {
    let repository: TechnicalOrderRepository

    func callAsFunction(_ order: TechnicalOrder, result: InstallationResult, notes: String) async -> NetworkResult<TechnicalOrder> {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNotes = trimmed.isEmpty ? nil : trimmed
        if (cleanNotes?.count ?? 0) > 300 { return .error("Las notas no pueden pasar de 300 caracteres.") }
        return await repository.recordInstallation(order.id, result: result, notes: cleanNotes)
    }
}
