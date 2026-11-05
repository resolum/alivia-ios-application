import XCTest
@testable import Alivia

/// A maintenance order carries the family's incident; the technician evaluates it, confirms the visit, starts it
/// and records the resolution.
final class IncidentResolutionTests: XCTestCase {
    private let incident = IncidentSummaryDto(
        id: 84, code: "INC-2026-0084", status: "SCHEDULED", problemType: "BATTERY",
        description: "El sensor no detecta la ventana desde anoche.", occurredAt: "2026-11-04T13:00:00Z",
        device: InstalledDeviceDto(alias: "Sensor de ventana", macAddress: "00:1A:2B:3C:4D:5E", type: "SENSOR"))

    private func dto(status: String = "SCHEDULED", startedAt: String? = nil, summary: IncidentSummaryDto?) -> TechnicalOrderDto {
        TechnicalOrderDto(
            id: 9, code: "ORD-2026-0009", draftId: "draft", serviceType: "MAINTENANCE", incidentId: 84, status: status,
            date: "2026-11-05", startTime: "10:00:00", endTime: "12:00:00", technicianId: 5, technicianName: "Elena Vega",
            contactName: "María", contactPhone: "984123456", directions: "Av. Del Parque Norte 742", evaluationResult: nil,
            installationResult: nil, completionNotes: nil, startedAt: startedAt, completedAt: nil, installedDevices: nil,
            incident: summary)
    }

    private func withStatus(_ status: String) -> IncidentSummaryDto {
        var copy = incident
        copy.status = status
        return copy
    }

    func testTheOrderShowsTheIncidentTheFamilyReported() {
        let order = TechnicalOrderMapper.toDomain(dto(summary: incident))!
        let summary = order.incident!
        XCTAssertEqual("INC-2026-0084", summary.code)
        XCTAssertEqual(.scheduled, summary.status)
        XCTAssertEqual(.battery, summary.problem)
        XCTAssertEqual("Batería baja o agotada", summary.problem.label)
        XCTAssertEqual(ISO8601DateFormatter().date(from: "2026-11-04T13:00:00Z"), summary.occurredAt)
        XCTAssertEqual(InstalledDevice(alias: "Sensor de ventana", macAddress: "00:1A:2B:3C:4D:5E", type: .sensor), summary.device)
        XCTAssertFalse(order.awaitsResolution)

        let unknown = TechnicalOrderMapper.toDomain(dto(summary: IncidentSummaryDto(id: 85, status: "WEIRD", problemType: "ROBOT",
                                                                                     occurredAt: "no")))!.incident!
        XCTAssertEqual("INC-85", unknown.code)
        XCTAssertNil(unknown.status)
        XCTAssertEqual(.other, unknown.problem)
        XCTAssertEqual("", unknown.description)
        XCTAssertNil(unknown.occurredAt)
        XCTAssertNil(unknown.device)
        XCTAssertNil(TechnicalOrderMapper.toDomain(dto(summary: IncidentSummaryDto()))!.incident)
        XCTAssertNil(TechnicalOrderMapper.toDomain(dto(summary: nil))!.incident)
        XCTAssertEqual(["Registrada", "En evaluación", "Visita programada", "En atención", "Resuelta", "Cancelada"],
                       IncidentStatus.allCases.map(\.label))
    }

    func testEachStepOfTheIncidentHasItsAction() {
        XCTAssertEqual(.evaluate, TechnicalOrderMapper.toDomain(dto(summary: withStatus("OPEN")))!.incidentAction)
        XCTAssertEqual(.confirmVisit, TechnicalOrderMapper.toDomain(dto(summary: withStatus("IN_EVALUATION")))!.incidentAction)
        XCTAssertEqual(.start, TechnicalOrderMapper.toDomain(dto(summary: incident))!.incidentAction)
        XCTAssertEqual(.start, TechnicalOrderMapper.toDomain(dto(summary: nil))!.incidentAction)
        let started = TechnicalOrderMapper.toDomain(dto(startedAt: "2026-11-05T15:10:00Z", summary: withStatus("IN_PROGRESS")))!
        XCTAssertEqual(.resolve, started.incidentAction)
        XCTAssertTrue(started.awaitsResolution)
        XCTAssertNil(TechnicalOrderMapper.toDomain(dto(status: "COMPLETED", summary: withStatus("RESOLVED")))!.incidentAction)
        var installation = started
        installation.serviceType = .installation
        XCTAssertNil(installation.incidentAction)
        XCTAssertFalse(installation.awaitsResolution)
    }

