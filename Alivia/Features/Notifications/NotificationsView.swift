import Observation
import SwiftUI

/// A message of the notification center.
struct AppNotification: Identifiable, Sendable {
    let id: Int64
    let type: String?
    let title: String
    let body: String?
    var read: Bool
    let createdAt: Date?

    /// Failures and disconnections show as alerts; the rest as information.
    var isAlert: Bool {
        ["ACTUATOR_FAILURE", "LOW_BATTERY", "EDGE_DISCONNECTED", "HELP_REQUEST_DELAYED", "PAYMENT_FAILED"].contains(type ?? "")
    }
}

nonisolated private struct NotificationDto: Decodable {
    var id: Int64?
    var type: String?
    var title: String?
    var body: String?
    var status: String?
    var createdAt: String?
}

nonisolated private struct MarkReadRequest: Encodable { let ids: [Int64] }

enum NotificationService {
    static func mine() async -> NetworkResult<[AppNotification]> {
        let result: NetworkResult<[NotificationDto]> = await BaseRepository.safeCall {
            try await SharedModule.apiClient.send("GET", "api/v1/notifications")
        }
        switch result {
        case .success(let list):
            return .success(list.compactMap { dto in
                guard let id = dto.id else { return nil }
                let title = dto.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let body = dto.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return AppNotification(id: id, type: dto.type, title: title.isEmpty ? "Notificación" : title,
                                       body: body.isEmpty ? nil : body, read: dto.status == "READ", createdAt: parse(dto.createdAt))
            }
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) })
        case .error(let message, let code): return .error(message, code: code)
        }
    }

    static func markRead(_ ids: [Int64]) async {
        guard !ids.isEmpty else { return }
        _ = await BaseRepository.safeCall {
            try await SharedModule.apiClient.sendWithoutResponse("POST", "api/v1/notifications/read", body: MarkReadRequest(ids: ids))
        }
    }

    /// Accepts "2026-11-10T13:15:00Z" and Lima times without a zone ("2026-11-10T08:15:00").
    private static func parse(_ value: String?) -> Date? {
        guard let value else { return nil }
        if let date = ISO8601DateFormatter().date(from: value) { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = LocalDate.zone
        for pattern in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss"] {
            formatter.dateFormat = pattern
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }
}

enum NotificationFilter: CaseIterable {
    case all, unread, today

    var label: String {
        switch self {
        case .all: return "Todas"
        case .unread: return "No leídas"
        case .today: return "Hoy"
        }
    }
}

@Observable
final class NotificationsViewModel {
    private(set) var loading = true
    private(set) var error: String?
    private(set) var notifications: [AppNotification] = []
    var filter: NotificationFilter = .all

    func matches(_ item: AppNotification, _ filter: NotificationFilter) -> Bool {
        switch filter {
        case .all: return true
        case .unread: return !item.read
        case .today: return item.createdAt.map { LocalDate($0) == Formats.today() } ?? false
        }
    }

    func count(_ filter: NotificationFilter) -> Int { notifications.filter { matches($0, filter) }.count }
    var visible: [AppNotification] { notifications.filter { matches($0, filter) } }

    func load() async {
        loading = notifications.isEmpty
        error = nil
        switch await NotificationService.mine() {
        case .success(let data): notifications = data
        case .error(let message, _): error = message
        }
        loading = false
    }

    /// Marks as read right away and tells the backend.
    func markAllRead() { mark(notifications.filter { !$0.read }.map(\.id)) }

    func open(_ item: AppNotification) { if !item.read { mark([item.id]) } }

    private func mark(_ ids: [Int64]) {
        guard !ids.isEmpty else { return }
        for index in notifications.indices where ids.contains(notifications[index].id) { notifications[index].read = true }
        Task { await NotificationService.markRead(ids) }
    }
}

/// Notification center opened from the bell of the headers.
struct NotificationsView: View {
    let onBack: () -> Void
    @State private var viewModel = NotificationsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left").font(.system(size: 18, weight: .medium)).foregroundStyle(AliviaColor.navy)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Volver")
                Text("Notificaciones").font(AliviaFont.titleLarge).foregroundStyle(AliviaColor.navy)
                Spacer()
                Button("Marcar todas") { viewModel.markAllRead() }
                    .font(AliviaFont.labelMedium).foregroundStyle(AliviaColor.navyButton)
                    .disabled(!viewModel.notifications.contains { !$0.read })
            }
            .padding(.horizontal, 8)
            HStack(spacing: 8) {
                ForEach(NotificationFilter.allCases, id: \.self) { filter in
                    let selected = viewModel.filter == filter
                    Button { viewModel.filter = filter } label: {
                        Text("\(filter.label) (\(viewModel.count(filter)))").font(AliviaFont.labelMedium)
                            .foregroundStyle(selected ? .white : AliviaColor.navy)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(selected ? AliviaColor.navy : AliviaColor.navySoft, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if let error = viewModel.error {
                        ErrorBanner(message: error)
                        Button("Reintentar") { Task { await viewModel.load() } }.foregroundStyle(AliviaColor.navyButton)
                    }
                    if viewModel.loading {
                        LoadingView()
                    } else if viewModel.visible.isEmpty && viewModel.error == nil {
                        emptyState
                    } else {
                        let today = Formats.today()
                        let todayItems = viewModel.visible.filter { $0.createdAt.map { LocalDate($0) == today } ?? false }
                        let earlier = viewModel.visible.filter { !($0.createdAt.map { LocalDate($0) == today } ?? false) }
                        if !todayItems.isEmpty { group("Hoy", todayItems) }
                        if !earlier.isEmpty { group("Anteriores", earlier) }
                    }
                }
                .padding(16)
            }
            .refreshable { await viewModel.load() }
        }
        .background(AliviaColor.background)
        .hidesNavigationBar()
        .task { await viewModel.load() }
    }

    private func group(_ title: String, _ items: [AppNotification]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)
            AliviaCard {
                ForEach(items) { item in
                    Button { viewModel.open(item) } label: { row(item) }.buttonStyle(.plain)
                }
            }
        }
    }

    private func row(_ item: AppNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.isAlert ? "exclamationmark.triangle" : "info.circle")
                .font(.system(size: 15)).foregroundStyle(item.isAlert ? AliviaColor.danger : AliviaColor.tealDark)
                .frame(width: 36, height: 36)
                .background(item.isAlert ? AliviaColor.dangerSoft : AliviaColor.tealSoft, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.navy)
                if let body = item.body { Text(body).font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.ink) }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                if let date = item.createdAt { Text(Formats.time(date)).font(AliviaFont.labelSmall).foregroundStyle(AliviaColor.inkMuted) }
                if !item.read { Circle().fill(item.isAlert ? AliviaColor.danger : AliviaColor.tealDark).frame(width: 8, height: 8) }
            }
        }
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell").font(.system(size: 28)).foregroundStyle(AliviaColor.navy)
                .frame(width: 72, height: 72).background(AliviaColor.navySoft, in: Circle())
            Text(viewModel.filter == .unread ? "Estás al día" : viewModel.filter == .today ? "No hay notificaciones de hoy" : "No tienes notificaciones")
                .font(AliviaFont.titleMedium).foregroundStyle(AliviaColor.navy)
            Text("Aquí verás los avisos del hogar, las asignaciones y los cambios de tu cuenta.")
                .font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.inkMuted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
    }
}
