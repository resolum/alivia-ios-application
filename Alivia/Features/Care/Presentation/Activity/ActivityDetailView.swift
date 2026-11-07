import SwiftUI

/// Detail of any activity or reminder, from the data the agenda already brings.
struct ActivityDetailView: View {
    let activity: CareActivity
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            DetailTopBar(title: "Detalle de actividad", subtitle: activity.title, onBack: onBack)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AliviaCard {
                        HStack(spacing: 8) {
                            Pill(text: activity.type.label, container: AliviaColor.navySoft, content: AliviaColor.navy)
                            Pill(text: activity.status.label, container: activity.status.container, content: activity.status.content)
                            Pill(text: "Prioridad \(activity.priority.label.lowercased())", container: activity.priority.container,
                                 content: activity.priority.content)
                        }
                        HStack(spacing: 12) {
                            Image(systemName: activity.type.icon).font(.system(size: 20)).foregroundStyle(AliviaColor.navy)
                            Text(activity.title).font(AliviaFont.titleLarge).foregroundStyle(AliviaColor.navy)
                        }
                    }
                    AliviaCard {
                        row("person", "Persona asistida", activity.assistedPerson)
                        row("calendar", "Fecha", Formats.day(activity.date))
                        row("clock", "Horario", schedule)
                        row("person.badge.shield.checkmark", "Responsable", activity.responsible)
                        row("repeat", "Frecuencia", activity.recurring ? "Se repite cada semana" : "Una sola vez")
                    }
                }
                .padding(16)
            }
        }
        .background(AliviaColor.background)
        .hidesNavigationBar()
    }

    /// "8:00 a. m. – 9:00 a. m.", with the day added when the activity ends on the next one.
    private var schedule: String {
        guard let end = activity.endTime else { return Formats.time(activity.startTime) }
        let window = Formats.window(activity.startTime, end)
        guard let endDate = activity.endDate, endDate != activity.date else { return window }
        return "\(window) (termina \(Formats.day(endDate).lowercased()))"
    }

    private func row(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(AliviaColor.inkMuted).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
                Text(value).font(AliviaFont.bodyLarge).foregroundStyle(AliviaColor.ink)
            }
        }
    }
}

extension CareActivityType {
    var label: String {
        switch self {
        case .medication: return "Medicamento"
        case .appointment: return "Cita"
        case .therapy: return "Terapia"
        case .meal: return "Comida"
        case .bath: return "Baño"
        case .exercise: return "Ejercicio"
        case .other: return "Otra"
        }
    }
}
