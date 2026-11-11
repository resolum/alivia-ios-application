import SwiftUI

struct AgendaView: View {
    let onOpenProfile: () -> Void
    let onOpenMedication: (String) -> Void
    let onOpenActivity: (CareActivity) -> Void
    var onNewActivity: () -> Void = {}
    @State private var viewModel = AgendaViewModel(getCareAgenda: CareModule.getCareAgenda(),
                                                   getReminders: CareModule.getReminders(),
                                                   scheduler: CareModule.reminderScheduler)
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let snapshot = viewModel.snapshot
        VStack(spacing: 0) {
            ScreenHeader(title: "Actividades", subtitle: snapshot.summary, onOpenProfile: onOpenProfile)
            HStack(spacing: 10) {
                modeSwitch
                if viewModel.canCreate {
                Button(action: onNewActivity) {
                    Label("Nueva", systemImage: "plus").font(AliviaFont.labelLarge).foregroundStyle(.white)
                        .padding(.horizontal, 16).frame(height: 44)
                        .background(AliviaColor.navy, in: Capsule())
                }
                .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if let error = viewModel.error {
                        VStack(alignment: .leading, spacing: 4) {
                            ErrorBanner(message: error)
                            Button("Reintentar") { Task { await viewModel.load() } }
                                .foregroundStyle(AliviaColor.navyButton)
                        }
                    }
                    if viewModel.mode == .calendar {
                        MonthCalendar(viewModel: viewModel)
                        HStack {
                            Text(Formats.longDay(viewModel.selectedDay)).font(AliviaFont.titleMedium).foregroundStyle(AliviaColor.navy)
                            Spacer()
                            let count = viewModel.selectedDayActivities.count
                            Pill(text: count == 1 ? "1 actividad" : "\(count) actividades", container: AliviaColor.navySoft,
                                 content: AliviaColor.navy)
                        }
                        if viewModel.monthLoading && viewModel.monthActivities.isEmpty {
                            LoadingView()
                        } else if viewModel.selectedDayActivities.isEmpty {
                            AliviaCard {
                                Text("No hay actividades este día.").font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.inkMuted)
                            }
                        }
                        ForEach(viewModel.selectedDayActivities) {
                            ActivityCard(activity: $0, onOpenMedication: onOpenMedication, onOpenActivity: onOpenActivity)
                        }
                    } else if viewModel.loading {
                        LoadingView()
                    } else {
                        if !viewModel.reminders.isEmpty {
                            GroupHeader(title: "Recordatorios pendientes", count: viewModel.reminders.count, noun: "recordatorio")
                            ForEach(viewModel.reminders) { ReminderCard(reminder: $0, onOpenMedication: onOpenMedication, onOpenActivity: onOpenActivity) }
                        }
                        let groups = snapshot.groups
                        if groups.isEmpty && viewModel.error == nil { EmptyAgenda() }
                        ForEach(groups) { group in
                            GroupHeader(title: group.kind.title, count: group.activities.count)
                            ForEach(group.activities) { ActivityCard(activity: $0, onOpenMedication: onOpenMedication, onOpenActivity: onOpenActivity) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .refreshable {
                await viewModel.load(refresh: true)
                if viewModel.mode == .calendar { await viewModel.loadMonth() }
            }
        }
        .background(AliviaColor.background)
        .onAppear {
            Task {
                await viewModel.loadRole()
                await viewModel.load()
                if viewModel.mode == .calendar { await viewModel.loadMonth() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.load() } }
        }
        .onChange(of: viewModel.mode) { _, mode in
            if mode == .calendar { Task { await viewModel.loadMonth() } }
        }
    }

    private var modeSwitch: some View {
        HStack(spacing: 0) {
            ForEach([(AgendaViewMode.list, "Lista", "list.bullet"), (.calendar, "Calendario", "calendar")], id: \.1) { mode, label, icon in
                let selected = viewModel.mode == mode
                Button { viewModel.mode = mode } label: {
                    Label(label, systemImage: icon).font(AliviaFont.labelLarge).foregroundStyle(AliviaColor.navy)
                        .frame(maxWidth: .infinity).frame(height: 36)
                        .background(selected ? AliviaColor.surface : .clear, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(AliviaColor.navySoft, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct MonthCalendar: View {
    @Bindable var viewModel: AgendaViewModel

    private static let weekdays = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]

    var body: some View {
        let month = viewModel.month
        let offset = (LocalDate.calendar.component(.weekday, from: month.date) + 5) % 7
        let total = ((offset + viewModel.daysInMonth + 6) / 7) * 7
        let today = Formats.today()
        AliviaCard {
            HStack {
                Text(Formats.monthYear(month)).font(AliviaFont.titleLarge).foregroundStyle(AliviaColor.navy)
                Spacer()
                Button { Task { await viewModel.moveMonth(-1) } } label: { Image(systemName: "chevron.left").frame(width: 36, height: 36) }
                    .accessibilityLabel("Mes anterior")
                Button { Task { await viewModel.moveMonth(1) } } label: { Image(systemName: "chevron.right").frame(width: 36, height: 36) }
                    .accessibilityLabel("Mes siguiente")
            }
            .foregroundStyle(AliviaColor.navy)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(Self.weekdays, id: \.self) { Text($0).font(AliviaFont.labelSmall).foregroundStyle(AliviaColor.inkMuted) }
                ForEach(0..<total, id: \.self) { index in
                    let dayNumber = index - offset + 1
                    if dayNumber >= 1 && dayNumber <= viewModel.daysInMonth {
                        let date = month.plusDays(dayNumber - 1)
                        let selected = date == viewModel.selectedDay
                        Button { viewModel.selectedDay = date } label: {
                            VStack(spacing: 2) {
                                Text("\(dayNumber)").font(AliviaFont.bodyMedium).foregroundStyle(selected ? .white : AliviaColor.ink)
                                Circle().fill(viewModel.daysWithActivities.contains(date)
                                              ? (selected ? Color.white : AliviaColor.tealDark) : .clear)
                                    .frame(width: 5, height: 5)
                            }
                            .frame(width: 40, height: 40)
                            .background(selected ? AliviaColor.navy : (date == today ? AliviaColor.navySoft : .clear), in: Circle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(height: 40)
                    }
                }
            }
        }
    }
}

/// Every activity opens its detail, where it can be marked as completed. The medication administration screen needs
/// `/api/v1/medication-administrations`, which the current backend does not expose.
private func open(_ activity: CareActivity, _ onOpenMedication: (String) -> Void, _ onOpenActivity: (CareActivity) -> Void) {
    onOpenActivity(activity)
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
        case .hygiene: return "hands.and.sparkles"
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
