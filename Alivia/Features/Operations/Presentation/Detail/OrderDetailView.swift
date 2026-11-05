import SwiftUI

struct OrderDetailView: View {
    let orderId: Int64
    let onBack: () -> Void
    let onOpenEvaluation: (Int64) -> Void
    let onOpenInstallation: (Int64) -> Void
    let onOpenCompleted: (Int64) -> Void
    let onOpenResolve: (Int64) -> Void
    @State private var viewModel: OrderDetailViewModel

    init(orderId: Int64, onBack: @escaping () -> Void, onOpenEvaluation: @escaping (Int64) -> Void,
         onOpenInstallation: @escaping (Int64) -> Void, onOpenCompleted: @escaping (Int64) -> Void,
         onOpenResolve: @escaping (Int64) -> Void = { _ in }) {
        self.orderId = orderId
        self.onBack = onBack
        self.onOpenEvaluation = onOpenEvaluation
        self.onOpenInstallation = onOpenInstallation
        self.onOpenCompleted = onOpenCompleted
        self.onOpenResolve = onOpenResolve
        _viewModel = State(initialValue: OrderDetailViewModel(orderId: orderId, getOrder: OperationsModule.getOrder(),
                                                              startOrder: OperationsModule.startOrder(),
                                                              advanceIncident: OperationsModule.advanceIncident()))
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailTopBar(title: "Detalle de orden", subtitle: viewModel.order?.code, onBack: onBack)
            ZStack {
                if viewModel.loading {
                    LoadingView().frame(maxHeight: .infinity, alignment: .top)
                } else if let order = viewModel.order {
                    OrderBody(order: order)
                } else {
                    VStack(alignment: .leading) {
                        ErrorBanner(message: viewModel.error ?? "No encontramos la orden.")
                        Button("Reintentar") { Task { await viewModel.load() } }.foregroundStyle(AliviaColor.navyButton)
                        Spacer()
                    }
                    .padding(16)
                }
            }
            .frame(maxHeight: .infinity)
            if let order = viewModel.order {
                actions(order)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(AliviaColor.surface)
            }
        }
        .background(AliviaColor.background)
        .hidesNavigationBar()
        .task { await viewModel.load() }
        .sheet(isPresented: $viewModel.confirmingStart, onDismiss: { viewModel.cancelStart() }) {
            if let order = viewModel.order {
                StartAttentionSheet(order: order, starting: viewModel.starting, error: viewModel.startError,
                                    onConfirm: { viewModel.start(onStarted: continueWith) },
                                    onDismiss: { viewModel.cancelStart() })
            }
        }
    }

    private func continueWith(_ started: TechnicalOrder) {
        switch started.serviceType {
        case .evaluation: onOpenEvaluation(started.id)
        case .installation: onOpenInstallation(started.id)
        case .maintenance: onOpenResolve(started.id)
        }
    }

    @ViewBuilder
    private func actions(_ order: TechnicalOrder) -> some View {
        VStack(spacing: 8) {
            if let error = viewModel.advanceError { ErrorBanner(message: error) }
            stepActions(order)
        }
    }

    @ViewBuilder
    private func stepActions(_ order: TechnicalOrder) -> some View {
        switch order.incidentAction {
        case .evaluate:
            VStack(spacing: 8) {
                PrimaryButton(text: "Marcar como evaluada", icon: "checklist", busy: viewModel.advancing, container: AliviaColor.navy) {
                    Task { await viewModel.advance() }
                }
                Text("Revisaste el reporte de la familia: la incidencia pasa a En evaluación")
                    .font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted).multilineTextAlignment(.center)
            }
        case .confirmVisit:
            VStack(spacing: 8) {
                PrimaryButton(text: "Confirmar visita", icon: "calendar.badge.checkmark", busy: viewModel.advancing,
                              container: AliviaColor.navy) {
                    Task { await viewModel.advance() }
                }
                Text("La familia verá la visita programada para \(Formats.day(order.date)) · \(Formats.window(order.startTime, order.endTime))")
                    .font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted).multilineTextAlignment(.center)
            }
        case .resolve:
            PrimaryButton(text: "Registrar resolución", icon: "checkmark.circle", container: AliviaColor.navy) { onOpenResolve(order.id) }
        default:
            progressActions(order)
        }
    }

    @ViewBuilder
    private func progressActions(_ order: TechnicalOrder) -> some View {
        switch (order.progress, order.serviceType) {
        case (.scheduled, _):
            VStack(spacing: 8) {
                PrimaryButton(text: "Iniciar atención", icon: "play.circle", container: AliviaColor.navy) { viewModel.askToStart() }
                Text("Al pulsar, confirmarás el inicio antes de cambiar a En proceso")
                    .font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted).multilineTextAlignment(.center)
            }
        case (.inProgress, .evaluation):
            PrimaryButton(text: "Registrar resultado de la evaluación", icon: "checkmark.circle", container: AliviaColor.navy) {
                onOpenEvaluation(order.id)
            }
        case (.inProgress, .installation):
            PrimaryButton(text: "Continuar instalación", icon: "wrench.and.screwdriver", container: AliviaColor.navy) {
                onOpenInstallation(order.id)
            }
        case (.inProgress, _):
            PrimaryButton(text: "Registrar resolución", icon: "checkmark.circle", container: AliviaColor.navy) { onOpenResolve(order.id) }
        case (.completed, _):
            PrimaryButton(text: "Ver resumen", icon: "checkmark.circle", container: AliviaColor.navy) { onOpenCompleted(order.id) }
        case (.canceled, _):
            Text("La orden fue cancelada.").font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.inkMuted)
        }
    }
}

