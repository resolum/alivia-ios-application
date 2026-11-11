import SwiftUI

/// Person the caregiver looks after, as `/api/v1/assisted-persons` returns them.
struct AssistedPerson: Identifiable, Sendable {
    let id: Int64
    /// Principal relative; the backend needs it to create activities for this person.
    let relativeId: Int64?
    let personProfileId: Int64?
    let householdId: Int64?
    let firstName: String
    let lastName: String
    let dni: String?
    let birthDate: LocalDate?
    let phoneNumber: String?
    let kinship: String?
    let mobilityLevel: String?
    let emergencyContactName: String?
    let emergencyContactPhone: String?

    var fullName: String { [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ") }
    var initials: String { careInitials(fullName) }

    func age(today: LocalDate) -> Int? {
        guard let birthDate else { return nil }
        return LocalDate.calendar.dateComponents([.year], from: birthDate.date, to: today.date).year
    }

    var kinshipLabel: String? {
        switch kinship {
        case "PARENT": return "Madre o padre"
        case "GRANDPARENT": return "Abuela o abuelo"
        case "AUNT_UNCLE": return "Tía o tío"
        case "SPOUSE": return "Cónyuge"
        case "SIBLING": return "Hermana o hermano"
        case "OTHER": return "Otro"
        default: return nil
        }
    }

    var mobilityLabel: String? {
        switch mobilityLevel {
        case "PARTIAL": return "Movilidad parcial"
        case "VERY_LIMITED": return "Movilidad muy limitada"
        case "NO_LIMB_MOBILITY": return "Sin movilidad de extremidades"
        default: return nil
        }
    }
}

enum CareRole: String, CaseIterable, Comparable, Sendable {
    case principal = "PRINCIPAL", caregiver = "CAREGIVER", guest = "GUEST"

    var label: String {
        switch self {
        case .principal: return "Principal"
        case .caregiver: return "Cuidador"
        case .guest: return "Invitado"
        }
    }

    var groupLabel: String {
        switch self {
        case .principal: return "Cuidador principal"
        case .caregiver: return "Cuidadores"
        case .guest: return "Invitados"
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool { allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)! }
}

/// A caregiver assigned to the assisted person; `isMe` marks the signed-in account.
struct CareCaregiver: Identifiable, Hashable, Sendable {
    let id: Int64
    let userId: Int64?
    let isMe: Bool
    var fullName: String? = nil
}

/// A member of the home's care network; the backend only gives the account and the role.
struct CareNetworkMember: Hashable, Sendable {
    let userId: Int64
    let role: CareRole
    var fullName: String? = nil
}

/// Days of a weekly schedule, as the backend names them; Monday first.
enum Weekday: String, CaseIterable, Comparable, Sendable {
    case monday = "MONDAY", tuesday = "TUESDAY", wednesday = "WEDNESDAY", thursday = "THURSDAY", friday = "FRIDAY",
         saturday = "SATURDAY", sunday = "SUNDAY"

    var initial: String { ["L", "M", "M", "J", "V", "S", "D"][Self.allCases.firstIndex(of: self)!] }

    /// The weekday of a date (Calendar counts Sunday as 1).
    init(_ date: LocalDate) {
        let weekday = LocalDate.calendar.component(.weekday, from: date.date)
        self = Self.allCases[(weekday + 5) % 7]
    }

    static func < (lhs: Self, rhs: Self) -> Bool { allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)! }
}

func careInitials(_ name: String) -> String {
    String(name.split(separator: " ").compactMap(\.first).prefix(2)).uppercased(with: Formats.locale)
}

nonisolated private struct AssistedPersonDto: Decodable {
    var id: Int64?
    var relativeId: Int64?
    var personProfileId: Int64?
    var householdId: Int64?
    var firstName: String?
    var lastName: String?
    var dni: String?
    var birthDate: String?
    var phoneNumber: String?
    var kinship: String?
    var mobilityLevel: String?
    var emergencyContactName: String?
    var emergencyContactPhone: String?
}

nonisolated private struct CaregiverDto: Decodable {
    var id: Int64?
    var userId: Int64?
    var status: String?
}

nonisolated private struct CreateCareActivityRequest: Encodable {
    let relativeId: Int64?
    let assistedPersonId: Int64
    let type: String
    let title: String
    let description: String?
}

nonisolated private struct AssignCareActivityRequest: Encodable {
    let relativeId: Int64?
    let caregiverId: Int64?
    let scheduleType: String
    let days: [String]?
    let date: String?
    let startTime: String
    let endTime: String
}

nonisolated private struct CompleteActivityRequest: Encodable {
    let careActivityId: Int64
    let assignmentId: Int64
    let date: String
    let notes: String?
}

nonisolated private struct HouseholdMemberDto: Decodable {
    var userId: Int64?
    var responsibility: String?
    var status: String?
    var fullName: String?
}

enum CareNetworkService {
    static func assistedPersons() async -> NetworkResult<[AssistedPerson]> {
        let result: NetworkResult<[AssistedPersonDto]> = await BaseRepository.safeCall {
            try await SharedModule.apiClient.send("GET", "api/v1/assisted-persons")
        }
        switch result {
        case .success(let list):
            return .success(list.compactMap { dto in
                guard let id = dto.id else { return nil }
                return AssistedPerson(
                    id: id, relativeId: dto.relativeId, personProfileId: dto.personProfileId, householdId: dto.householdId, firstName: clean(dto.firstName) ?? "", lastName: clean(dto.lastName) ?? "",
                    dni: clean(dto.dni), birthDate: LocalDate(iso: dto.birthDate), phoneNumber: clean(dto.phoneNumber),
                    kinship: dto.kinship, mobilityLevel: dto.mobilityLevel, emergencyContactName: clean(dto.emergencyContactName),
                    emergencyContactPhone: clean(dto.emergencyContactPhone))
            })
        case .error(let message, let code): return .error(message, code: code)
        }
    }

    static func members(householdId: Int64) async -> NetworkResult<[CareNetworkMember]> {
        let result: NetworkResult<[HouseholdMemberDto]> = await BaseRepository.safeCall {
            try await SharedModule.apiClient.send("GET", "api/v1/households/\(householdId)/members")
        }
        switch result {
        case .success(let list):
            return .success(list
                .filter { $0.status == nil || $0.status == "ACTIVE" }
                .compactMap { dto in
                    guard let userId = dto.userId, let role = dto.responsibility.flatMap(CareRole.init(rawValue:)) else { return nil }
                    return CareNetworkMember(userId: userId, role: role, fullName: clean(dto.fullName))
                }
                .sorted { $0.role < $1.role })
        case .error(let message, let code): return .error(message, code: code)
        }
    }

    /// Names who each occurrence is for and who is responsible, since the agenda leaves the names empty:
    /// "Tú" for the signed-in caregiver, "Otro cuidador" otherwise, and the assisted person from its profile id.
    static func nameAgendaPeople(_ activities: [CareActivity]) async -> [CareActivity] {
        var names: [Int64: String] = [:]
        var caregivers: [Int64: CareCaregiver] = [:]
        for person in await assistedPersons().value ?? [] {
            if let profileId = person.personProfileId { names[profileId] = person.fullName }
            for caregiver in await self.caregivers(assistedPersonId: person.id, householdId: person.householdId).value ?? [] {
                caregivers[caregiver.id] = caregiver
            }
        }
        return activities.map { activity in
            var named = activity
            if activity.assistedPerson == "Persona asistida", let profileId = activity.assistedPersonProfileId,
               let name = names[profileId] {
                named.assistedPerson = name
            }
            if activity.responsible == "Sin responsable", let caregiverId = activity.responsibleCaregiverId {
                let caregiver = caregivers[caregiverId]
                named.responsible = caregiver?.isMe == true ? "Tú" : caregiver?.fullName ?? "Otro cuidador"
            }
            return named
        }
    }

    /// Caregivers of the assisted person, the signed-in one first.
    static func caregivers(assistedPersonId: Int64, householdId: Int64?) async -> NetworkResult<[CareCaregiver]> {
        // The household members bring the names the caregivers list lacks.
        var names: [Int64: String] = [:]
        if let householdId, case .success(let members) = await self.members(householdId: householdId) {
            for member in members { if let name = member.fullName { names[member.userId] = name } }
        }
        let mineResult: NetworkResult<[CaregiverDto]> = await BaseRepository.safeCall {
            try await SharedModule.apiClient.send("GET", "api/v1/caregivers")
        }
        let mine = Set((mineResult.value ?? []).compactMap(\.id))
        let result: NetworkResult<[CaregiverDto]> = await BaseRepository.safeCall {
            try await SharedModule.apiClient.send("GET", "api/v1/caregivers?assistedPersonId=\(assistedPersonId)")
        }
        switch result {
        case .success(let list):
            return .success(list
                .filter { $0.status == nil || $0.status == "ACTIVE" }
                .compactMap { dto in
                    dto.id.map { CareCaregiver(id: $0, userId: dto.userId, isMe: mine.contains($0),
                                               fullName: dto.userId.flatMap { names[$0] }) }
                }
                .sorted { $0.isMe && !$1.isMe })
        case .error(let message, let code): return .error(message, code: code)
        }
    }

    /// Creates the activity and its schedule; empty `days` means a one-time occurrence on `date`.
    static func createActivity(person: AssistedPerson, type: CareActivityType, title: String, description: String?,
                               caregiverId: Int64?, date: LocalDate, days: Set<Weekday>, start: LocalTime,
                               end: LocalTime) async -> NetworkResult<Int64> {
        await BaseRepository.safeCall {
            let activityId: Int64 = try await SharedModule.apiClient.send(
                "POST", "api/v1/activities",
                body: CreateCareActivityRequest(relativeId: person.relativeId, assistedPersonId: person.id, type: type.rawValue,
                                                title: title, description: description))
            let _: Int64 = try await SharedModule.apiClient.send(
                "POST", "api/v1/activities/\(activityId)/assignments",
                body: AssignCareActivityRequest(
                    relativeId: person.relativeId, caregiverId: caregiverId,
                    scheduleType: days.isEmpty ? "ONE_TIME" : "WEEKLY",
                    days: days.isEmpty ? nil : days.sorted().map(\.rawValue),
                    date: days.isEmpty ? iso(date) : nil,
                    startTime: hour(start), endTime: hour(end)))
            return activityId
        }
    }

    static func complete(activityId: Int64, assignmentId: Int64, date: LocalDate, notes: String?) async -> NetworkResult<Void> {
        await BaseRepository.safeCall {
            try await SharedModule.apiClient.sendWithoutResponse(
                "POST", "api/v1/activity-logs/complete",
                body: CompleteActivityRequest(careActivityId: activityId, assignmentId: assignmentId, date: iso(date), notes: notes))
        }
    }

    private static func iso(_ date: LocalDate) -> String { String(format: "%04d-%02d-%02d", date.year, date.month, date.day) }
    private static func hour(_ time: LocalTime) -> String { String(format: "%02d:%02d", time.hour, time.minute) }

    private static func clean(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct InitialsAvatar: View {
    let text: String
    var size: CGFloat = 40
    var container: Color = AliviaColor.navySoft

    var body: some View {
        ZStack {
            Circle().fill(container)
            if text.isEmpty {
                Image(systemName: "person").font(.system(size: size / 2.4)).foregroundStyle(AliviaColor.navy)
            } else {
                Text(text).font(.system(size: size / 2.8, weight: .bold)).foregroundStyle(AliviaColor.navy)
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(AliviaColor.surface, lineWidth: 2))
    }
}

private func cardLink(_ text: String, action: @escaping () -> Void) -> some View {
    HStack {
        Spacer()
        Button(action: action) {
            HStack(spacing: 2) {
                Text(text).font(AliviaFont.labelLarge)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(AliviaColor.navy)
        }
        .buttonStyle(.plain)
    }
}

struct CareNetworkCard: View {
    let members: [CareNetworkMember]
    let person: AssistedPerson?
    let onOpen: () -> Void

    var body: some View {
        AliviaCard {
            HStack(spacing: 10) {
                Image(systemName: "person.3").font(.system(size: 13)).foregroundStyle(AliviaColor.navy)
                    .frame(width: 32, height: 32).background(AliviaColor.navySoft, in: Circle())
                Text("RED DE CUIDADO").font(AliviaFont.labelMedium).foregroundStyle(AliviaColor.ink)
                Spacer()
                if !members.isEmpty { Text("\(members.count) vinculados").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.ink) }
            }
            if members.isEmpty {
                Text("Todavía no hay otras personas en la red de cuidado.").font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.inkMuted)
            } else {
                let principal = members.first(where: { $0.role == .principal })?.fullName ?? person?.emergencyContactName
                HStack(spacing: 14) {
                    HStack(spacing: -12) {
                        ForEach(Array(members.prefix(3).enumerated()), id: \.offset) { index, member in
                            let text = index == 2 && members.count > 3 ? "+\(members.count - 2)"
                                : member.fullName.map(careInitials) ?? (member.role == .principal ? principal.map(careInitials) ?? "" : "")
                            InitialsAvatar(text: text, container: index == 0 ? AliviaColor.tealSoft : AliviaColor.navySoft)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(principal ?? "Familiar principal").font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.navy)
                        Text("Principal (familiar)").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.tealDark)
                    }
                }
            }
            cardLink("Ver red de cuidado", action: onOpen)
        }
    }
}

struct AssistedPersonCard: View {
    let person: AssistedPerson?
    let household: CaregiverHousehold?
    let today: LocalDate
    let onOpen: () -> Void

    var body: some View {
        AliviaCard {
            if let person {
                HStack(spacing: 14) {
                    InitialsAvatar(text: person.initials, size: 64, container: AliviaColor.tealSoft)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(person.fullName).font(AliviaFont.titleLarge).foregroundStyle(AliviaColor.navy)
                        Pill(text: "Sin alertas", container: AliviaColor.navySoft, content: AliviaColor.navy, dot: AliviaColor.tealDark)
                    }
                    Spacer()
                    if let age = person.age(today: today) {
                        Text("\(age) años").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.ink)
                    }
                }
                Divider()
                HStack {
                    Text(household?.alias ?? "Asistencia continua").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.ink)
                    cardLink("Ver perfil", action: onOpen)
                }
            } else {
                Text("PERSONA ASISTIDA").font(AliviaFont.labelMedium).foregroundStyle(AliviaColor.ink)
                Text("Todavía no tienes una persona asistida asignada.").font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.inkMuted)
            }
        }
    }
}

