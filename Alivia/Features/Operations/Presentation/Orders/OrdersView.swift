import SwiftUI

struct OrdersView: View {
    let onOpenOrder: (Int64) -> Void
    let onOpenProfile: () -> Void
    @State private var viewModel = OrdersViewModel(getMyOrders: OperationsModule.getMyOrders())
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let snapshot = viewModel.snapshot
        VStack(spacing: 0) {
            ScreenHeader(title: "Órdenes", subtitle: snapshot.summary, onOpenProfile: onOpenProfile)
            ViewSwitch(selection: $viewModel.view).padding(.horizontal, 16)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if viewModel.view == .calendar {
                        WeekCalendar(viewModel: viewModel)
                    }
                    Filters(snapshot: snapshot, selection: $viewModel.filter)
                    if let error = viewModel.error {
                        VStack(alignment: .leading, spacing: 4) {
                            ErrorBanner(message: error)
                            Button("Reintentar") { Task { await viewModel.load() } }
                                .foregroundStyle(AliviaColor.navyButton)
                        }
                    }
                    if viewModel.loading {
                        LoadingView()
                    } else if viewModel.view == .list {
                        let groups = snapshot.groups
                        if groups.isEmpty && viewModel.error == nil { EmptyOrders() }
                        ForEach(groups) { group in
                            GroupHeader(title: group.title, count: group.orders.count)
                            ForEach(group.orders) { order in
                                OrderCard(order: order, isNext: order.id == snapshot.nextOrderId) { onOpenOrder(order.id) }
                            }
                        }
                    } else {
                        let dayOrders = snapshot.filtered.filter { $0.date == viewModel.selectedDay }.sorted { $0.startTime < $1.startTime }
                        GroupHeader(title: Formats.day(viewModel.selectedDay, today: viewModel.today), count: dayOrders.count)
                        if dayOrders.isEmpty { EmptyOrders(text: "No tienes órdenes este día") }
                        ForEach(dayOrders) { order in
                            OrderCard(order: order, isNext: order.id == snapshot.nextOrderId) { onOpenOrder(order.id) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .refreshable { await viewModel.load(refresh: true) }
        }
        .background(AliviaColor.background)
        // Reload each time the screen is shown: entering the tab, coming back from an order or back to the app.
        .onAppear { Task { await viewModel.load() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.load() } }
        }
    }
}

private struct ViewSwitch: View {
    @Binding var selection: OrdersViewMode

    var body: some View {
        HStack(spacing: 4) {
            option(.list, "Lista", "list.bullet")
            option(.calendar, "Calendario", "calendar")
        }
        .padding(4)
        .background(AliviaColor.navySoft, in: RoundedRectangle(cornerRadius: 14))
    }

    private func option(_ value: OrdersViewMode, _ label: String, _ icon: String) -> some View {
        let selected = value == selection
        return Button { selection = value } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 15))
                Text(label).font(.system(size: 13, weight: selected ? .bold : .medium))
            }
            .foregroundStyle(AliviaColor.navy)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selected ? AliviaColor.surface : Color.clear, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct Filters: View {
    let snapshot: OrdersSnapshot
    @Binding var selection: OrderFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(OrderFilter.allCases, id: \.self) { filter in
                    let selected = filter == selection
                    Button { selection = filter } label: {
                        HStack(spacing: 8) {
                            if let type = filter.type { Dot(color: type.color, size: 8) }
                            Text(filter == .all ? "\(filter.label) (\(snapshot.count(for: filter)))" : filter.label)
                                .font(AliviaFont.labelMedium)
                        }
                        .foregroundStyle(selected ? .white : AliviaColor.ink)
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(selected ? AliviaColor.navy : AliviaColor.surface, in: Capsule())
                        .overlay(Capsule().stroke(selected ? Color.clear : AliviaColor.outline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }
}

private struct GroupHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title).font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.ink)
            Spacer()
            Text(count == 1 ? "1 orden" : "\(count) órdenes").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
        }
        .padding(.top, 4)
    }
}

