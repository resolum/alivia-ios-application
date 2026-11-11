import Observation
import SwiftUI

/// Technician's start screen: greeting, today's working hours, today's orders and the last ones closed.
@Observable
final class TechnicianHomeViewModel {
    private(set) var loading = true
    private(set) var error: String?
    private(set) var today = Formats.today()
    private(set) var firstName: String?
    private(set) var todayShifts: [TechnicianWorkingDay.Shift] = []
    private(set) var orders: [TechnicalOrder] = []

    private let getMyOrders: GetMyOrdersUseCase
    private let getProfile: GetMyProfileUseCase

    init(getMyOrders: GetMyOrdersUseCase, getProfile: GetMyProfileUseCase) {
        self.getMyOrders = getMyOrders
        self.getProfile = getProfile
    }

    /// Orders of today, in the order the technician attends them.
    var todayOrders: [TechnicalOrder] {
        orders.filter { $0.date == today && $0.progress != .canceled }.sorted { $0.startTime < $1.startTime }
    }

    /// The last orders the technician closed, the most recent first.
    var latestCompleted: [TechnicalOrder] {
        Array(orders.filter { $0.progress == .completed }
            .sorted { ($0.completedAt ?? .distantPast, $0.date) > ($1.completedAt ?? .distantPast, $1.date) }
            .prefix(3))
    }

    func load() async {
        today = Formats.today()
        loading = orders.isEmpty && error == nil
        error = nil
        async let ordersResult = getMyOrders()
        async let profileResult = getProfile()
        async let scheduleResult = TechnicianSchedule.load(from: today, to: today)
        // The greeting and the working hours are extras: only the orders decide whether the screen failed.
        if case .success(let profile) = await profileResult, !profile.firstName.isEmpty { firstName = profile.firstName }
        if case .success(let days) = await scheduleResult { todayShifts = days.first { $0.date == today }?.shifts ?? [] }
        switch await ordersResult {
        case .success(let data): orders = data
        case .error(let message, _): error = message
        }
        loading = false
    }
}

struct TechnicianHomeView: View {
    let onOpenOrder: (Int64) -> Void
    let onOpenSchedule: () -> Void
    let onOpenOrders: () -> Void
    let onOpenNotifications: () -> Void
    @State private var viewModel = TechnicianHomeViewModel(getMyOrders: OperationsModule.getMyOrders(),
                                                           getProfile: ProfilesModule.getMyProfile())
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Inicio", overline: "Técnico en campo · Alivia", onOpenProfile: onOpenNotifications)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    greeting
                    workday
                    if viewModel.loading {
                        LoadingView()
                    } else if let error = viewModel.error {
                        VStack(alignment: .leading, spacing: 4) {
                            ErrorBanner(message: error)
                            Button("Reintentar") { Task { await viewModel.load() } }.foregroundStyle(AliviaColor.navyButton)
                        }
                    } else {
                        let today = viewModel.todayOrders
                        if today.isEmpty {
                            noOrdersToday
                        } else {
                            SectionLabel(text: "Órdenes de hoy").padding(.top, 4)
                            ForEach(today) { order in
                                OrderCard(order: order, isNext: false) { onOpenOrder(order.id) }
                            }
                        }
                        latestHeader
                        let latest = viewModel.latestCompleted
                        if latest.isEmpty {
                            AliviaCard {
                                Text("Aún no tienes órdenes finalizadas.").font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.inkMuted)
                            }
                        }
                        ForEach(latest) { order in
                            CompletedOrderCard(order: order) { onOpenOrder(order.id) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
            .refreshable { await viewModel.load() }
        }
        .background(AliviaColor.background)
        .onAppear { Task { await viewModel.load() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.load() } }
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Formats.longDay(viewModel.today)).font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
            Text(viewModel.firstName.map { "Hola, \($0)" } ?? "Hola")
                .font(AliviaFont.headlineMedium).foregroundStyle(AliviaColor.navy)
        }
        .padding(.vertical, 4)
    }

    private var workday: some View {
        let shifts = viewModel.todayShifts
        let clock = LocalDate.calendar.dateComponents([.hour, .minute], from: Date())
        let now = LocalTime(hour: clock.hour ?? 0, minute: clock.minute ?? 0)
        let badge: (String, Color, Color) =
            if shifts.contains(where: { $0.start <= now && now < $0.end }) {
                ("Jornada activa", AliviaColor.tealSoft, AliviaColor.tealDark)
            } else if !shifts.isEmpty {
                ("Jornada de hoy", AliviaColor.navySoft, AliviaColor.navy)
            } else {
                ("Sin jornada hoy", AliviaColor.surfaceMuted, AliviaColor.inkMuted)
            }
        let count = viewModel.todayOrders.count
        return AliviaCard {
            HStack(spacing: 8) {
                Pill(text: badge.0, container: badge.1, content: badge.2, dot: badge.2).fixedSize()
                Text(shifts.isEmpty ? "—" : shifts.map { unbroken(Formats.window($0.start, $0.end)) }.joined(separator: " · "))
                    .font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.ink).lineLimit(2).minimumScaleFactor(0.85)
                Spacer(minLength: 0)
                Pill(text: count == 1 ? "1 orden hoy" : "\(count) órdenes hoy", container: AliviaColor.navySoft, content: AliviaColor.navy)
                    .fixedSize()
            }
        }
    }

    /// Keeps "8:00 a. m." together so a window only breaks around the dash.
    private func unbroken(_ window: String) -> String {
        window.split(separator: " – ").map { $0.replacingOccurrences(of: " ", with: "\u{00A0}") }.joined(separator: " – ")
    }

    private var noOrdersToday: some View {
        AliviaCard {
            VStack(spacing: 10) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 22)).foregroundStyle(AliviaColor.navy)
                    .frame(width: 56, height: 56).background(AliviaColor.navySoft, in: Circle())
                Text("No tienes órdenes asignadas para hoy")
                    .font(AliviaFont.titleLarge).foregroundStyle(AliviaColor.navy).multilineTextAlignment(.center)
                Text("Cualquier nueva asignación o cambio en tu jornada será notificado por la central de Alivia.")
                    .font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.inkMuted).multilineTextAlignment(.center)
                Button(action: onOpenSchedule) {
                    Label("Ver mi horario", systemImage: "calendar")
                        .font(AliviaFont.labelLarge).foregroundStyle(AliviaColor.navy)
                        .padding(.horizontal, 28).frame(height: 48)
                        .background(AliviaColor.navySoft, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }

    private var latestHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Últimas órdenes").font(AliviaFont.titleLarge).foregroundStyle(AliviaColor.navy)
                Text("Servicios finalizados recientemente").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
            }
            Spacer()
            Button(action: onOpenOrders) {
                HStack(spacing: 2) {
                    Text("Ver historial").font(AliviaFont.labelMedium)
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(AliviaColor.navy)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }
}

private struct CompletedOrderCard: View {
    let order: TechnicalOrder
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("#\(order.code) · \(order.completedAt.map { Formats.moment($0) } ?? Formats.day(order.date))")
                        .font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted).lineLimit(1)
                    Spacer()
                    ProgressPill(progress: order.progress)
                }
                Text(order.serviceType.longLabel).font(AliviaFont.titleMedium).foregroundStyle(AliviaColor.ink).lineLimit(1)
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse").font(.system(size: 13)).foregroundStyle(AliviaColor.inkMuted)
                    Text(order.homeName).font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.ink).lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(AliviaColor.inkMuted)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AliviaColor.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AliviaColor.outline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