struct CareNetworkSheet: View {
    let members: [CareNetworkMember]
    let person: AssistedPerson?
    var myFullName: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Red de cuidado").font(AliviaFont.headlineSmall).foregroundStyle(AliviaColor.navy)
                if let person {
                    HStack(spacing: 12) {
                        InitialsAvatar(text: person.initials, container: AliviaColor.tealSoft)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.fullName).font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.navy)
                            Text("Persona asistida").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
                        }
                        Spacer()
                        Pill(text: "\(members.count) vinculados", container: AliviaColor.navySoft, content: AliviaColor.navy)
                    }
                }
                if members.isEmpty {
                    Text("Todavía no hay otras personas en la red de cuidado.").font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.inkMuted)
                }
                ForEach(CareRole.allCases, id: \.self) { role in
                    let group = members.filter { $0.role == role }
                    if !group.isEmpty {
                        SectionLabel(text: role.groupLabel).padding(.top, 4)
                        AliviaCard {
                            ForEach(Array(group.enumerated()), id: \.offset) { index, member in
                                if index > 0 { Divider() }
                                let name = member.fullName ?? (role == .principal ? person?.emergencyContactName : nil)
                                let isMe = name != nil && name == myFullName
                                HStack(spacing: 12) {
                                    InitialsAvatar(text: name.map(careInitials) ?? "", size: 40,
                                                   container: isMe ? AliviaColor.tealSoft : AliviaColor.navySoft)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(name ?? "\(role.label) \(index + 1)").font(AliviaFont.titleSmall)
                                                .foregroundStyle(AliviaColor.navy)
                                            if isMe { Pill(text: "Tú", container: AliviaColor.tealSoft, content: AliviaColor.tealDark) }
                                        }
                                        Text(subtitle(role)).font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
                                    }
                                    Spacer()
                                    Pill(text: "Vinculado", container: AliviaColor.tealSoft, content: AliviaColor.tealDark,
                                         dot: AliviaColor.tealDark)
                                }
                            }
                        }
                    }
                }
                Label("La gestión de cuidadores se realiza desde la plataforma web.", systemImage: "info.circle")
                    .font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.ink)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(AliviaColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 16)
        }
        .background(AliviaColor.surface)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func subtitle(_ role: CareRole) -> String {
        switch role {
        case .principal: return "Familiar responsable · Principal"
        case .caregiver: return "Cuidador de \(person?.firstName ?? "la persona asistida")"
        case .guest: return "Acceso de solo lectura"
        }
    }
}

