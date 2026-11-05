import Foundation
import Observation

/// The technician closes the incident of a started maintenance order; the family then sees it resolved.
@Observable
final class ResolveIncidentViewModel {
    private(set) var order: TechnicalOrder?
    private(set) var loadError: String?
    var diagnosis = "" { didSet { diagnosis = String(diagnosis.prefix(ResolveIncidentUseCase.maxResolution)); error = nil } }
    var workPerformed = "" { didSet { workPerformed = String(workPerformed.prefix(ResolveIncidentUseCase.maxResolution)); error = nil } }
    private(set) var saving = false
    private(set) var error: String?

    private let orderId: Int64
    private let getOrder: GetOrderUseCase
    private let resolveIncident: ResolveIncidentUseCase

    init(orderId: Int64, getOrder: GetOrderUseCase, resolveIncident: ResolveIncidentUseCase) {
        self.orderId = orderId
        self.getOrder = getOrder
        self.resolveIncident = resolveIncident
    }

    var canSubmit: Bool {
        order != nil && !saving
            && !diagnosis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !workPerformed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func load() async {
        switch await getOrder(orderId) {
        case .success(let data): order = data
        case .error(let message, _): loadError = message
        }
    }

    func submit(onResolved: @escaping (Int64) -> Void) async {
        guard let order, !saving else { return }
        saving = true
        error = nil
        let outcome = await resolveIncident(order, diagnosis: diagnosis, workPerformed: workPerformed)
        saving = false
        switch outcome {
        case .success(let data):
            self.order = data
            onResolved(data.id)
        case .error(let message, _):
            error = message
        }
    }
}
