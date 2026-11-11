import Foundation
import Observation

/// Where the technician goes after the decision: the summary, which waits for the family when the home is viable.
enum EvaluationNext: Equatable {
    case completed(orderId: Int64)
}

@Observable
final class EvaluationViewModel {
    private(set) var order: TechnicalOrder?
    private(set) var loadError: String?
    private(set) var result: EvaluationResult?
    var notes = "" { didSet { if notes.count > 300 { notes = String(notes.prefix(300)) }; error = nil } }
    var confirmingRejection = false
    private(set) var saving = false
    private(set) var error: String?

    private let orderId: Int64
    private let getOrder: GetOrderUseCase
    private let recordEvaluation: RecordEvaluationUseCase

    init(orderId: Int64, getOrder: GetOrderUseCase, recordEvaluation: RecordEvaluationUseCase) {
        self.orderId = orderId
        self.getOrder = getOrder
        self.recordEvaluation = recordEvaluation
    }

    func load() async {
        switch await getOrder(orderId) {
        case .success(let data): order = data
        case .error(let message, _): loadError = message
        }
    }

    func select(_ value: EvaluationResult) {
        result = value
        error = nil
    }

    func dismissRejection() { confirmingRejection = false }

    /// A not viable home asks for a second confirmation, because it closes the request and releases the payment.
    func submit(confirmed: Bool = false, onNext: @escaping (EvaluationNext) -> Void) {
        guard let result else {
            error = "Elige el resultado de la evaluación."
            return
        }
        if result == .notViable && !confirmed {
            confirmingRejection = true
            return
        }
        guard let order else { return }
        saving = true
        error = nil
        confirmingRejection = false
        Task {
            switch await recordEvaluation(order, result: result, notes: notes) {
            case .error(let message, _):
                saving = false
                error = message
            case .success:
                saving = false
                onNext(.completed(orderId: order.id))
            }
        }
    }
}
