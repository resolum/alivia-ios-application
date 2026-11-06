import SwiftUI

struct AgendaView: View {
    let onOpenProfile: () -> Void
    @State private var viewModel = AgendaViewModel(getCareAgenda: CareModule.getCareAgenda())
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let snapshot = viewModel.snapshot
        VStack(spacing: 0) {
            ScreenHeader(title: "Agenda", subtitle: snapshot.summary, onOpenProfile: onOpenProfile)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "Lista de actividades")
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
                            ForEach(group.activities) { ActivityCard(activity: $0) }
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

private struct GroupHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title).font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.ink)
            Spacer()
            Text(count == 1 ? "1 actividad" : "\(count) actividades").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
        }
        .padding(.top, 4)
    }
}

private struct ActivityCard: View {
    let activity: CareActivity

    var body: some View {
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
        .accessibilityElement(children: .combine)
    }

    private func detail(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(AliviaColor.inkMuted)
            Text(text).font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.ink).lineLimit(1)
        }
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
