import Foundation
import Observation

@Observable
final class MedicationDetailViewModel {
    private(set) var loading = true
    private(set) var administration: MedicationAdministration?
    private(set) var error: String?

    var recording = false
    var result: AdministrationResult = .administered { didSet { recordError = nil } }
    var occurredAt = Date() { didSet { recordError = nil } }
    var reason = "" { didSet { reason = String(reason.prefix(Self.maxText)); recordError = nil } }
    var notes = "" { didSet { notes = String(notes.prefix(Self.maxText)); recordError = nil } }
    private(set) var saving = false
    private(set) var recordError: String?

    static let maxText = 300

    private let administrationId: String
    private let getAdministration: GetMedicationAdministrationUseCase
    private let recordOutcome: RecordMedicationOutcomeUseCase

    init(administrationId: String, getAdministration: GetMedicationAdministrationUseCase,
         recordOutcome: RecordMedicationOutcomeUseCase) {
        self.administrationId = administrationId
        self.getAdministration = getAdministration
        self.recordOutcome = recordOutcome
    }

    var canSubmit: Bool {
        guard let administration, administration.canRecord, !saving else { return false }
        return result == .administered || !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Opens the form with the time set to now.
    func startRecording() {
        result = .administered
        occurredAt = Date()
        reason = ""
        notes = ""
        recordError = nil
        recording = true
    }

    /// Sends the result; the detail shows the updated administration and the form closes.
    /// When the dose already has a result, the detail is loaded again to show it.
    func submit() async {
        guard let administration, canSubmit else { return }
        saving = true
        recordError = nil
        let outcome = await recordOutcome(administration, result: result, occurredAt: occurredAt,
                                          reason: reason, notes: notes, now: Date())
        saving = false
        switch outcome {
        case .success(let data):
            self.administration = data
            recording = false
        case .error(let message, let code):
            recordError = message
            if code == 409 { await load() }
        }
    }

    func load() async {
        loading = administration == nil
        error = nil
        switch await getAdministration(administrationId) {
        case .success(let data): administration = data
        case .error(let message, _):
            // A failed reload must not hide a detail already on screen.
            if administration == nil { error = message }
        }
        loading = false
    }
}
