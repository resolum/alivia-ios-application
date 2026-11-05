import Foundation
import Observation

@Observable
final class OrderDetailViewModel {
    private(set) var loading = true
    private(set) var order: TechnicalOrder?
    private(set) var error: String?
    var confirmingStart = false
    private(set) var starting = false
    private(set) var startError: String?
    private(set) var advancing = false
    private(set) var advanceError: String?

    private let orderId: Int64
    private let getOrder: GetOrderUseCase
    private let startOrder: StartOrderUseCase
    private let advanceIncident: AdvanceIncidentUseCase?

    init(orderId: Int64, getOrder: GetOrderUseCase, startOrder: StartOrderUseCase, advanceIncident: AdvanceIncidentUseCase? = nil) {
        self.orderId = orderId
        self.getOrder = getOrder
        self.startOrder = startOrder
        self.advanceIncident = advanceIncident
    }

    /// Evaluates the incident or confirms its visit, the step the order shows; the order comes back updated.
    func advance() async {
        guard let order, let advanceIncident, !advancing else { return }
        advancing = true
        advanceError = nil
        switch await advanceIncident(order) {
        case .success(let data): self.order = data
        case .error(let message, _): advanceError = message
        }
        advancing = false
    }

    func load() async {
        loading = order == nil
        error = nil
        switch await getOrder(orderId) {
        case .success(let data): order = data
        case .error(let message, _): error = message
        }
        loading = false
    }

    func askToStart() {
        confirmingStart = true
        startError = nil
    }

    func cancelStart() {
        confirmingStart = false
        startError = nil
    }

    /// Starts the visit and, once the backend records it, lets the screen move on to the order's process.
    func start(onStarted: @escaping (TechnicalOrder) -> Void) {
        starting = true
        startError = nil
        Task {
            switch await startOrder(orderId) {
            case .success(let data):
                starting = false
                confirmingStart = false
                order = data
                onStarted(data)
            case .error(let message, _):
                starting = false
                startError = message
            }
        }
    }
}
