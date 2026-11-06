import SwiftUI

enum MainTab: Hashable {
    case home, orders, schedule, devices, alerts, agenda, profile

    /// Tabs of the bottom bar for each role of the mobile app.
    static func tabs(for role: UserRole) -> [MainTab] {
        role == .technician
            ? [.home, .orders, .schedule, .profile]
            : [.home, .devices, .alerts, .agenda, .profile]
    }

    var label: String {
        switch self {
        case .home: return "Inicio"
        case .orders: return "Órdenes"
        case .schedule: return "Horario"
        case .devices: return "Dispositivos"
        case .alerts: return "Alertas"
        case .agenda: return "Agenda"
        case .profile: return "Perfil"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .orders: return "list.clipboard"
        case .schedule: return "calendar"
        case .devices: return "sensor"
        case .alerts: return "bell"
        case .agenda: return "calendar.badge.clock"
        case .profile: return "person.crop.circle"
        }
    }
}

/// Main navigation of the app. For now only Órdenes works; Inicio, Horario and Perfil are placeholders, and
/// Perfil lets the account sign out.
struct MainView: View {
    let session: Session
    let onOpenOrder: (Int64) -> Void
    let onOpenMedication: (String) -> Void
    let onSignOut: () -> Void
    @State private var tab: MainTab

    init(session: Session, onOpenOrder: @escaping (Int64) -> Void,
         onOpenMedication: @escaping (String) -> Void = { _ in }, onSignOut: @escaping () -> Void) {
        self.session = session
        self.onOpenOrder = onOpenOrder
        self.onOpenMedication = onOpenMedication
        self.onSignOut = onSignOut
        _tab = State(initialValue: session.role == .technician ? .orders : .home)
    }

    private var technician: Bool { session.role == .technician }

    var body: some View {
        TabView(selection: $tab) {
            ForEach(MainTab.tabs(for: session.role), id: \.self) { item in
                Tab(item.label, systemImage: item.icon, value: item) {
                    content(for: item).background(AliviaColor.background)
                }
            }
        }
        .tint(AliviaColor.navy)
    }

    @ViewBuilder
    private func content(for item: MainTab) -> some View {
        switch item {
        case .orders:
            OrdersView(onOpenOrder: onOpenOrder, onOpenProfile: { tab = .profile })
        case .home:
            VStack(spacing: 0) {
                ScreenHeader(title: "Inicio", overline: technician ? "Técnico en campo · Alivia" : "Alivia", onOpenProfile: { tab = .profile })
                ComingSoonView(icon: MainTab.home.icon, title: "Muy pronto", description: "Esta sección estará disponible en una próxima versión.")
            }
        case .schedule:
            VStack(spacing: 0) {
                ScreenHeader(title: "Horario", onOpenProfile: { tab = .profile })
                ComingSoonView(icon: MainTab.schedule.icon, title: "Muy pronto", description: "Esta sección estará disponible en una próxima versión.")
            }
        case .devices:
            VStack(spacing: 0) {
                ScreenHeader(title: MainTab.devices.label, onOpenProfile: { tab = .profile })
                ComingSoonView(icon: MainTab.devices.icon, title: "Muy pronto", description: "Aquí verás el estado, la conexión y la batería de los dispositivos de tu hogar.")
            }
        case .alerts:
            VStack(spacing: 0) {
                ScreenHeader(title: MainTab.alerts.label, onOpenProfile: { tab = .profile })
                ComingSoonView(icon: MainTab.alerts.icon, title: "Muy pronto", description: "Aquí recibirás las alertas del hogar, con su prioridad y confirmación.")
            }
        case .agenda:
            AgendaView(onOpenProfile: { tab = .profile }, onOpenMedication: onOpenMedication)
        case .profile:
            ProfileView(session: session, onSignOut: onSignOut)
        }
    }
}
