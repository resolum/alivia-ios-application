import SwiftUI

struct MedicationDetailView: View {
    let onBack: () -> Void
    @State private var viewModel: MedicationDetailViewModel

    init(administrationId: String, onBack: @escaping () -> Void) {
        self.onBack = onBack
        _viewModel = State(initialValue: MedicationDetailViewModel(
            administrationId: administrationId, getAdministration: CareModule.getMedicationAdministration()))
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailTopBar(title: "Detalle de actividad", subtitle: viewModel.administration?.medication, onBack: onBack)
            ZStack {
                if viewModel.loading {
                    LoadingView().frame(maxHeight: .infinity, alignment: .top)
                } else if let administration = viewModel.administration {
                    MedicationDetailContent(administration: administration)
                } else {
                    VStack(alignment: .leading) {
                        ErrorBanner(message: viewModel.error ?? "No encontramos el medicamento.")
                        Button("Reintentar") { Task { await viewModel.load() } }.foregroundStyle(AliviaColor.navyButton)
                        Spacer()
                    }
                    .padding(16)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .background(AliviaColor.background)
        .hidesNavigationBar()
        .task { await viewModel.load() }
    }
}

private struct MedicationDetailContent: View {
    let administration: MedicationAdministration

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AliviaCard {
                    HStack(spacing: 8) {
                        Pill(text: "Medicamento", container: AliviaColor.navySoft, content: AliviaColor.navy)
                        Pill(text: administration.status.label, container: administration.status.container,
                             content: administration.status.content)
                    }
                    Text(administration.medication).font(AliviaFont.titleLarge).foregroundStyle(AliviaColor.navy)
                }
                AliviaCard {
                    row("person", "Persona asistida", administration.assistedPerson)
                    row("calendar", "Fecha", Formats.day(administration.date))
                    row("clock", "Horario", schedule)
                    row("person.badge.shield.checkmark", "Responsable", administration.responsible)
                }
                if let outcome = administration.outcome {
                    SectionLabel(text: "Resultado")
                    AliviaCard {
                        row(outcome.result.icon, "Resultado", outcome.result.label)
                        if let moment = moment(outcome) { row("clock.badge.checkmark", "Hora real", moment) }
                        row("hourglass", "Registro", outcome.late ? "Tardío" : "A tiempo")
                        if let reason = outcome.reason { row("text.bubble", "Motivo", reason) }
                        if let notes = outcome.notes { row("note.text", "Notas", notes) }
                    }
                }
            }
            .padding(16)
        }
    }

    private var schedule: String {
        guard let end = administration.endTime else { return Formats.time(administration.startTime) }
        return Formats.window(administration.startTime, end)
    }

    private func moment(_ outcome: AdministrationOutcome) -> String? {
        guard let time = outcome.occurredTime else { return nil }
        guard let date = outcome.occurredDate, date != administration.date else { return Formats.time(time) }
        return "\(Formats.day(date)) · \(Formats.time(time))"
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

extension AdministrationStatus {
    var label: String {
        switch self {
        case .pending: return "Pendiente"
        case .administered: return "Administrada"
        case .omitted: return "Omitida"
        case .missed: return "Vencida"
        case .cancelled: return "Cancelada"
        }
    }

    var container: Color {
        switch self {
        case .pending: return AliviaColor.navySoft
        case .administered: return AliviaColor.tealSoft
        case .omitted, .cancelled: return AliviaColor.surfaceMuted
        case .missed: return AliviaColor.dangerSoft
        }
    }

    var content: Color {
        switch self {
        case .pending: return AliviaColor.navy
        case .administered: return AliviaColor.tealDark
        case .omitted, .cancelled: return AliviaColor.inkMuted
        case .missed: return AliviaColor.danger
        }
    }
}

extension AdministrationResult {
    var label: String { self == .administered ? "Administrada" : "Omitida" }
    var icon: String { self == .administered ? "checkmark.circle" : "xmark.circle" }
}
