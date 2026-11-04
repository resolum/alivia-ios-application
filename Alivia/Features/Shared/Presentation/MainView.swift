import SwiftUI

enum MainTab: CaseIterable {
    case home, orders, schedule, profile

    var label: String {
        switch self {
        case .home: return "Inicio"
        case .orders: return "Órdenes"
        case .schedule: return "Horario"
        case .profile: return "Perfil"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .orders: return "list.clipboard"
        case .schedule: return "calendar"
        case .profile: return "person.crop.circle"
        }
    }
}

/// Main navigation of the app. For now only Órdenes works; Inicio, Horario and Perfil are placeholders, and
/// Perfil lets the account sign out.
struct MainView: View {
    let session: Session
    let onOpenOrder: (Int64) -> Void
    let onSignOut: () -> Void
    @State private var tab: MainTab

    init(session: Session, onOpenOrder: @escaping (Int64) -> Void, onSignOut: @escaping () -> Void) {
        self.session = session
        self.onOpenOrder = onOpenOrder
        self.onSignOut = onSignOut
        _tab = State(initialValue: session.role == .technician ? .orders : .home)
    }

    private var technician: Bool { session.role == .technician }

    var body: some View {
        TabView(selection: $tab) {
            ForEach(MainTab.allCases, id: \.self) { item in
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
            if technician {
                OrdersView(onOpenOrder: onOpenOrder, onOpenProfile: { tab = .profile })
            } else {
                ComingSoonView(icon: MainTab.orders.icon, title: "Órdenes", description: "Aquí verás las visitas técnicas de tu hogar.")
            }
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
        case .profile:
            VStack(spacing: 0) {
                ScreenHeader(title: "Perfil", subtitle: session.email, onOpenProfile: {})
                ComingSoonView(icon: MainTab.profile.icon, title: session.email,
                               description: technician ? "Cuenta de técnico" : "Cuenta de cuidador")
                Button(action: onSignOut) {
                    Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(AliviaFont.labelLarge)
                        .foregroundStyle(AliviaColor.navyButton)
                        .padding(.horizontal, 24)
                        .frame(height: 44)
                        .overlay(Capsule().stroke(AliviaColor.outline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(24)
            }
        }
    }
}