private struct OrderBody: View {
    let order: TechnicalOrder
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    TypePill(type: order.serviceType)
                    OrderStatusPill(order: order)
                }
                Text(order.homeName).font(AliviaFont.headlineSmall).foregroundStyle(AliviaColor.navy)
                HStack(spacing: 8) {
                    Image(systemName: "calendar").font(.system(size: 14)).foregroundStyle(AliviaColor.inkMuted)
                    Text("\(Formats.day(order.date)) · \(Formats.window(order.startTime, order.endTime))")
                        .font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.ink)
                }

                SectionLabel(text: "Visita").padding(.top, 8)
                AliviaCard {
                    InfoRow(icon: "person", label: "Responsable", value: order.contactName ?? "La familia no indicó quién recibe la visita") {
                        if let phone = order.contactPhone, let url = URL(string: "tel:\(phone.filter { !$0.isWhitespace })") {
                            Button { openURL(url) } label: {
                                Label("Llamar", systemImage: "phone")
                                    .font(AliviaFont.labelLarge)
                                    .foregroundStyle(AliviaColor.tealDark)
                                    .padding(.horizontal, 16)
                                    .frame(height: 40)
                                    .background(AliviaColor.teal, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Divider().overlay(AliviaColor.outline)
                    InfoRow(icon: "mappin.and.ellipse", label: "Referencia de acceso", value: order.directions ?? "Sin indicaciones registradas") {
                        if let directions = order.directions,
                           let query = directions.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                           let url = URL(string: "https://maps.apple.com/?q=\(query)") {
                            Button { openURL(url) } label: {
                                HStack(spacing: 4) {
                                    Text("Abrir en Maps").font(AliviaFont.labelMedium)
                                    Image(systemName: "arrow.up.right.square").font(.system(size: 14))
                                }
                                .foregroundStyle(AliviaColor.navy)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                SectionLabel(text: "Solicitud").padding(.top, 8)
                AliviaCard {
                    switch order.serviceType {
                    case .evaluation:
                        Text("Evaluación técnica de compatibilidad").font(AliviaFont.titleMedium).foregroundStyle(AliviaColor.navy)
                        Text("Revisa en el hogar que la configuración contratada pueda instalarse. Si el hogar es viable, la familia confirma la configuración en la web y se abre la orden de instalación; si no, la solicitud se cierra y se libera el pago de la familia.")
                            .font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.ink)
                    case .installation:
                        Text("Instalación de dispositivos").font(AliviaFont.titleMedium).foregroundStyle(AliviaColor.navy)
                        Text(order.installedDevices.isEmpty ? "Aún no hay dispositivos registrados." : "\(order.installedDevices.count) dispositivos registrados.")
                            .font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.ink)
                        ForEach(order.installedDevices, id: \.macAddress) { device in
                            HStack(spacing: 8) {
                                Image(systemName: "cpu").font(.system(size: 16)).foregroundStyle(AliviaColor.tealDark)
                                Text("\(device.alias) · \(device.type.label)").font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.ink)
                                Spacer()
                                Text(device.macAddress).font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
                            }
                        }
                    case .maintenance:
                        SectionLabel(text: "Problema reportado", color: AliviaColor.danger)
                        if let incident = order.incident {
                            IncidentContent(incident: incident)
                        } else {
                            Text("Incidencia #\(order.incidentId.map(String.init) ?? "")").font(AliviaFont.titleMedium).foregroundStyle(AliviaColor.navy)
                            Text("Revisa el dispositivo reportado por la familia.").font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.ink)
                        }
                    }
                    if let notes = order.completionNotes {
                        Divider().overlay(AliviaColor.outline)
                        InfoRow(icon: "info.circle", label: "Notas del cierre", value: notes) { EmptyView() }
                    }
                }
            }
            .padding(16)
        }
    }
}

/// The incident as the family reported it: code, problem, device and their description.
struct IncidentCard: View {
    let incident: IncidentSummary

    var body: some View {
        AliviaCard {
            SectionLabel(text: "Problema reportado", color: AliviaColor.danger)
            IncidentContent(incident: incident)
        }
    }
}

struct IncidentContent: View {
    let incident: IncidentSummary

    var body: some View {
        Text("\(incident.code) · \(incident.problem.label)").font(AliviaFont.titleMedium).foregroundStyle(AliviaColor.navy)
        if let device = incident.device {
            HStack(spacing: 8) {
                Image(systemName: "cpu").font(.system(size: 16)).foregroundStyle(AliviaColor.tealDark)
                Text("\(device.alias) · \(device.type.label)").font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.ink)
                Spacer()
                Text(device.macAddress).font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
            }
        }
        if !incident.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text("“\(incident.description)”").font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.ink)
        }
        if let occurredAt = incident.occurredAt {
            Text("Ocurrió \(Formats.moment(occurredAt))").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
        }
    }
}

private struct InfoRow<Action: View>: View {
    let icon: String
    let label: String
    let value: String
    @ViewBuilder let action: Action

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(AliviaColor.navySoft).frame(width: 40, height: 40)
                Image(systemName: icon).font(.system(size: 17)).foregroundStyle(AliviaColor.navy)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
                Text(value).font(AliviaFont.bodyLarge).foregroundStyle(AliviaColor.ink)
            }
            Spacer(minLength: 0)
            action
        }
    }
}
