import Foundation
import Observation

/// The four steps of an installation at the home.
enum InstallationStep: Int, CaseIterable {
    case home = 1, devices, tests, closing

    var number: Int { rawValue }

    var title: String {
        switch self {
        case .home: return "Hogar"
        case .devices: return "Dispositivos"
        case .tests: return "Pruebas"
        case .closing: return "Cierre"
        }
    }

    var screenTitle: String {
        switch self {
        case .home: return "Verificar hogar"
        case .devices: return "Registrar dispositivos"
        case .tests: return "Probar dispositivos"
        case .closing: return "Cerrar instalación"
        }
    }
}

struct DeviceForm: Equatable {
    var alias = ""
    var macAddress = ""
    var type: DeviceType?

    var macComplete: Bool { macAddress.count == 17 }
    var macValid: Bool { MacAddress.isValid(macAddress) }
}

@Observable
final class InstallationViewModel {
    private(set) var order: TechnicalOrder?
    private(set) var loadError: String?
    private(set) var step: InstallationStep = .home
    private(set) var form = DeviceForm()
    private(set) var tested: Set<String> = []
    private(set) var result: InstallationResult?
    private(set) var notes = ""
    private(set) var busy = false
    private(set) var error: String?

    private let orderId: Int64
    private let getOrder: GetOrderUseCase
    private let registerDevice: RegisterDeviceUseCase
    private let removeDevice: RemoveDeviceUseCase
    private let completeInstallation: CompleteInstallationUseCase

    init(orderId: Int64, getOrder: GetOrderUseCase, registerDevice: RegisterDeviceUseCase,
         removeDevice: RemoveDeviceUseCase, completeInstallation: CompleteInstallationUseCase) {
        self.orderId = orderId
        self.getOrder = getOrder
        self.registerDevice = registerDevice
        self.removeDevice = removeDevice
        self.completeInstallation = completeInstallation
    }

    var duplicateMac: Bool { order?.installedDevices.contains { $0.macAddress == form.macAddress } == true }
    var allTested: Bool { order?.installedDevices.allSatisfy { tested.contains($0.macAddress) } == true }
    var canRegister: Bool {
        !form.alias.trimmingCharacters(in: .whitespaces).isEmpty && form.macValid && !duplicateMac && form.type != nil
    }

    func load() async {
        guard order == nil else { return }
        switch await getOrder(orderId) {
        case .success(let data):
            order = data
            step = data.installedDevices.isEmpty ? .home : .devices
        case .error(let message, _):
            loadError = message
        }
    }

    func goTo(_ next: InstallationStep) {
        step = next
        error = nil
    }

    /// Steps back; returns false on the first step so the screen can leave.
    func back() -> Bool {
        guard let previous = InstallationStep(rawValue: step.rawValue - 1) else { return false }
        goTo(previous)
        return true
    }

    func updateAlias(_ alias: String) { form.alias = String(alias.prefix(60)); error = nil }
    func updateMac(_ mac: String) { form.macAddress = MacAddress.format(mac); error = nil }
    func clearMac() { form.macAddress = "" }
    func updateType(_ type: DeviceType) { form.type = type; error = nil }
    func toggleTested(_ mac: String) { if tested.contains(mac) { tested.remove(mac) } else { tested.insert(mac) } }
    func selectResult(_ value: InstallationResult) { result = value; error = nil }
    func updateNotes(_ value: String) { notes = String(value.prefix(300)); error = nil }

    func register() {
        guard let order else { return }
        let current = form
        busy = true
        error = nil
        Task {
            switch await registerDevice(order, alias: current.alias, macAddress: current.macAddress, type: current.type) {
            case .success(let data):
                self.order = data
                form = DeviceForm()
            case .error(let message, _):
                error = message
            }
            busy = false
        }
    }

    func remove(_ macAddress: String) {
        busy = true
        error = nil
        Task {
            switch await removeDevice(orderId, macAddress: macAddress) {
            case .success(let data):
                order = data
                tested.remove(macAddress)
            case .error(let message, _):
                error = message
            }
            busy = false
        }
    }

    func finish(onCompleted: @escaping (Int64) -> Void) {
        guard let order else { return }
        guard let result else {
            error = "Elige el resultado de la instalación."
            return
        }
        busy = true
        error = nil
        Task {
            switch await completeInstallation(order, result: result, notes: notes) {
            case .success(let closed):
                busy = false
                self.order = closed
                onCompleted(closed.id)
            case .error(let message, _):
                busy = false
                error = message
            }
        }
    }
}
