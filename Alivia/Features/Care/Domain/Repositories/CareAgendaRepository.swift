import Foundation

protocol CareAgendaRepository: AnyObject {
    func agenda(from: LocalDate, to: LocalDate) async -> NetworkResult<[CareActivity]>
}
