import XCTest
@testable import Alivia

final class TechnicalOrderRulesTests: XCTestCase {
    private func dto(id: Int64 = 2, type: String = "INSTALLATION", status: String = "SCHEDULED", startedAt: String? = nil) -> TechnicalOrderDto {
        TechnicalOrderDto(
            id: id, code: "ORD-2026-000\(id)", draftId: "draft", serviceType: type, incidentId: nil, status: status,
            date: "2026-11-03", startTime: "09:00", endTime: "11:00", technicianId: 7, technicianName: "Carla Mendoza",
            contactName: "María", contactPhone: "984123456", directions: " ", evaluationResult: nil,
            installationResult: nil, completionNotes: nil, startedAt: startedAt, completedAt: nil,
            installedDevices: [InstalledDeviceDto(alias: "Micrófono", macAddress: "00:1A:2B:3C:4D:5E", type: "MICROPHONE"),
                               InstalledDeviceDto(alias: "x", macAddress: "y", type: "TOASTER")]
        )
    }

    private func order(_ type: ServiceType = .installation, devices: [InstalledDevice] = [], id: Int64 = 2) -> TechnicalOrder {
        var order = TechnicalOrderMapper.toDomain(dto(id: id, type: type.rawValue))!
        order.installedDevices = devices
        return order
    }

    func testFormatsTheMacAddressWhileTyping() {
        XCTAssertEqual("00:1A:2B", MacAddress.format("001a2b"))
        XCTAssertEqual("00:1A:2B:3C:4D:5E", MacAddress.format("00-1a-2b-3c-4d-5e-ff"))
        XCTAssertTrue(MacAddress.isValid("00:1A:2B:3C:4D:5E"))
        XCTAssertFalse(MacAddress.isValid("00:1A:2B:3C:4D"))
    }

    func testMapsTheOrderAndItsProgress() {
        let scheduled = TechnicalOrderMapper.toDomain(dto())!
        XCTAssertEqual(.scheduled, scheduled.progress)
        XCTAssertNil(scheduled.directions)
        XCTAssertEqual("Hogar de María", scheduled.homeName)
        XCTAssertEqual([InstalledDevice(alias: "Micrófono", macAddress: "00:1A:2B:3C:4D:5E", type: .microphone)], scheduled.installedDevices)
        XCTAssertEqual(.inProgress, TechnicalOrderMapper.toDomain(dto(startedAt: "2026-11-03T15:07:30Z"))!.progress)
        XCTAssertEqual(.inProgress, TechnicalOrderMapper.toDomain(dto(startedAt: "2026-11-03T15:07:30.123456Z"))!.progress)
        XCTAssertEqual(.completed, TechnicalOrderMapper.toDomain(dto(status: "COMPLETED"))!.progress)
        XCTAssertNil(TechnicalOrderMapper.toDomain(dto(type: "UNKNOWN")))
        XCTAssertEqual(LocalDate(year: 2026, month: 11, day: 3), scheduled.date)
        XCTAssertEqual(LocalTime(hour: 9, minute: 0), scheduled.startTime)
    }

    func testAViableEvaluationWaitsForTheInstallationOfTheSameRequest() async {
        let repository = FakeOrderRepository()
        let evaluation = order(.evaluation)
        repository.mine = [evaluation, order(.installation, id: 5)]

        let missingNotes = await RecordEvaluationUseCase(repository: repository)(evaluation, result: .viableWithAdaptation, notes: " ")
        XCTAssertNotNil(missingNotes.errorMessage)

        let viable = await RecordEvaluationUseCase(repository: repository)(evaluation, result: .viable, notes: "")
        XCTAssertNotNil(viable.value)
        XCTAssertEqual(.viable, repository.lastResult)

        let rejected = await RecordEvaluationUseCase(repository: repository)(evaluation, result: .notViable, notes: "Sin red")
        XCTAssertNotNil(rejected.value)
        XCTAssertEqual(.notViable, repository.lastResult)

        // The installation of the same request appears once the family confirmed on the web.
        let find = FindInstallationOfRequestUseCase(repository: repository)
        let found = await find(evaluation.draftId)
        XCTAssertEqual(5, found.value??.id)
        let other = await find("other")
        XCTAssertNil(other.value!)
    }

