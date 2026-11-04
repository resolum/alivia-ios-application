import Foundation
import Observation

enum OrdersViewMode { case list, calendar }

enum OrderFilter: CaseIterable {
    case all, evaluations, installations, incidents

    var label: String {
        switch self {
        case .all: return "Todas"
        case .evaluations: return "Revisiones"
        case .installations: return "Instalaciones"
        case .incidents: return "Incidencias"
        }
    }

    var type: ServiceType? {
        switch self {
        case .all: return nil
        case .evaluations: return .evaluation
        case .installations: return .installation
        case .incidents: return .maintenance
        }
    }
}

/// What the Órdenes tab shows, computed from the loaded orders.
struct OrdersSnapshot {
    var orders: [TechnicalOrder]
    var filter: OrderFilter
    var today: LocalDate

    var filtered: [TechnicalOrder] { orders.filter { filter.type == nil || $0.serviceType == filter.type } }

    /// The order the technician attends next: the first open one from today on.
    var nextOrderId: Int64? {
        orders.filter { $0.isOpen && !($0.date < today) }
            .min { ($0.date, $0.startTime) < ($1.date, $1.startTime) }?.id
    }

    var summary: String {
        let open = orders.filter(\.isOpen)
        let todayCount = open.filter { $0.date == today }.count
        let tomorrowCount = open.filter { $0.date == today.plusDays(1) }.count
        let later = open.filter { $0.date > today.plusDays(1) }.count
        return "\(todayCount) hoy · \(tomorrowCount) mañana · \(later) \(later == 1 ? "próxima" : "próximas")"
    }

    struct Group: Identifiable {
        let title: String
        let orders: [TechnicalOrder]
        var id: String { title }
    }

    /// Today, tomorrow and each later day in order; past days at the end, the latest first.
    var groups: [Group] {
        let byDate = Dictionary(grouping: filtered, by: \.date)
        let upcoming = byDate.keys.filter { !($0 < today) }.sorted()
        let past = byDate.keys.filter { $0 < today }.sorted(by: >)
        return (upcoming + past).map { date in
            let label = Formats.day(date, today: today)
            let afterComma = label.components(separatedBy: ", ").dropFirst().joined(separator: ", ")
            let title: String
            if date == today { title = "Hoy · \(afterComma)" }
            else if date == today.plusDays(1) { title = "Mañana · \(afterComma)" }
            else if date > today { title = "Próximas · \(label)" }
            else { title = "Anteriores · \(label)" }
            return Group(title: title, orders: (byDate[date] ?? []).sorted { $0.startTime < $1.startTime })
        }
    }

    func count(for filter: OrderFilter) -> Int { orders.filter { filter.type == nil || $0.serviceType == filter.type }.count }
}

@Observable
final class OrdersViewModel {
    private(set) var loading = true
    private(set) var refreshing = false
    private(set) var error: String?
    private(set) var orders: [TechnicalOrder] = []
    var view: OrdersViewMode = .list
    var filter: OrderFilter = .all
    private(set) var today = Formats.today()
    var selectedDay = Formats.today()

    private let getMyOrders: GetMyOrdersUseCase
    private var loadTask: Task<Void, Never>?

    init(getMyOrders: GetMyOrdersUseCase) {
        self.getMyOrders = getMyOrders
    }

    var snapshot: OrdersSnapshot { OrdersSnapshot(orders: orders, filter: filter, today: today) }

    /// Loads the orders again. The screen calls it every time it is shown (entering the tab, coming back from an
    /// order or to the app), so new assignments appear without pulling. The current list stays visible meanwhile,
    /// and a load already running is reused unless the technician pulls to refresh.
    func load(refresh: Bool = false) async {
        if let running = loadTask {
            if !refresh { return await running.value }
            running.cancel()
        }
        loading = orders.isEmpty
        refreshing = refresh
        error = nil
        today = Formats.today()
        let task = Task {
            let result = await getMyOrders()
            guard !Task.isCancelled else { return }
            switch result {
            case .success(let data): orders = data
            case .error(let message, _): error = message
            }
            loading = false
            refreshing = false
        }
        loadTask = task
        await task.value
        if loadTask == task { loadTask = nil }
    }
}
