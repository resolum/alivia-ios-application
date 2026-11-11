import Foundation
import Observation

enum AgendaGroupKind: Int, CaseIterable {
    case today, tomorrow, upcoming, past

    var title: String {
        switch self {
        case .today: return "Hoy"
        case .tomorrow: return "Mañana"
        case .upcoming: return "Pasado mañana"
        case .past: return "Ayer"
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

    /// Hoy, Mañana, Pasado mañana and Ayer, skipping the empty ones. Each group runs by time;
    /// Ayer goes from the most recent to the oldest.
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

enum AgendaViewMode { case list, calendar }

@Observable
final class AgendaViewModel {
    var mode: AgendaViewMode = .list
    /// Only the principal relative creates activities; the rest only follow them.
    private(set) var canCreate = false

    func loadRole() async {
        if case .success(let home) = await CaregiverHouseholdService.mine() { canCreate = home?.canPlanActivities ?? false }
    }
    /// First day of the month the calendar shows.
    private(set) var month = LocalDate(year: Formats.today().year, month: Formats.today().month, day: 1)
    private(set) var monthActivities: [CareActivity] = []
    private(set) var monthLoading = false
    var selectedDay = Formats.today()

    var daysWithActivities: Set<LocalDate> { Set(monthActivities.map(\.date)) }

    var selectedDayActivities: [CareActivity] {
        monthActivities.filter { $0.date == selectedDay }.sorted { $0.startTime < $1.startTime }
    }

    var daysInMonth: Int { LocalDate.calendar.range(of: .day, in: .month, for: month.date)?.count ?? 30 }

    func moveMonth(_ delta: Int) async {
        let moved = LocalDate.calendar.date(byAdding: .month, value: delta, to: month.date) ?? month.date
        month = LocalDate(moved)
        let today = Formats.today()
        selectedDay = (today.year == month.year && today.month == month.month) ? today : month
        await loadMonth()
    }

    func loadMonth() async {
        monthLoading = true
        let last = month.plusDays(daysInMonth - 1)
        if case .success(let data) = await getCareAgenda.between(month, last) {
            monthActivities = await CareNetworkService.nameAgendaPeople(data)
        }
        monthLoading = false
    }

    private(set) var loading = true
    private(set) var refreshing = false
    private(set) var error: String?
    private(set) var activities: [CareActivity] = []
    /// Pending reminders. They load apart from the agenda, and a failure only hides the section.
    private(set) var reminders: [CareActivity] = []
    private(set) var today = Formats.today()

    private let getCareAgenda: GetCareAgendaUseCase
    private let getReminders: GetRemindersUseCase
    private let scheduler: ReminderNotificationScheduler
    private var askedForNotifications = false
    private var loadTask: Task<Void, Never>?

    init(getCareAgenda: GetCareAgendaUseCase, getReminders: GetRemindersUseCase, scheduler: ReminderNotificationScheduler) {
        self.scheduler = scheduler
        self.getCareAgenda = getCareAgenda
        self.getReminders = getReminders
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
        if !askedForNotifications {
            askedForNotifications = true
            await scheduler.requestAuthorizationIfNeeded()
        }
        let task = Task {
            async let remindersResult = getReminders()
            let result = await getCareAgenda(today: today)
            let remindersOutcome = await remindersResult
            guard !Task.isCancelled else { return }
            switch result {
            case .success(let data): activities = await CareNetworkService.nameAgendaPeople(data)
            case .error(let message, _): error = message
            }
            if case .success(let data) = remindersOutcome {
                reminders = data
                await scheduler.reschedule(data)
            }
            loading = false
            refreshing = false
        }
        loadTask = task
        await task.value
        if loadTask == task { loadTask = nil }
    }
}