    func testValidatesDevicesAndAllowsInstallationClosingWithoutDevices() async {
        let repository = FakeOrderRepository()
        let withDevice = order(devices: [InstalledDevice(alias: "Mic", macAddress: "00:1A:2B:3C:4D:5E", type: .microphone)])
        let register = RegisterDeviceUseCase(repository: repository)
        let blankAlias = await register(withDevice, alias: " ", macAddress: "001A2B3C4D5E", type: .hub)
        XCTAssertNotNil(blankAlias.errorMessage)
        let shortMac = await register(withDevice, alias: "Hub", macAddress: "001A2B", type: .hub)
        XCTAssertNotNil(shortMac.errorMessage)
        let duplicate = await register(withDevice, alias: "Hub", macAddress: "00-1a-2b-3c-4d-5e", type: .hub)
        XCTAssertNotNil(duplicate.errorMessage)
        let noType = await register(withDevice, alias: "Hub", macAddress: "AABBCCDDEEFF", type: nil)
        XCTAssertNotNil(noType.errorMessage)
        let ok = await register(withDevice, alias: "Hub", macAddress: "aabbccddeeff", type: .hub)
        XCTAssertNotNil(ok.value)
        XCTAssertEqual("AA:BB:CC:DD:EE:FF", repository.lastMac)

        let complete = CompleteInstallationUseCase(repository: repository)
        let approvedEmpty = await complete(order(), result: .approved, notes: "")
        XCTAssertNotNil(approvedEmpty.value)
        let rejected = await complete(order(), result: .rejected, notes: "")
        XCTAssertNotNil(rejected.value)
        let approved = await complete(withDevice, result: .approved, notes: "")
        XCTAssertNotNil(approved.value)
    }

    func testSummarizesAndGroupsTheOrdersOfTheTechnician() {
        let today = LocalDate(year: 2026, month: 11, day: 3)
        var first = order(.evaluation, id: 1)
        first.date = today
        var second = order(.installation, id: 2)
        second.date = today.plusDays(1)
        var third = order(.installation, id: 3)
        third.date = today.plusDays(4)
        var past = order(.evaluation, id: 4)
        past.date = today.plusDays(-1)
        past.progress = .completed
        let snapshot = OrdersSnapshot(orders: [first, second, third, past], filter: .all, today: today)

        XCTAssertEqual("1 hoy · 1 mañana · 1 próxima", snapshot.summary)
        XCTAssertEqual(1, snapshot.nextOrderId)
        XCTAssertEqual(["Hoy · 3 de noviembre", "Mañana · 4 de noviembre"], snapshot.groups.prefix(2).map(\.title))
        XCTAssertTrue(snapshot.groups.last!.title.hasPrefix("Anteriores · "))
        XCTAssertEqual(2, OrdersSnapshot(orders: [first, second, third, past], filter: .installations, today: today).filtered.count)
    }
}

private final class FakeOrderRepository: TechnicalOrderRepository {
    var mine: [TechnicalOrder] = []
    var lastResult: EvaluationResult?
    var lastMac: String?

    private func anyOrder() -> TechnicalOrder {
        TechnicalOrderMapper.toDomain(TechnicalOrderDto(id: 1, draftId: "draft", serviceType: "EVALUATION", status: "COMPLETED",
                                                        date: "2026-11-03", startTime: "09:00", endTime: "11:00",
                                                        technicianId: 7, technicianName: "Carla"))!
    }

    func myOrders() async -> NetworkResult<[TechnicalOrder]> { .success(mine) }
    func order(_ orderId: Int64) async -> NetworkResult<TechnicalOrder> { .success(anyOrder()) }
    func start(_ orderId: Int64) async -> NetworkResult<TechnicalOrder> { .success(anyOrder()) }

    func recordEvaluation(_ orderId: Int64, result: EvaluationResult, notes: String?) async -> NetworkResult<TechnicalOrder> {
        lastResult = result
        return .success(anyOrder())
    }

    func registerDevice(_ orderId: Int64, alias: String, macAddress: String, type: DeviceType) async -> NetworkResult<TechnicalOrder> {
        lastMac = macAddress
        return .success(anyOrder())
    }

    func removeDevice(_ orderId: Int64, macAddress: String) async -> NetworkResult<TechnicalOrder> { .success(anyOrder()) }
    func recordInstallation(_ orderId: Int64, result: InstallationResult, notes: String?) async -> NetworkResult<TechnicalOrder> {
        .success(anyOrder())
    }
}