    func testTheTechnicianEvaluatesTheReportAndConfirmsTheVisit() async {
        let repository = IncidentOrderRepository()
        let advance = AdvanceIncidentUseCase(repository: repository)

        repository.answer = dto(summary: withStatus("IN_EVALUATION"))
        let registered = TechnicalOrderMapper.toDomain(dto(summary: withStatus("OPEN")))!
        let evaluated = await advance(registered).value!
        XCTAssertEqual(.confirmVisit, evaluated.incidentAction)

        repository.answer = dto(summary: incident)
        let confirmed = await advance(evaluated).value!
        XCTAssertEqual(.start, confirmed.incidentAction)
        let nothingPending = await advance(confirmed)
        XCTAssertNotNil(nothingPending.errorMessage)
        XCTAssertEqual(["evaluate:9", "confirm:9"], repository.calls)
    }

    func testTheTechnicianResolvesAStartedVisit() async {
        let repository = IncidentOrderRepository()
        let resolve = ResolveIncidentUseCase(repository: repository)
        let scheduled = TechnicalOrderMapper.toDomain(dto(summary: incident))!
        let started = TechnicalOrderMapper.toDomain(dto(startedAt: "2026-11-05T15:10:00Z", summary: withStatus("IN_PROGRESS")))!

        let notStarted = await resolve(scheduled, diagnosis: "Pila agotada", workPerformed: "Cambio de pila")
        XCTAssertEqual("Inicia la atención antes de registrar la resolución.", notStarted.errorMessage)
        let noDiagnosis = await resolve(started, diagnosis: " ", workPerformed: "x")
        XCTAssertEqual("Describe el diagnóstico del dispositivo.", noDiagnosis.errorMessage)
        let noWork = await resolve(started, diagnosis: "Pila agotada", workPerformed: "")
        XCTAssertEqual("Describe el trabajo realizado.", noWork.errorMessage)
        let tooLong = await resolve(started, diagnosis: String(repeating: "a", count: 501), workPerformed: "Cambio de pila")
        XCTAssertEqual("Cada campo admite hasta 500 caracteres.", tooLong.errorMessage)
        XCTAssertTrue(repository.calls.isEmpty)

        repository.answer = dto(status: "COMPLETED", startedAt: "2026-11-05T15:10:00Z", summary: withStatus("RESOLVED"))
        let resolved = await resolve(started, diagnosis: "  Pila agotada ", workPerformed: " Cambio de pila y prueba ").value!
        XCTAssertEqual(.completed, resolved.progress)
        XCTAssertEqual(.resolved, resolved.incident?.status)
        XCTAssertEqual(["resolve:9:Pila agotada:Cambio de pila y prueba"], repository.calls)
    }
}

private final class IncidentOrderRepository: TechnicalOrderRepository {
    var answer = TechnicalOrderDto(id: 9, serviceType: "MAINTENANCE", date: "2026-11-05", startTime: "10:00", endTime: "12:00")
    var calls: [String] = []

    private func reply(_ call: String? = nil) -> NetworkResult<TechnicalOrder> {
        if let call { calls.append(call) }
        return TechnicalOrderMapper.toDomain(answer).map { .success($0) } ?? .error("La respuesta del servidor no es válida.")
    }

    func myOrders() async -> NetworkResult<[TechnicalOrder]> { .success([]) }
    func order(_ orderId: Int64) async -> NetworkResult<TechnicalOrder> { reply() }
    func start(_ orderId: Int64) async -> NetworkResult<TechnicalOrder> { reply("start:\(orderId)") }
    func recordEvaluation(_ orderId: Int64, result: EvaluationResult, notes: String?) async -> NetworkResult<TechnicalOrder> { reply() }
    func registerDevice(_ orderId: Int64, alias: String, macAddress: String, type: DeviceType) async -> NetworkResult<TechnicalOrder> { reply() }
    func removeDevice(_ orderId: Int64, macAddress: String) async -> NetworkResult<TechnicalOrder> { reply() }
    func recordInstallation(_ orderId: Int64, result: InstallationResult, notes: String?) async -> NetworkResult<TechnicalOrder> { reply() }
    func evaluateIncident(_ orderId: Int64) async -> NetworkResult<TechnicalOrder> { reply("evaluate:\(orderId)") }
    func confirmVisit(_ orderId: Int64) async -> NetworkResult<TechnicalOrder> { reply("confirm:\(orderId)") }
    func resolveIncident(_ orderId: Int64, diagnosis: String, workPerformed: String) async -> NetworkResult<TechnicalOrder> {
        reply("resolve:\(orderId):\(diagnosis):\(workPerformed)")
    }
}
