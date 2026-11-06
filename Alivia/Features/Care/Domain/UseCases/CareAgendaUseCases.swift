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
