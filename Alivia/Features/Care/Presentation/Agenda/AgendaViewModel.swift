import Foundation
import Observation

enum AgendaGroupKind: Int, CaseIterable {
    case today, tomorrow, upcoming, past

    var title: String {
        switch self {
        case .today: return "Hoy"
        case .tomorrow: return "Mañana"
        case .upcoming: return "Próximas"
        case .past: return "Anteriores"
        }
    }
}

/// What the Agenda tab shows, computed from the loaded activities.
struct AgendaSnapshot {
    var activities: [CareActivity]
    var today: LocalDate

    struct Group: Identifiable {
        let kind: AgendaGroupKind
        let activities: [CareActivity]
        var id: Int { kind.rawValue }
    }

    private func kind(of date: LocalDate) -> AgendaGroupKind {
        if date == today { return .today }
        if date == today.plusDays(1) { return .tomorrow }
        return date > today ? .upcoming : .past
    }

    /// Hoy, Mañana, Próximas and Anteriores, skipping the empty ones. Each group runs by date and time;
    /// Anteriores goes from the most recent to the oldest.
    var groups: [Group] {
        let byKind = Dictionary(grouping: activities, by: { kind(of: $0.date) })
        return AgendaGroupKind.allCases.compactMap { kind in
            guard let items = byKind[kind], !items.isEmpty else { return nil }
            let sorted = items.sorted { ($0.date, $0.startTime) < ($1.date, $1.startTime) }
            return Group(kind: kind, activities: kind == .past ? sorted.reversed() : sorted)
        }
    }

    var summary: String {
        let todayCount = activities.filter { $0.date == today }.count
        return todayCount == 1 ? "1 actividad hoy" : "\(todayCount) actividades hoy"
    }
}

@Observable
final class AgendaViewModel {
    private(set) var loading = true
    private(set) var refreshing = false
    private(set) var error: String?
    private(set) var activities: [CareActivity] = []
    private(set) var today = Formats.today()

    private let getCareAgenda: GetCareAgendaUseCase
    private var loadTask: Task<Void, Never>?

    init(getCareAgenda: GetCareAgendaUseCase) {
        self.getCareAgenda = getCareAgenda
    }

    var snapshot: AgendaSnapshot { AgendaSnapshot(activities: activities, today: today) }

    /// Loads the agenda again. The current list stays visible meanwhile, and a load already running is reused
    /// unless the caregiver pulls to refresh.
    func load(refresh: Bool = false) async {
        if let running = loadTask {
            if !refresh { return await running.value }
            running.cancel()
        }
        loading = activities.isEmpty
        refreshing = refresh
        error = nil
        today = Formats.today()
        let task = Task {
            let result = await getCareAgenda(today: today)
            guard !Task.isCancelled else { return }
            switch result {
            case .success(let data): activities = data
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
