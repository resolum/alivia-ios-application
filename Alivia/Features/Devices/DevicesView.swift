import Observation
import SwiftUI

enum HomeDeviceType: String, CaseIterable, Comparable, Sendable {
    case hub = "HUB", microphone = "MICROPHONE", actuator = "ACTUATOR", sensor = "SENSOR", other = "OTHER"

    var label: String {
        switch self {
        case .hub: return "Hub central"
        case .microphone: return "Cubo de voz"
        case .actuator: return "Actuador"
        case .sensor: return "Sensor"
        case .other: return "Dispositivo"
        }
    }

    var groupLabel: String {
        switch self {
        case .hub: return "Hub central"
        case .microphone: return "Cubos de voz"
        case .actuator: return "Luces y actuadores"
        case .sensor: return "Sensores"
        case .other: return "Otros"
        }
    }

    var icon: String {
        switch self {
        case .hub: return "point.3.connected.trianglepath.dotted"
        case .microphone: return "mic"
        case .actuator: return "lightbulb"
        case .sensor: return "sensor"
        case .other: return "cpu"
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

/// A device the technician installed in the caregiver's home.
struct HomeDevice: Identifiable, Hashable, Sendable {
    let id: Int64
    let alias: String
    let macAddress: String
    let type: HomeDeviceType
}

/// The serviced home and its installed devices.
struct HomeDevices: Sendable {
    let address: String?
    let devices: [HomeDevice]
}

nonisolated private struct HomeDevicesDto: Decodable {
    struct DeviceDto: Decodable {
        var id: Int64?
        var alias: String?
        var macAddress: String?
        var type: String?
    }
    var directions: String?
    var devices: [DeviceDto]?
}

enum HomeDeviceService {
    /// Installed devices of the account's home, from `/api/v1/support-incidents/devices`; nil while the home has no
    /// active service (404).
    static func mine() async -> NetworkResult<HomeDevices?> {
        let result: NetworkResult<HomeDevicesDto> = await BaseRepository.safeCall {
            try await SharedModule.apiClient.send("GET", "api/v1/support-incidents/devices")
        }
        switch result {
        case .success(let dto):
            let devices = (dto.devices ?? []).enumerated().compactMap { index, device -> HomeDevice? in
                let mac = device.macAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !mac.isEmpty else { return nil }
                let alias = device.alias?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return HomeDevice(id: device.id ?? Int64(index + 1), alias: alias.isEmpty ? "Dispositivo" : alias, macAddress: mac,
                                  type: device.type.flatMap(HomeDeviceType.init(rawValue:)) ?? .other)
            }
            let address = dto.directions?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return .success(HomeDevices(address: address.isEmpty ? nil : address, devices: devices))
        case .error(_, 404): return .success(nil)
        case .error(let message, let code): return .error(message, code: code)
        }
    }
}

@Observable
final class DevicesViewModel {
    private(set) var loading = true
    private(set) var loaded = false
    private(set) var error: String?
    private(set) var home: HomeDevices?
    var selected: HomeDevice?

    var devices: [HomeDevice] { home?.devices ?? [] }

    var groups: [(type: HomeDeviceType, devices: [HomeDevice])] {
        Dictionary(grouping: devices, by: \.type).sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    func load() async {
        loading = !loaded
        error = nil
        switch await HomeDeviceService.mine() {
        case .success(let data):
            home = data
            loaded = true
        case .error(let message, _):
            error = message
        }
        loading = false
    }
}

/// Devices installed in the caregiver's home, grouped by kind; each one opens its detail.
struct DevicesView: View {
    let onOpenNotifications: () -> Void
    @State private var viewModel = DevicesViewModel()

    var body: some View {
        let devices = viewModel.devices
        VStack(spacing: 0) {
            ScreenHeader(title: "Dispositivos",
                         subtitle: viewModel.loaded ? (devices.count == 1 ? "1 equipo instalado" : "\(devices.count) equipos instalados") : nil,
                         onOpenProfile: onOpenNotifications)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if let error = viewModel.error {
                        VStack(alignment: .leading, spacing: 4) {
                            ErrorBanner(message: error)
                            Button("Reintentar") { Task { await viewModel.load() } }.foregroundStyle(AliviaColor.navyButton)
                        }
                    }
                    if viewModel.loading {
                        LoadingView()
                    } else if viewModel.loaded && devices.isEmpty {
                        emptyState
                    } else if !devices.isEmpty {
                        summary
                        ForEach(viewModel.groups, id: \.type) { group in
                            SectionLabel(text: "\(group.type.groupLabel) · \(group.devices.count)").padding(.top, 4)
                            ForEach(group.devices) { device in
                                DeviceCard(device: device) { viewModel.selected = device }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .refreshable { await viewModel.load() }
        }
        .background(AliviaColor.background)
        .onAppear { Task { await viewModel.load() } }
        .sheet(item: $viewModel.selected) { device in
            DeviceDetailSheet(device: device, address: viewModel.home?.address)
        }
    }

    private var summary: some View {
        let devices = viewModel.devices
        return AliviaCard {
            HStack(spacing: 8) {
                Pill(text: "Monitoreo activo", container: AliviaColor.tealSoft, content: AliviaColor.tealDark, dot: AliviaColor.tealDark)
                    .fixedSize()
                if let address = viewModel.home?.address {
                    Label(address, systemImage: "mappin.and.ellipse").font(AliviaFont.bodySmall)
                        .foregroundStyle(AliviaColor.inkMuted).lineLimit(1)
                }
            }
            HStack(spacing: 8) {
                tile(devices.count, "Instalados", AliviaColor.navySoft)
                tile(devices.filter { $0.type == .microphone }.count, "Cubos de voz", AliviaColor.surfaceMuted)
                tile(devices.filter { $0.type == .sensor }.count, "Sensores", AliviaColor.surfaceMuted)
            }
        }
    }

    private func tile(_ count: Int, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(count)").font(AliviaFont.titleLarge).foregroundStyle(AliviaColor.navy)
            Text(label).font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color, in: RoundedRectangle(cornerRadius: 12))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sensor").font(.system(size: 28)).foregroundStyle(AliviaColor.navy)
                .frame(width: 72, height: 72).background(AliviaColor.navySoft, in: Circle())
            Text("Tu hogar todavía no tiene dispositivos instalados").font(AliviaFont.titleMedium)
                .foregroundStyle(AliviaColor.navy).multilineTextAlignment(.center)
            Text("Aparecerán aquí cuando el técnico termine la instalación.").font(AliviaFont.bodyMedium)
                .foregroundStyle(AliviaColor.inkMuted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

private struct DeviceCard: View {
    let device: HomeDevice
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: device.type.icon).font(.system(size: 18)).foregroundStyle(AliviaColor.navy)
                    .frame(width: 44, height: 44).background(AliviaColor.navySoft, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.alias).font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.navy).lineLimit(2)
                    HStack(spacing: 8) {
                        Pill(text: "Instalado", container: AliviaColor.tealSoft, content: AliviaColor.tealDark, dot: AliviaColor.tealDark)
                        Text(device.type.label).font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(AliviaColor.inkMuted)
            }
            .padding(14)
            .background(AliviaColor.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AliviaColor.outline, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

private struct DeviceDetailSheet: View {
    let device: HomeDevice
    let address: String?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: device.type.icon).font(.system(size: 28)).foregroundStyle(AliviaColor.navy)
                .frame(width: 64, height: 64).background(AliviaColor.navySoft, in: RoundedRectangle(cornerRadius: 18))
            Text(device.alias).font(AliviaFont.titleLarge).foregroundStyle(AliviaColor.navy).multilineTextAlignment(.center)
            Text(device.type.label).font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.inkMuted)
            Pill(text: "Instalado", container: AliviaColor.tealSoft, content: AliviaColor.tealDark, dot: AliviaColor.tealDark)
            AliviaCard {
                SectionLabel(text: "Información esencial")
                row("Tipo", device.type.label)
                Divider()
                row("Dirección MAC", device.macAddress)
                if let address {
                    Divider()
                    row("Hogar", address)
                }
            }
            .padding(.top, 8)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .background(AliviaColor.surface)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.inkMuted)
            Spacer()
            Text(value).font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.ink).multilineTextAlignment(.trailing)
        }
    }
}
