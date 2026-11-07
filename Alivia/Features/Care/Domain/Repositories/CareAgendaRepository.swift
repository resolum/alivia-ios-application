import Foundation

protocol CareAgendaRepository: AnyObject {
    func agenda(from: LocalDate, to: LocalDate) async -> NetworkResult<[CareActivity]>
    func reminders() async -> NetworkResult<[CareActivity]>
    func medicationAdministration(_ administrationId: String) async -> NetworkResult<MedicationAdministration>
    func recordOutcome(_ administrationId: String, result: AdministrationResult, occurredAt: Date,
                       reason: String?, notes: String?) async -> NetworkResult<MedicationAdministration>
}
