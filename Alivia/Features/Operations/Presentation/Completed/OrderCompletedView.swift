import SwiftUI

struct OrderCompletedView: View {
    let onBackToOrders: () -> Void
    let onOpenSummary: (Int64) -> Void
    let onOpenInstallation: (Int64) -> Void
    @State private var viewModel: OrderDetailViewModel

    init(orderId: Int64, onBackToOrders: @escaping () -> Void, onOpenSummary: @escaping (Int64) -> Void,
         onOpenInstallation: @escaping (Int64) -> Void) {
        self.onBackToOrders = onBackToOrders
        self.onOpenSummary = onOpenSummary
        self.onOpenInstallation = onOpenInstallation
        _viewModel = State(initialValue: OrderDetailViewModel(orderId: orderId, getOrder: OperationsModule.getOrder(),
                                                              startOrder: OperationsModule.startOrder()))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.loading {
                    LoadingView()
                } else if let order = viewModel.order {
                    Spacer().frame(height: 24)
                    ZStack {
                        Circle().fill(AliviaColor.tealSoft).frame(width: 96, height: 96)
                        Circle().fill(AliviaColor.teal).frame(width: 64, height: 64)
                        Image(systemName: "checkmark").font(.system(size: 28, weight: .semibold)).foregroundStyle(AliviaColor.tealDark)
                    }
                    Text("Orden completada").font(AliviaFont.headlineSmall).foregroundStyle(AliviaColor.navy)
                    Text("La información se registró correctamente").font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.ink)
                    VStack(spacing: 8) {
                        SummaryRow(icon: "number", label: "Código de orden") {
                            Text(order.code).font(AliviaFont.titleMedium).foregroundStyle(AliviaColor.navy)
                        }
                        SummaryRow(icon: "briefcase", label: "Tipo de orden") {
                            Pill(text: order.serviceType.longLabel, container: AliviaColor.navySoft, content: AliviaColor.navy)
                        }
                        SummaryRow(icon: "checkmark.seal", label: "Resultado final") { ResultPill(order: order) }
                        if let completedAt = order.completedAt {
                            SummaryRow(icon: "clock", label: "Finalización") {
                                Text(Formats.moment(completedAt)).font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.ink)
                            }
                        }
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.icloud").foregroundStyle(AliviaColor.tealDark)
                        Text(message(of: order)).font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.ink)
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(AliviaColor.navySoft, in: RoundedRectangle(cornerRadius: 12))
                    if order.awaitsFamilyConfirmation {
                        AwaitingFamilyConfirmation(order: order, onOpenInstallation: onOpenInstallation)
                    }
                    Spacer().frame(height: 8)
                    PrimaryButton(text: "Volver a órdenes", container: AliviaColor.navy, action: onBackToOrders)
                    Button { onOpenSummary(order.id) } label: {
                        Text("Ver resumen").font(AliviaFont.labelLarge).foregroundStyle(AliviaColor.navy)
                    }
                    .buttonStyle(.plain)
                } else {
                    ErrorBanner(message: viewModel.error ?? "No encontramos la orden.")
                }
            }
            .padding(20)
        }
        .background(AliviaColor.background)
        .hidesNavigationBar()
        .navigationBarBackButtonHidden(true)
        .task { await viewModel.load() }
    }

    private func message(of order: TechnicalOrder) -> String {
        if order.evaluationResult == .notViable { return "La solicitud se cerró y se liberó el pago retenido de la familia." }
        if order.installationResult == .approved {
            return "El hogar quedó en servicio con \(order.installedDevices.count) dispositivos. La orden está disponible en tu historial."
        }
        return "La orden se ha sincronizado y estará disponible en tu historial."
    }
}

extension TechnicalOrder {
    /// A viable evaluation waits for the family to confirm the configuration on the web before the installation.
    var awaitsFamilyConfirmation: Bool {
        serviceType == .evaluation && (evaluationResult == .viable || evaluationResult == .viableWithAdaptation)
    }
}

/// Asks the backend every few seconds, while the screen is shown, whether the family already confirmed: then the
/// installation order of the same request exists and the technician can start it.
private struct AwaitingFamilyConfirmation: View {
    let order: TechnicalOrder
    let onOpenInstallation: (Int64) -> Void
    @State private var installation: TechnicalOrder?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let found = installation {
                Text("La familia confirmó la configuración").font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.navy)
                Text("Ya puedes continuar con la instalación (\(found.code)).").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.ink)
                PrimaryButton(text: "Iniciar instalación", container: AliviaColor.tealDark) { onOpenInstallation(found.id) }
            } else {
                HStack(spacing: 10) {
                    ProgressView().tint(AliviaColor.tealDark)
                    Text("Esperando confirmación de la familia").font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.navy)
                }
                Text("La familia revisa y confirma la configuración desde la web. Cuando lo haga, aquí y en Órdenes aparecerá la orden de instalación.")
                    .font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.ink)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AliviaColor.surface, in: RoundedRectangle(cornerRadius: 12))
        .task(id: order.draftId) {
            let find = OperationsModule.findInstallationOfRequest()
            while installation == nil && !Task.isCancelled {
                if case .success(let found) = await find(order.draftId) { installation = found }
                if installation == nil { try? await Task.sleep(for: .seconds(5)) }
            }
        }
    }
}

private struct ResultPill: View {
    let order: TechnicalOrder

    var body: some View {
        if order.evaluationResult == .notViable {
            Pill(text: "No viable", container: AliviaColor.dangerSoft, content: AliviaColor.danger, dot: AliviaColor.danger)
        } else if order.evaluationResult == .viableWithAdaptation {
            Pill(text: "Viable con adaptación", container: AliviaColor.tealSoft, content: AliviaColor.tealDark, dot: AliviaColor.tealDark)
        } else if order.evaluationResult == .viable {
            Pill(text: "Viable", container: AliviaColor.tealSoft, content: AliviaColor.tealDark, dot: AliviaColor.tealDark)
        } else if order.installationResult == .approved {
            Pill(text: "Instalada", container: AliviaColor.tealSoft, content: AliviaColor.tealDark, dot: AliviaColor.tealDark)
        } else if order.installationResult == .rejected {
            Pill(text: "Rechazada", container: AliviaColor.dangerSoft, content: AliviaColor.danger, dot: AliviaColor.danger)
        } else {
            Pill(text: "Resuelta", container: AliviaColor.tealSoft, content: AliviaColor.tealDark, dot: AliviaColor.tealDark)
        }
    }
}

private struct SummaryRow<Value: View>: View {
    let icon: String
    let label: String
    @ViewBuilder let value: Value

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 17)).foregroundStyle(AliviaColor.inkMuted).frame(width: 20)
            Text(label).font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.inkMuted)
            Spacer()
            value
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(AliviaColor.surface, in: RoundedRectangle(cornerRadius: 12))
    }
}
