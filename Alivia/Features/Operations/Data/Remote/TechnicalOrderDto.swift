import Foundation

/// Technical order as `/api/v1/technical-orders` returns it.
struct TechnicalOrderDto: Decodable {
    var id: Int64?
    var code: String?
    var draftId: String?
    var serviceType: String?
    var incidentId: Int64?
    var status: String?
    var date: String?
    var startTime: String?
    var endTime: String?
    var technicianId: Int64?
    var technicianName: String?
    var contactName: String?
    var contactPhone: String?
    var directions: String?
    var evaluationResult: String?
    var installationResult: String?
    var completionNotes: String?
    var startedAt: String?
    var completedAt: String?
    var installedDevices: [InstalledDeviceDto]?
}

struct InstalledDeviceDto: Decodable {
    var alias: String?
    var macAddress: String?
    var type: String?
}

struct EvaluationResultRequestDto: Encodable { let result: String; let notes: String? }

struct InstallationResultRequestDto: Encodable { let result: String; let notes: String? }

struct RegisterDeviceRequestDto: Encodable { let alias: String; let macAddress: String; let type: String }

enum TechnicalOrderMapper {
    static func toDomain(_ dto: TechnicalOrderDto) -> TechnicalOrder? {
        guard let id = dto.id,
              let type = dto.serviceType.flatMap(ServiceType.init(rawValue:)),
              let date = LocalDate(iso: dto.date),
              let start = LocalTime(iso: dto.startTime),
              let end = LocalTime(iso: dto.endTime) else { return nil }
        let startedAt = InstantParser.parse(dto.startedAt)
        let progress: OrderProgress
        switch dto.status {
        case "COMPLETED": progress = .completed
        case "CANCELED": progress = .canceled
        default: progress = startedAt != nil ? .inProgress : .scheduled
        }
        return TechnicalOrder(
            id: id,
            code: dto.code ?? "ORD-\(id)",
            draftId: dto.draftId ?? "",
            serviceType: type,
            incidentId: dto.incidentId,
            progress: progress,
            date: date,
            startTime: start,
            endTime: end,
            technicianName: dto.technicianName ?? "",
            contactName: notBlank(dto.contactName),
            contactPhone: notBlank(dto.contactPhone),
            directions: notBlank(dto.directions),
            evaluationResult: dto.evaluationResult.flatMap(EvaluationResult.init(rawValue:)),
            installationResult: dto.installationResult.flatMap(InstallationResult.init(rawValue:)),
            completionNotes: dto.completionNotes,
            startedAt: startedAt,
            completedAt: InstantParser.parse(dto.completedAt),
            installedDevices: (dto.installedDevices ?? []).compactMap { device in
                guard let kind = device.type.flatMap(DeviceType.init(rawValue:)) else { return nil }
                return InstalledDevice(alias: device.alias ?? "", macAddress: device.macAddress ?? "", type: kind)
            }
        )
    }

    private static func notBlank(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }
}

/// Calls of the Operations context.
final class TechnicalOrderFacadeService {
    private let client: APIClient
    init(client: APIClient) { self.client = client }

    func mine() async throws -> [TechnicalOrderDto] { try await client.send("GET", "api/v1/technical-orders/mine") }
    func get(_ orderId: Int64) async throws -> TechnicalOrderDto { try await client.send("GET", "api/v1/technical-orders/\(orderId)") }
    func start(_ orderId: Int64) async throws -> TechnicalOrderDto { try await client.send("POST", "api/v1/technical-orders/\(orderId)/start") }

    func recordEvaluation(_ orderId: Int64, result: String, notes: String?) async throws -> TechnicalOrderDto {
        try await client.send("POST", "api/v1/technical-orders/\(orderId)/evaluation-result",
                              body: EvaluationResultRequestDto(result: result, notes: notes))
    }

    func registerDevice(_ orderId: Int64, alias: String, macAddress: String, type: String) async throws -> TechnicalOrderDto {
        try await client.send("POST", "api/v1/technical-orders/\(orderId)/devices",
                              body: RegisterDeviceRequestDto(alias: alias, macAddress: macAddress, type: type))
    }

    func removeDevice(_ orderId: Int64, macAddress: String) async throws -> TechnicalOrderDto {
        let mac = macAddress.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? macAddress
        return try await client.send("DELETE", "api/v1/technical-orders/\(orderId)/devices/\(mac)")
    }

    func recordInstallation(_ orderId: Int64, result: String, notes: String?) async throws -> TechnicalOrderDto {
        try await client.send("POST", "api/v1/technical-orders/\(orderId)/installation-result",
                              body: InstallationResultRequestDto(result: result, notes: notes))
    }
}
