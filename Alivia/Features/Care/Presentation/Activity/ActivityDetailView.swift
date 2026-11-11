import SwiftUI

/// Detail of any activity or reminder, from the data the agenda already brings.
struct ActivityDetailView: View {
    let activity: CareActivity
    let onBack: () -> Void
    @State private var completing = false
    @State private var error: String?

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
                        row("person.badge.shield.checkmark", "Asignada a", activity.responsible == "Sin responsable" ? "Sin responsable asignado" : activity.responsible)
                        row("repeat", "Frecuencia", activity.recurring ? "Se repite cada semana" : "Una sola vez")
                    }
                    if let error { ErrorBanner(message: error) }
                    let canComplete = activity.canComplete(now: Date())
                    PrimaryButton(text: canComplete ? "Marcar como completada" : "Disponible durante su horario",
                                  icon: "checkmark.circle", enabled: canComplete, busy: completing, container: AliviaColor.navy) {
                        Task { await complete() }
                    }
                    Text("Solo se puede marcar mientras la actividad está en curso.")
                        .font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted).frame(maxWidth: .infinity)
                }
                .padding(16)
            }
        }
        .background(AliviaColor.background)
        .hidesNavigationBar()
    }

    /// Records the occurrence; the backend accepts it only between its start and end.
    private func complete() async {
        guard let activityId = activity.activityId, let assignmentId = activity.assignmentId else {
            error = "Esta actividad no se puede marcar desde la app."
            return
        }
        completing = true
        error = nil
        switch await CareNetworkService.complete(activityId: activityId, assignmentId: assignmentId, date: activity.date, notes: nil) {
        case .success: onBack()
        case .error(_, 400): error = "Solo puedes marcarla mientras está en curso, entre su hora de inicio y de fin."
        case .error(let message, _): error = message
        }
        completing = false
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
        case .hygiene: return "Higiene"
        case .medication: return "Medicamento"
        case .appointment: return "Cita médica"
        case .therapy: return "Terapia"
        case .meal: return "Alimentación"
        case .bath: return "Baño"
        case .exercise: return "Ejercicio"
        case .other: return "Otra"
        }
    }
}
