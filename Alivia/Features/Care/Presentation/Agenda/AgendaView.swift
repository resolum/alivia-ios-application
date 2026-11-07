import SwiftUI

struct AgendaView: View {
    let onOpenProfile: () -> Void
    let onOpenMedication: (String) -> Void
    let onOpenActivity: (CareActivity) -> Void
    @State private var viewModel = AgendaViewModel(getCareAgenda: CareModule.getCareAgenda(),
                                                   getReminders: CareModule.getReminders(),
                                                   scheduler: CareModule.reminderScheduler)
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let snapshot = viewModel.snapshot
        VStack(spacing: 0) {
            ScreenHeader(title: "Agenda", subtitle: snapshot.summary, onOpenProfile: onOpenProfile)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if !viewModel.reminders.isEmpty {
                        GroupHeader(title: "Recordatorios pendientes", count: viewModel.reminders.count, noun: "recordatorio")
                        ForEach(viewModel.reminders) { ReminderCard(reminder: $0, onOpenMedication: onOpenMedication, onOpenActivity: onOpenActivity) }
                    }
                    SectionLabel(text: "Lista de actividades").padding(.top, 8)
                    if let error = viewModel.error {
                        VStack(alignment: .leading, spacing: 4) {
                            ErrorBanner(message: error)
                            Button("Reintentar") { Task { await viewModel.load() } }
                                .foregroundStyle(AliviaColor.navyButton)
                        }
                    }
                    if viewModel.loading {
                        LoadingView()
                    } else {
                        let groups = snapshot.groups
                        if groups.isEmpty && viewModel.error == nil { EmptyAgenda() }
                        ForEach(groups) { group in
                            GroupHeader(title: group.kind.title, count: group.activities.count)
                            ForEach(group.activities) { ActivityCard(activity: $0, onOpenMedication: onOpenMedication, onOpenActivity: onOpenActivity) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .refreshable { await viewModel.load(refresh: true) }
        }
        .background(AliviaColor.background)
        .onAppear { Task { await viewModel.load() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.load() } }
        }
    }
}

/// Medications open their administration; every other activity opens the activity detail.
private func open(_ activity: CareActivity, _ onOpenMedication: (String) -> Void, _ onOpenActivity: (CareActivity) -> Void) {
    if let administrationId = activity.administrationId { onOpenMedication(administrationId) } else { onOpenActivity(activity) }
}

private struct GroupHeader: View {
    let title: String
    let count: Int
    var noun = "actividad"

    var body: some View {
        HStack {
            Text(title).font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.ink)
            Spacer()
            Text(count == 1 ? "1 \(noun)" : "\(count) \(noun)s").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
        }
        .padding(.top, 4)
    }
}

private struct ActivityCard: View {
    let activity: CareActivity
    let onOpenMedication: (String) -> Void
    let onOpenActivity: (CareActivity) -> Void

    var body: some View {
        Button { open(activity, onOpenMedication, onOpenActivity) } label: { content }
            .buttonStyle(.plain)
            .accessibilityHint(activity.administrationId != nil ? "Abre el detalle del medicamento" : "Abre el detalle de la actividad")
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(AliviaColor.navySoft).frame(width: 40, height: 40)
                Image(systemName: activity.type.icon).font(.system(size: 17)).foregroundStyle(AliviaColor.navy)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(Formats.time(activity.startTime)).font(AliviaFont.labelMedium).foregroundStyle(AliviaColor.navy)
                    if activity.recurring {
                        Image(systemName: "repeat").font(.system(size: 11)).foregroundStyle(AliviaColor.inkMuted)
                            .accessibilityLabel("Recurrente")
                    }
                    Spacer()
                    Pill(text: activity.status.label, container: activity.status.container, content: activity.status.content)
                }
                Text(activity.title).font(AliviaFont.titleMedium).foregroundStyle(AliviaColor.navy)
                detail("person", activity.assistedPerson)
                detail("person.badge.shield.checkmark", "Responsable: \(activity.responsible)")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AliviaColor.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AliviaColor.outline, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private func detail(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(AliviaColor.inkMuted)
            Text(text).font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.ink).lineLimit(1)
        }
    }
}

