import Observation
import SwiftUI

/// Two steps: what the activity is, then when it happens and who is responsible.
@Observable
final class NewActivityViewModel {
    enum Step { case activity, schedule }

    private(set) var loading = true
    private(set) var error: String?
    var step: Step = .activity
    private(set) var person: AssistedPerson?
    private(set) var caregivers: [CareCaregiver] = []
    private(set) var type: CareActivityType?
    var title = "" { didSet { if title.count > 120 { title = String(title.prefix(120)) } } }
    var activityDescription = "" { didSet { if activityDescription.count > 500 { activityDescription = String(activityDescription.prefix(500)) } } }
    var date = Date()
    /// A start equal to the end pushes the end 30 minutes after it.
    var start = NewActivityViewModel.time(9, 0) {
        didSet { if sameTime(start, end) { end = start.addingTimeInterval(30 * 60) } }
    }
    var end = NewActivityViewModel.time(9, 30)

    /// Why "Confirmar programación" is disabled, shown under the button.
    var blockedReason: String? {
        if caregiverId == nil { return "Elige al responsable de la actividad." }
        if sameTime(start, end) { return "La hora de inicio y de fin no pueden ser iguales." }
        if weekly && days.isEmpty { return "Elige al menos un día de la semana." }
        return nil
    }
    var weekly = false { didSet { if weekly && days.isEmpty { days = [Weekday(LocalDate(date))] } } }
    var days: Set<Weekday> = []
    var caregiverId: Int64?
    private(set) var saving = false
    private(set) var saved = false

