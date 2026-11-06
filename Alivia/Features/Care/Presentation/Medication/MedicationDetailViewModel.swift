import Foundation
import Observation

@Observable
final class MedicationDetailViewModel {
    private(set) var loading = true
    private(set) var administration: MedicationAdministration?
    private(set) var error: String?

    private let administrationId: String
    private let getAdministration: GetMedicationAdministrationUseCase

    init(administrationId: String, getAdministration: GetMedicationAdministrationUseCase) {
        self.administrationId = administrationId
        self.getAdministration = getAdministration
    }

    func load() async {
        loading = administration == nil
        error = nil
        switch await getAdministration(administrationId) {
        case .success(let data): administration = data
        case .error(let message, _): error = message
        }
        loading = false
    }
}