struct AssistedPersonSheet: View {
    let person: AssistedPerson
    let household: CaregiverHousehold?
    let today: LocalDate

    private static let birthFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Formats.locale
        formatter.timeZone = LocalDate.zone
        formatter.dateFormat = "d 'de' MMMM 'de' yyyy"
        return formatter
    }()

    var body: some View {
        let age = person.age(today: today)
        ScrollView {
            VStack(spacing: 10) {
                InitialsAvatar(text: person.initials, size: 88, container: AliviaColor.tealSoft)
                Text(person.fullName).font(AliviaFont.headlineSmall).foregroundStyle(AliviaColor.navy).multilineTextAlignment(.center)
                Pill(text: "Perfil completo", container: AliviaColor.tealSoft, content: AliviaColor.tealDark, dot: AliviaColor.tealDark)
                Text([age.map { "\($0) años" }, household?.alias].compactMap { $0 }.joined(separator: " · "))
                    .font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
                SectionLabel(text: "Información personal").frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                AliviaCard {
                    row("Nombres", person.firstName)
                    row("Apellidos", person.lastName)
                    if let dni = person.dni { row("Documento", "DNI \(dni)") }
                    if let birth = person.birthDate {
                        row("Fecha de nacimiento", Self.birthFormat.string(from: birth.date) + (age.map { " (\($0) años)" } ?? ""))
                    }
                    if let kinship = person.kinshipLabel { row("Parentesco", kinship) }
                    if let mobility = person.mobilityLabel { row("Movilidad", mobility) }
                }
                SectionLabel(text: "Información asociada").frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                AliviaCard {
                    if let household { row("Hogar relacionado", household.alias) }
                    if let name = person.emergencyContactName { row("Cuidador principal", name) }
                    if let phone = person.emergencyContactPhone { row("Teléfono de contacto", "+\(phone)") }
                    if let phone = person.phoneNumber { row("Teléfono de la persona", "+\(phone)") }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 16)
        }
        .background(AliviaColor.surface)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.inkMuted)
            Spacer()
            Text(value).font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.ink).multilineTextAlignment(.trailing)
        }
    }
}