    var canContinue: Bool { person != nil && type != nil && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var canSave: Bool { canContinue && blockedReason == nil && !saving }

    /// An end earlier than the start means the activity ends the next day, as the backend allows.
    var endsNextDay: Bool { localTime(end) < localTime(start) }

    private func sameTime(_ a: Date, _ b: Date) -> Bool { localTime(a) == localTime(b) }

    static func time(_ hour: Int, _ minute: Int) -> Date {
        LocalDate.calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    func load() async {
        loading = true
        error = nil
        switch await CareNetworkService.assistedPersons() {
        case .error(let message, _): error = message
        case .success(let persons):
            person = persons.first
            if let person, case .success(let list) = await CareNetworkService.caregivers(assistedPersonId: person.id, householdId: person.householdId) {
                caregivers = list
                caregiverId = caregiverId ?? list.first(where: \.isMe)?.id ?? list.first?.id
            }
        }
        loading = false
    }

    func select(_ newType: CareActivityType) {
        if title.isEmpty || title == type.map(Self.suggestion) { title = Self.suggestion(newType) }
        type = newType
        error = nil
    }

    func next() {
        if canContinue { step = .schedule; error = nil } else { error = "Elige el tipo y escribe el nombre de la actividad." }
    }

    func save() async {
        guard let person, let type else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDescription = activityDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let startTime = localTime(start), endTime = localTime(end)
        let day = LocalDate(date)
        if !weekly && day < Formats.today() { error = "La fecha no puede ser anterior a hoy."; return }
        if endTime == startTime { error = "La hora de inicio y de fin no pueden ser iguales."; return }
        saving = true
        error = nil
        let result = await CareNetworkService.createActivity(
            person: person, type: type, title: cleanTitle, description: cleanDescription.isEmpty ? nil : cleanDescription,
            caregiverId: caregiverId, date: day, days: weekly ? days : [], start: startTime, end: endTime)
        switch result {
        case .success: saved = true
        case .error(_, 409): error = "El responsable ya tiene otra actividad en ese horario."
        case .error(let message, _): error = message
        }
        saving = false
    }

    private func localTime(_ date: Date) -> LocalTime {
        let parts = LocalDate.calendar.dateComponents([.hour, .minute], from: date)
        return LocalTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    private static func suggestion(_ type: CareActivityType) -> String {
        switch type {
        case .hygiene: return "Aseo personal"
        case .medication: return "Medicación"
        case .appointment: return "Cita médica"
        case .therapy: return "Sesión de terapia"
        case .meal: return "Alimentación"
        case .bath: return "Baño asistido"
        case .exercise: return "Paseo asistido"
        case .other: return ""
        }
    }
}

/// Creates a care activity for the assisted person and assigns it to the caregiver or another one.
struct NewActivityView: View {
    let onClose: () -> Void
    @State private var viewModel = NewActivityViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    if viewModel.step == .schedule { viewModel.step = .activity } else { onClose() }
                } label: {
                    Image(systemName: "arrow.left").font(.system(size: 18, weight: .medium)).foregroundStyle(AliviaColor.navy)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Volver")
                VStack(alignment: .leading, spacing: 0) {
                    Text(viewModel.step == .activity ? "Nueva actividad" : "Programación")
                        .font(AliviaFont.titleLarge).foregroundStyle(AliviaColor.navy)
                    Text("Paso \(viewModel.step == .activity ? 1 : 2) de 2").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            stepTabs
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.loading {
                        LoadingView()
                    } else if viewModel.step == .activity {
                        activityStep
                    } else {
                        scheduleStep
                    }
                    if let error = viewModel.error { ErrorBanner(message: error) }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            VStack {
                if viewModel.step == .activity {
                    PrimaryButton(text: "Continuar", icon: "arrow.right", enabled: viewModel.canContinue, container: AliviaColor.navy) {
                        viewModel.next()
                    }
                } else {
                    if let reason = viewModel.blockedReason {
                        Label(reason, systemImage: "exclamationmark.circle").font(AliviaFont.bodySmall)
                            .foregroundStyle(AliviaColor.danger)
                    }
                    PrimaryButton(text: "Confirmar programación", icon: "checkmark", enabled: viewModel.canSave, busy: viewModel.saving,
                                  container: AliviaColor.navy) {
                        Task { await viewModel.save() }
                    }
                }
            }
            .padding(16)
            .background(AliviaColor.surface)
        }
        .background(AliviaColor.background)
        .hidesNavigationBar()
        .task { await viewModel.load() }
        .onChange(of: viewModel.saved) { _, saved in if saved { onClose() } }
    }

    private var stepTabs: some View {
        HStack(spacing: 0) {
            ForEach([("1  Actividad", NewActivityViewModel.Step.activity), ("2  Programación", .schedule)], id: \.0) { label, step in
                let selected = viewModel.step == step
                Text(label).font(AliviaFont.labelLarge).foregroundStyle(selected ? .white : AliviaColor.navy)
                    .frame(maxWidth: .infinity).frame(height: 36)
                    .background(selected ? AliviaColor.navy : .clear, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(4)
        .background(AliviaColor.navySoft, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var activityStep: some View {
        SectionLabel(text: "Persona asistida")
        AliviaCard {
            if let person = viewModel.person {
                HStack(spacing: 12) {
                    InitialsAvatar(text: person.initials, size: 44, container: AliviaColor.tealSoft)
                    Text(person.fullName).font(AliviaFont.titleMedium).foregroundStyle(AliviaColor.navy)
                }
            } else {
                Text("No tienes una persona asistida asignada.").font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.inkMuted)
            }
        }
        SectionLabel(text: "Tipo de actividad").padding(.top, 4)
        // One swipeable row, as the design shows it.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
            ForEach(CareActivityType.allCases, id: \.self) { type in
                let selected = viewModel.type == type
                Button { viewModel.select(type) } label: {
                    Label(type.label, systemImage: type.icon).font(AliviaFont.labelMedium)
                        .foregroundStyle(selected ? .white : AliviaColor.navy)
                        .padding(.horizontal, 14).frame(height: 38)
                        .background(selected ? AliviaColor.navy : AliviaColor.surface, in: Capsule())
                        .overlay(Capsule().stroke(selected ? .clear : AliviaColor.outline, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            }
            .padding(.vertical, 1)
        }
        SectionLabel(text: "Detalle").padding(.top, 4)
        field { TextField("Nombre (ej. Medicación de la mañana)", text: $viewModel.title) }
        field {
            TextField("Instrucción (opcional)", text: $viewModel.activityDescription, axis: .vertical).lineLimit(3...6)
        }
        Text("\(viewModel.activityDescription.count)/500").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
    }

    @ViewBuilder
    private var scheduleStep: some View {
        AliviaCard {
            HStack(spacing: 12) {
                Image(systemName: viewModel.type?.icon ?? "clock").foregroundStyle(AliviaColor.tealDark)
                    .frame(width: 40, height: 40).background(AliviaColor.tealSoft, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text((viewModel.type?.label ?? "").uppercased(with: Formats.locale)).font(AliviaFont.labelSmall)
                        .foregroundStyle(AliviaColor.tealDark)
                    Text(viewModel.title).font(AliviaFont.titleMedium).foregroundStyle(AliviaColor.navy)
                    if let person = viewModel.person {
                        Text(person.fullName).font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
                    }
                }
            }
        }
        SectionLabel(text: "Fecha y hora").padding(.top, 4)
        AliviaCard {
            if !viewModel.weekly {
                DatePicker("Fecha", selection: $viewModel.date, in: Date()..., displayedComponents: .date)
            }
            DatePicker("Inicio", selection: $viewModel.start, displayedComponents: .hourAndMinute)
            DatePicker("Fin", selection: $viewModel.end, displayedComponents: .hourAndMinute)
            if viewModel.endsNextDay {
                Label("Termina al día siguiente", systemImage: "moon").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
            }
        }
        .environment(\.locale, Formats.locale)
        .environment(\.timeZone, LocalDate.zone)
        SectionLabel(text: "Repetición").padding(.top, 4)
        AliviaCard {
            Picker("Repetición", selection: $viewModel.weekly) {
                Text("No se repite").tag(false)
                Text("Cada semana").tag(true)
            }
            .pickerStyle(.segmented)
            if viewModel.weekly {
                HStack(spacing: 6) {
                    ForEach(Weekday.allCases, id: \.self) { day in
                        let selected = viewModel.days.contains(day)
                        Button {
                            if selected { viewModel.days.remove(day) } else { viewModel.days.insert(day) }
                        } label: {
                            Text(day.initial).font(AliviaFont.labelLarge).foregroundStyle(selected ? .white : AliviaColor.navy)
                                .frame(width: 38, height: 38)
                                .background(selected ? AliviaColor.navy : AliviaColor.navySoft, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        SectionLabel(text: "Responsable").padding(.top, 4)
        if viewModel.caregivers.isEmpty {
            AliviaCard {
                Text("No hay cuidadores asignados a esta persona.").font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.inkMuted)
            }
        }
        ForEach(Array(viewModel.caregivers.enumerated()), id: \.element.id) { index, caregiver in
            let others = viewModel.caregivers.prefix(index + 1).filter { !$0.isMe }.count
            let selected = viewModel.caregiverId == caregiver.id
            Button { viewModel.caregiverId = caregiver.id } label: {
                HStack(spacing: 12) {
                    InitialsAvatar(text: caregiver.isMe ? "TÚ" : caregiver.fullName.map(careInitials) ?? "C\(others)",
                                   container: caregiver.isMe ? AliviaColor.tealSoft : AliviaColor.navySoft)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(caregiver.isMe ? "Tú" : caregiver.fullName ?? "Otro cuidador \(others)")
                            .font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.navy)
                        Text(caregiver.isMe ? caregiver.fullName ?? "Cuidador activo en turno" : "Cuidador de la red")
                            .font(AliviaFont.bodySmall)
                            .foregroundStyle(caregiver.isMe ? AliviaColor.tealDark : AliviaColor.inkMuted)
                    }
                    Spacer()
                    Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(selected ? AliviaColor.navy : AliviaColor.inkMuted)
                }
                .padding(14)
                .background(AliviaColor.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? AliviaColor.navy : AliviaColor.outline,
                                                                   lineWidth: selected ? 2 : 1))
            }
            .buttonStyle(.plain)
        }
    }

    private func field<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(AliviaFont.bodyLarge)
            .padding(14)
            .background(AliviaColor.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AliviaColor.outline, lineWidth: 1))
    }
}
