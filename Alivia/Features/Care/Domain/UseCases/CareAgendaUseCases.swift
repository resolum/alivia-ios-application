import Foundation

/// Activities of the care agenda from a week back to two weeks ahead of today.
struct GetCareAgendaUseCase {
    static let daysBack = 7
    static let daysAhead = 14
    let repository: CareAgendaRepository

    func callAsFunction(today: LocalDate = Formats.today()) async -> NetworkResult<[CareActivity]> {
        await repository.agenda(from: today.plusDays(-Self.daysBack), to: today.plusDays(Self.daysAhead))
    }
}

/// Pending reminders of the caregiver, as the backend orders them (by start and priority).
struct GetRemindersUseCase {
    let repository: CareAgendaRepository
    func callAsFunction() async -> NetworkResult<[CareActivity]> { await repository.reminders() }
}

struct GetMedicationAdministrationUseCase {
    let repository: CareAgendaRepository
    func callAsFunction(_ administrationId: String) async -> NetworkResult<MedicationAdministration> {
        await repository.medicationAdministration(administrationId)
    }
}