struct OrderCard: View {
    let order: TechnicalOrder
    let isNext: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                Rectangle().fill(order.serviceType.color).frame(width: 5)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        if isNext { Pill(text: "SIGUIENTE", container: AliviaColor.tealSoft, content: AliviaColor.tealDark) }
                        Spacer()
                        ProgressPill(progress: order.progress)
                    }
                    Text(order.homeName).font(AliviaFont.titleMedium).foregroundStyle(AliviaColor.navy).lineLimit(1)
                    HStack(spacing: 6) {
                        Image(systemName: order.serviceType.icon).font(.system(size: 14)).foregroundStyle(order.serviceType.color)
                        Text("\(order.serviceType.label) · \(Formats.window(order.startTime, order.endTime))")
                            .font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.ink)
                    }
                    if let directions = order.directions {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.and.ellipse").font(.system(size: 14)).foregroundStyle(AliviaColor.inkMuted)
                            Text(directions).font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted).lineLimit(1)
                        }
                    }
                }
                .padding(.leading, 14)
                .padding(.vertical, 14)
                .padding(.trailing, 8)
                Image(systemName: "chevron.right").foregroundStyle(AliviaColor.inkMuted).padding(.trailing, 10)
            }
            .background(AliviaColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AliviaColor.outline, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

private struct WeekCalendar: View {
    @Bindable var viewModel: OrdersViewModel

    var body: some View {
        let monday = viewModel.selectedDay.monday
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(Formats.monthYear(viewModel.selectedDay)).font(AliviaFont.titleLarge).foregroundStyle(AliviaColor.navy)
                Pill(text: "Semana \(monday.isoWeek)", container: AliviaColor.tealSoft, content: AliviaColor.tealDark)
                Spacer()
                Button { viewModel.selectedDay = viewModel.selectedDay.plusWeeks(-1) } label: {
                    Image(systemName: "chevron.left").foregroundStyle(AliviaColor.navy).frame(width: 36, height: 36)
                }
                .accessibilityLabel("Semana anterior")
                Button { viewModel.selectedDay = viewModel.selectedDay.plusWeeks(1) } label: {
                    Image(systemName: "chevron.right").foregroundStyle(AliviaColor.navy).frame(width: 36, height: 36)
                }
                .accessibilityLabel("Semana siguiente")
            }
            .buttonStyle(.plain)
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { offset in
                    let day = monday.plusDays(offset)
                    let selected = day == viewModel.selectedDay
                    let isToday = day == viewModel.today
                    let types = ServiceType.allCases.filter { type in viewModel.orders.contains { $0.date == day && $0.serviceType == type } }
                    Button { viewModel.selectedDay = day } label: {
                        VStack(spacing: 6) {
                            Text(isToday ? "HOY" : Formats.shortWeekdayName(day))
                                .font(AliviaFont.labelSmall)
                                .foregroundStyle(isToday ? AliviaColor.navy : AliviaColor.inkMuted)
                            Text("\(day.day)")
                                .font(AliviaFont.titleSmall)
                                .foregroundStyle(selected ? .white : AliviaColor.ink)
                                .frame(width: 34, height: 34)
                                .background(selected ? AliviaColor.navy : Color.clear, in: Circle())
                            HStack(spacing: 3) { ForEach(types, id: \.self) { Dot(color: $0.color) } }.frame(height: 6)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selected ? AliviaColor.navySoft : Color.clear, in: RoundedRectangle(cornerRadius: 14))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                ForEach([ServiceType.maintenance, .installation, .evaluation], id: \.self) { type in
                    HStack(spacing: 6) {
                        Dot(color: type.color, size: 8)
                        Text(type.label).font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.ink)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(10)
            .background(AliviaColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(AliviaColor.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AliviaColor.outline, lineWidth: 1))
    }
}

private struct EmptyOrders: View {
    var text = "No tienes órdenes asignadas"

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(AliviaColor.navySoft).frame(width: 72, height: 72)
                Image(systemName: "calendar.badge.checkmark").font(.system(size: 28)).foregroundStyle(AliviaColor.navy)
            }
            Text(text).font(AliviaFont.titleMedium).foregroundStyle(AliviaColor.navy)
            Text("Cualquier nueva asignación aparecerá aquí.").font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
