import Observation
import SwiftUI

/// The home the signed-in caregiver belongs to, from `/api/v1/households/mine`.
struct CaregiverHousehold: Sendable {
    let alias: String
    let address: String?
}

nonisolated private struct HouseholdDto: Decodable {
    var id: Int64?
    var alias: String?
    var formattedAddress: String?
}

enum CaregiverHouseholdService {
    /// The caregiver's home, or nil when the account is not linked to one yet (404).
    static func mine() async -> NetworkResult<CaregiverHousehold?> {
        let result: NetworkResult<HouseholdDto> = await BaseRepository.safeCall {
            try await SharedModule.apiClient.send("GET", "api/v1/households/mine")
        }
        switch result {
        case .success(let dto):
            guard dto.id != nil else { return .success(nil) }
            let alias = dto.alias?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let address = dto.formattedAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return .success(CaregiverHousehold(alias: alias.isEmpty ? "Mi hogar" : alias, address: address.isEmpty ? nil : address))
        case .error(_, 404): return .success(nil)
        case .error(let message, let code): return .error(message, code: code)
        }
    }
}

/// Caregiver's start screen: greeting, next activity, care network and the assisted person.
@Observable
final class CaregiverHomeViewModel {
    private(set) var loading = true
    private(set) var error: String?
    private(set) var today = Formats.today()
    private(set) var firstName: String?
    private(set) var household: CaregiverHousehold?
    private(set) var activities: [CareActivity] = []
    private(set) var assistedPerson: AssistedPerson?
    private(set) var network: [CareNetworkMember] = []

    private let getCareAgenda: GetCareAgendaUseCase
    private let getProfile: GetMyProfileUseCase

    init(getCareAgenda: GetCareAgendaUseCase, getProfile: GetMyProfileUseCase) {
        self.getCareAgenda = getCareAgenda
        self.getProfile = getProfile
    }

    /// The first pending activity from now on.
    var nextActivity: CareActivity? {
        let now = Date()
        return activities
            .filter { $0.status == .scheduled || $0.status == .inProgress }
            .filter { $0.startsAt >= now || ($0.date == today && $0.status == .inProgress) }
            .min { ($0.date, $0.startTime) < ($1.date, $1.startTime) }
    }

    var todayCount: Int { activities.filter { $0.date == today }.count }

    func load() async {
        today = Formats.today()
        loading = activities.isEmpty && household == nil
        error = nil
        async let agendaResult = getCareAgenda(today: today)
        async let profileResult = getProfile()
        async let householdResult = CaregiverHouseholdService.mine()
        if case .success(let profile) = await profileResult, !profile.firstName.isEmpty { firstName = profile.firstName }
        if case .success(let home) = await householdResult { household = home }
        if case .success(let persons) = await CareNetworkService.assistedPersons(), let person = persons.first {
            assistedPerson = person
        }
        if let householdId = assistedPerson?.householdId,
           case .success(let members) = await CareNetworkService.members(householdId: householdId) {
            network = members
        }
        switch await agendaResult {
        case .success(let data): activities = data
        case .error(let message, _): error = message
        }
        loading = false
    }
}

struct CaregiverHomeView: View {
    let onOpenActivities: () -> Void
    let onOpenNotifications: () -> Void
    @State private var viewModel = CaregiverHomeViewModel(getCareAgenda: CareModule.getCareAgenda(),
                                                          getProfile: ProfilesModule.getMyProfile())
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingNetwork = false
    @State private var showingPerson = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.firstName.map { "Hola, \($0)" } ?? "Hola")
                            .font(AliviaFont.headlineMedium).foregroundStyle(AliviaColor.navy)
                        Text("¡Bienvenido a Alivia Cuidados! Tu resumen y el estado del hogar para hoy.")
                            .font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.ink)
                    }
                    .padding(.top, 8)
                    Spacer()
                    NotificationsButton(action: onOpenNotifications)
                }
                if viewModel.loading {
                    LoadingView()
                } else {
                    if let error = viewModel.error {
                        VStack(alignment: .leading, spacing: 4) {
                            ErrorBanner(message: error)
                            Button("Reintentar") { Task { await viewModel.load() } }.foregroundStyle(AliviaColor.navyButton)
                        }
                    }
                    nextActivityCard
                    CareNetworkCard(members: viewModel.network, person: viewModel.assistedPerson) { showingNetwork = true }
                    AssistedPersonCard(person: viewModel.assistedPerson, household: viewModel.household, today: viewModel.today) {
                        showingPerson = true
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .refreshable { await viewModel.load() }
        .background(AliviaColor.background)
        .onAppear { Task { await viewModel.load() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.load() } }
        }
        .sheet(isPresented: $showingNetwork) { CareNetworkSheet(members: viewModel.network, person: viewModel.assistedPerson) }
        .sheet(isPresented: $showingPerson) {
            if let person = viewModel.assistedPerson {
                AssistedPersonSheet(person: person, household: viewModel.household, today: viewModel.today)
            }
        }
    }

    private func cardTitle(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(AliviaColor.navy)
                .frame(width: 32, height: 32).background(AliviaColor.navySoft, in: Circle())
            Text(title.uppercased(with: Formats.locale)).font(AliviaFont.labelMedium).foregroundStyle(AliviaColor.ink)
        }
    }

    private var nextActivityCard: some View {
        let activity = viewModel.nextActivity
        return AliviaCard {
            HStack {
                cardTitle("clock", "Próxima actividad")
                Spacer()
                if let activity {
                    Pill(text: activity.status.label, container: activity.status.container, content: activity.status.content)
                }
            }
            if let activity {
                Text(activity.title).font(AliviaFont.titleLarge).foregroundStyle(AliviaColor.navy)
                HStack(spacing: 6) {
                    Image(systemName: "calendar").font(.system(size: 13)).foregroundStyle(AliviaColor.navy)
                    let day = Formats.day(activity.date, today: viewModel.today).components(separatedBy: ",").first ?? ""
                    Text("\(day) · \(Formats.time(activity.startTime))").font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.ink)
                }
                if activity.responsible != "Sin responsable" {
                    Text("A cargo de: \(Text(activity.responsible).fontWeight(.semibold))")
                        .font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.ink)
                }
            } else {
                Text("No tienes actividades pendientes").font(AliviaFont.titleMedium).foregroundStyle(AliviaColor.navy)
                Text(viewModel.todayCount == 0 ? "No hay actividades programadas para hoy." : "Completaste las actividades de hoy.")
                    .font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.inkMuted)
            }
            HStack {
                Spacer()
                Button(action: onOpenActivities) {
                    HStack(spacing: 2) {
                        Text("Ver actividades").font(AliviaFont.labelLarge)
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(AliviaColor.navy)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
