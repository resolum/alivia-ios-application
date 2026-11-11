import SwiftUI

extension ServiceType {
    var label: String {
        switch self {
        case .evaluation: return "Revisión"
        case .installation: return "Instalación"
        case .maintenance: return "Incidencia"
        }
    }

    var longLabel: String {
        switch self {
        case .evaluation: return "Evaluación técnica"
        case .installation: return "Instalación de dispositivos"
        case .maintenance: return "Incidencia técnica"
        }
    }

    var color: Color {
        switch self {
        case .evaluation: return AliviaColor.evaluation
        case .installation: return AliviaColor.installation
        case .maintenance: return AliviaColor.incident
        }
    }

    var icon: String {
        switch self {
        case .evaluation: return "checkmark.circle"
        case .installation: return "wrench.and.screwdriver"
        case .maintenance: return "exclamationmark.triangle"
        }
    }
}

extension OrderProgress {
    var label: String {
        switch self {
        case .scheduled: return "Programada"
        case .inProgress: return "En proceso"
        case .completed: return "Completada"
        case .canceled: return "Cancelada"
        }
    }
}

extension DeviceType {
    var label: String {
        switch self {
        case .microphone: return "Micrófono"
        case .actuator: return "Actuador"
        case .sensor: return "Sensor"
        case .hub: return "Hub central"
        }
    }
}

/// SF Symbol of a device type, or a generic chip when none was chosen.
func deviceIcon(_ type: DeviceType?) -> String {
    switch type {
    case .microphone: return "mic"
    case .actuator: return "switch.2"
    case .sensor: return "sensor"
    case .hub: return "wifi.router"
    case nil: return "cpu"
    }
}

struct ProgressPill: View {
    let progress: OrderProgress

    var body: some View {
        switch progress {
        case .scheduled: Pill(text: progress.label, container: AliviaColor.navySoft, content: AliviaColor.navy)
        case .inProgress: Pill(text: progress.label, container: AliviaColor.warningSoft, content: AliviaColor.navy, dot: AliviaColor.warning)
        case .completed: Pill(text: progress.label, container: AliviaColor.tealSoft, content: AliviaColor.tealDark)
        case .canceled: Pill(text: progress.label, container: AliviaColor.surfaceMuted, content: AliviaColor.inkMuted)
        }
    }
}

/// The incident stage for maintenance orders (Registrada, En evaluación…), the order progress otherwise.
struct OrderStatusPill: View {
    let order: TechnicalOrder

    var body: some View {
        if order.serviceType == .maintenance, let status = order.incident?.status {
            switch status {
            case .open, .inEvaluation, .inProgress:
                Pill(text: status.label, container: AliviaColor.warningSoft, content: AliviaColor.navy, dot: AliviaColor.warning)
            case .scheduled: Pill(text: status.label, container: AliviaColor.navySoft, content: AliviaColor.navy)
            case .resolved: Pill(text: status.label, container: AliviaColor.tealSoft, content: AliviaColor.tealDark)
            case .canceled: Pill(text: status.label, container: AliviaColor.surfaceMuted, content: AliviaColor.inkMuted)
            }
        } else {
            ProgressPill(progress: order.progress)
        }
    }
}

struct TypePill: View {
    let type: ServiceType

    var body: some View {
        switch type {
        case .maintenance: Pill(text: type.label, container: AliviaColor.dangerSoft, content: AliviaColor.danger, dot: AliviaColor.danger)
        case .installation: Pill(text: type.label, container: AliviaColor.tealSoft, content: AliviaColor.tealDark, dot: AliviaColor.installation)
        case .evaluation: Pill(text: type.label, container: AliviaColor.navySoft, content: AliviaColor.navy, dot: AliviaColor.navy)
        }
    }
}
