import SwiftUI

enum MainTab: Hashable {
    case home, orders, schedule, agenda, devices, history, alerts, profile

    /// Tabs of the bottom bar for each role of the mobile app.
    static func tabs(for role: UserRole) -> [MainTab] {
        role == .technician
            ? [.home, .orders, .schedule, .profile]
            : [.home, .agenda, .devices, .history, .profile]
    }

    var label: String {
        switch self {
        case .home: return "Inicio"
        case .orders: return "Órdenes"
        case .schedule: return "Horario"
        case .devices: return "Dispositivos"
        case .alerts: return "Alertas"
        case .agenda: return "Actividades"
        case .history: return "Historial"
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
        case .agenda: return "list.bullet.clipboard"
        case .history: return "clock.arrow.circlepath"
        case .profile: return "person.crop.circle"
        }
    }
}

/// Main navigation of the app, adapted to the authenticated account role.
struct MainView: View {
    let session: Session
    let onOpenOrder: (Int64) -> Void
    let onOpenMedication: (String) -> Void
    let onOpenActivity: (CareActivity) -> Void
    let onOpenNotifications: () -> Void
    let onSignOut: () -> Void
    @State private var tab: MainTab

    init(session: Session, onOpenOrder: @escaping (Int64) -> Void,
         onOpenMedication: @escaping (String) -> Void = { _ in },
         onOpenActivity: @escaping (CareActivity) -> Void = { _ in }, onOpenNotifications: @escaping () -> Void = {},
         onSignOut: @escaping () -> Void) {
        self.session = session
        self.onOpenOrder = onOpenOrder
        self.onOpenMedication = onOpenMedication
        self.onOpenActivity = onOpenActivity
        self.onOpenNotifications = onOpenNotifications
        self.onSignOut = onSignOut
        _tab = State(initialValue: .home)
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
            OrdersView(onOpenOrder: onOpenOrder, onOpenProfile: onOpenNotifications)
        case .home where technician:
            TechnicianHomeView(onOpenOrder: onOpenOrder, onOpenSchedule: { tab = .schedule },
                               onOpenOrders: { tab = .orders }, onOpenNotifications: onOpenNotifications)
        case .home:
            CaregiverHomeView(onOpenActivities: { tab = .agenda }, onOpenNotifications: onOpenNotifications)
        case .schedule:
            ScheduleView(onOpenProfile: onOpenNotifications)
        case .devices:
            DevicesView(onOpenNotifications: onOpenNotifications)
        case .alerts:
            VStack(spacing: 0) {
                ScreenHeader(title: MainTab.alerts.label, onOpenProfile: onOpenNotifications)
                ComingSoonView(icon: MainTab.alerts.icon, title: "Muy pronto", description: "Aquí recibirás las alertas del hogar, con su prioridad y confirmación.")
            }
        case .history:
            VStack(spacing: 0) {
                ScreenHeader(title: MainTab.history.label, onOpenProfile: onOpenNotifications)
                ComingSoonView(icon: MainTab.history.icon, title: "Muy pronto", description: "Aquí verás los eventos del hogar: comandos de voz, actividades y alertas.")
            }
        case .agenda:
            AgendaView(onOpenProfile: onOpenNotifications, onOpenMedication: onOpenMedication, onOpenActivity: onOpenActivity)
        case .profile:
            ProfileView(session: session, onSignOut: onSignOut)
        }
    }
}