private struct ReminderCard: View {
    let reminder: CareActivity
    let onOpenMedication: (String) -> Void
    let onOpenActivity: (CareActivity) -> Void

    var body: some View {
        Button { open(reminder, onOpenMedication, onOpenActivity) } label: { content }
            .buttonStyle(.plain)
            .accessibilityHint(reminder.administrationId != nil ? "Abre el detalle del medicamento" : "Abre el detalle de la actividad")
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(AliviaColor.tealSoft).frame(width: 40, height: 40)
                Image(systemName: reminder.type.icon).font(.system(size: 17)).foregroundStyle(AliviaColor.tealDark)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(Formats.time(reminder.startTime)).font(AliviaFont.labelMedium).foregroundStyle(AliviaColor.navy)
                    Spacer()
                    Pill(text: reminder.priority.label, container: reminder.priority.container, content: reminder.priority.content)
                }
                Text(reminder.title).font(AliviaFont.titleMedium).foregroundStyle(AliviaColor.navy)
                HStack(spacing: 6) {
                    Image(systemName: "person").font(.system(size: 13)).foregroundStyle(AliviaColor.inkMuted)
                    Text(reminder.assistedPerson).font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.ink).lineLimit(1)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AliviaColor.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AliviaColor.outline, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

private struct EmptyAgenda: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(AliviaColor.navySoft).frame(width: 72, height: 72)
                Image(systemName: "calendar.badge.clock").font(.system(size: 28)).foregroundStyle(AliviaColor.navy)
            }
            Text("No hay actividades en estas fechas").font(AliviaFont.titleMedium).foregroundStyle(AliviaColor.navy)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

extension CareActivityType {
    var icon: String {
        switch self {
        case .medication: return "pills"
        case .appointment: return "stethoscope"
        case .therapy: return "figure.mind.and.body"
        case .meal: return "fork.knife"
        case .bath: return "shower"
        case .exercise: return "figure.walk"
        case .other: return "checklist"
        }
    }
}

extension CarePriority {
    var label: String {
        switch self {
        case .high: return "Alta"
        case .medium: return "Media"
        case .low: return "Baja"
        case .routine: return "Rutina"
        }
    }

    var container: Color {
        switch self {
        case .high: return AliviaColor.dangerSoft
        case .medium: return AliviaColor.warningSoft
        case .low: return AliviaColor.tealSoft
        case .routine: return AliviaColor.surfaceMuted
        }
    }

    var content: Color {
        switch self {
        case .high: return AliviaColor.danger
        case .medium: return AliviaColor.warning
        case .low: return AliviaColor.tealDark
        case .routine: return AliviaColor.inkMuted
        }
    }
}

extension CareActivityStatus {
    var label: String {
        switch self {
        case .scheduled: return "Programada"
        case .inProgress: return "En curso"
        case .completed: return "Completada"
        case .cancelled: return "Cancelada"
        case .missed: return "Vencida"
        case .omitted: return "Omitida"
        }
    }

    var container: Color {
        switch self {
        case .scheduled: return AliviaColor.navySoft
        case .inProgress: return AliviaColor.warningSoft
        case .completed: return AliviaColor.tealSoft
        case .cancelled, .omitted: return AliviaColor.surfaceMuted
        case .missed: return AliviaColor.dangerSoft
        }
    }

    var content: Color {
        switch self {
        case .scheduled: return AliviaColor.navy
        case .inProgress: return AliviaColor.warning
        case .completed: return AliviaColor.tealDark
        case .cancelled, .omitted: return AliviaColor.inkMuted
        case .missed: return AliviaColor.danger
        }
    }
}
