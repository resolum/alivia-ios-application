import SwiftUI
import Observation

struct WorkingDayDto: Decodable {
    struct ShiftDto: Decodable { let start: String; let end: String }
    let date: String
    let shifts: [ShiftDto]
}

struct TechnicianWorkingDay: Identifiable {
    struct Shift: Identifiable {
        let start: LocalTime
        let end: LocalTime
        var id: String { "\(start.hour):\(start.minute)-\(end.hour):\(end.minute)" }
    }

    let date: LocalDate
    let shifts: [Shift]
    var id: String { date.iso }
}

/// The technician's working days between two dates, from `/api/v1/technical-orders/mine/schedule`.
enum TechnicianSchedule {
    static func load(from: LocalDate, to: LocalDate) async -> NetworkResult<[TechnicianWorkingDay]> {
        let path = "api/v1/technical-orders/mine/schedule?from=\(from.iso)&to=\(to.iso)"
        let result: NetworkResult<[WorkingDayDto]> = await BaseRepository.safeCall {
            try await SharedModule.apiClient.send("GET", path)
        }
        switch result {
        case .success(let response):
            return .success(response.compactMap { dto in
                guard let date = LocalDate(iso: dto.date) else { return nil }
                let shifts = dto.shifts.compactMap { shift -> TechnicianWorkingDay.Shift? in
                    guard let start = LocalTime(iso: shift.start), let end = LocalTime(iso: shift.end) else { return nil }
                    return .init(start: start, end: end)
                }
                return TechnicianWorkingDay(date: date, shifts: shifts)
            })
        case .error(let message, let code):
            return .error(message, code: code)
        }
    }
}

@Observable
final class ScheduleViewModel {
    private(set) var days: [TechnicianWorkingDay] = []
    private(set) var loading = true
    private(set) var error: String?
    private(set) var from = Formats.today().monday
    private(set) var to = Formats.today().monday.plusDays(13)

    func load() async {
        loading = days.isEmpty
        error = nil
        from = Formats.today().monday
        to = from.plusDays(13)
        switch await TechnicianSchedule.load(from: from, to: to) {
        case .success(let data): days = data
        case .error(let message, _): error = message
        }
        loading = false
    }
}

struct ScheduleView: View {
    let onOpenProfile: () -> Void
    @State private var viewModel = ScheduleViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Horario", subtitle: "Próximas 2 semanas", onOpenProfile: onOpenProfile)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    AliviaCard {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 24))
                                .foregroundStyle(AliviaColor.navy)
                                .frame(width: 48, height: 48)
                                .background(AliviaColor.navySoft, in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Jornada asignada").font(AliviaFont.titleMedium).foregroundStyle(AliviaColor.navy)
                                Text("\(viewModel.days.count) días laborables entre \(short(viewModel.from)) y \(short(viewModel.to))")
                                    .font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
                            }
                        }
                    }

                    if let error = viewModel.error {
                        ErrorBanner(message: error)
                        Button("Reintentar") { Task { await viewModel.load() } }
                            .font(AliviaFont.labelLarge).foregroundStyle(AliviaColor.navyButton)
                    } else if viewModel.loading {
                        LoadingView()
                    } else if viewModel.days.isEmpty {
                        AliviaCard {
                            Text("No tienes turnos asignados para estas dos semanas.")
                                .font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.inkMuted)
                        }
                    } else {
                        SectionLabel(text: "Turnos por día").padding(.top, 4)
                        ForEach(viewModel.days) { day in
                            dayCard(day)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .refreshable { await viewModel.load() }
        }
        .background(AliviaColor.background)
        .onAppear { Task { await viewModel.load() } }
    }

    private func dayCard(_ day: TechnicianWorkingDay) -> some View {
        AliviaCard {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 2) {
                    Text(Formats.shortWeekdayName(day.date)).font(AliviaFont.labelSmall).foregroundStyle(AliviaColor.tealDark)
                    Text("\(day.date.day)").font(AliviaFont.titleLarge).foregroundStyle(AliviaColor.navy)
                }
                .frame(width: 48, height: 54)
                .background(AliviaColor.tealSoft, in: RoundedRectangle(cornerRadius: 13))

                VStack(alignment: .leading, spacing: 8) {
                    Text(Formats.day(day.date)).font(AliviaFont.titleMedium).foregroundStyle(AliviaColor.ink)
                    ForEach(day.shifts) { shift in
                        HStack(spacing: 8) {
                            Image(systemName: "clock").foregroundStyle(AliviaColor.inkMuted)
                            Text(Formats.window(shift.start, shift.end))
                                .font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.ink)
                        }
                    }
                }
                Spacer()
            }
        }
    }

    private func short(_ date: LocalDate) -> String {
        DateFormatter.shortAlivia.string(from: date.date)
    }
}

private extension LocalDate {
    var iso: String { String(format: "%04d-%02d-%02d", year, month, day) }
}

private extension DateFormatter {
    static let shortAlivia: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Formats.locale
        formatter.timeZone = LocalDate.zone
        formatter.dateFormat = "d MMM"
        return formatter
    }()
}
