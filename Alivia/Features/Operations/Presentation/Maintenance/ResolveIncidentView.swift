import SwiftUI

struct ResolveIncidentView: View {
    let onBack: () -> Void
    let onResolved: (Int64) -> Void
    @State private var viewModel: ResolveIncidentViewModel

    init(orderId: Int64, onBack: @escaping () -> Void, onResolved: @escaping (Int64) -> Void) {
        self.onBack = onBack
        self.onResolved = onResolved
        _viewModel = State(initialValue: ResolveIncidentViewModel(orderId: orderId, getOrder: OperationsModule.getOrder(),
                                                                  resolveIncident: OperationsModule.resolveIncident()))
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailTopBar(title: "Resolver incidencia",
                         subtitle: viewModel.order.map { "\($0.incident?.code ?? $0.code) · \($0.homeName)" }, onBack: onBack)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.order == nil, let loadError = viewModel.loadError {
                        ErrorBanner(message: loadError)
                    } else if let order = viewModel.order {
                        if let incident = order.incident { IncidentCard(incident: incident) }
                        SectionLabel(text: "Diagnóstico").padding(.top, 8)
                        AliviaCard {
                            ResolutionField(placeholder: "¿Qué encontraste en el dispositivo?", text: $viewModel.diagnosis)
                        }
                        SectionLabel(text: "Trabajo realizado").padding(.top, 8)
                        AliviaCard {
                            ResolutionField(placeholder: "Cambio de pila, recalibración, prueba de funcionamiento…",
                                            text: $viewModel.workPerformed)
                        }
                        Text("Al confirmar, la orden se cierra y la familia verá la incidencia como resuelta en la web.")
                            .font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
                        if let error = viewModel.error { ErrorBanner(message: error) }
                    } else {
                        LoadingView()
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            if viewModel.order != nil {
                PrimaryButton(text: "Marcar incidencia como resuelta", icon: "checkmark.circle", enabled: viewModel.canSubmit,
                              busy: viewModel.saving, container: AliviaColor.tealDark) {
                    Task { await viewModel.submit(onResolved: onResolved) }
                }
                .padding(16)
                .background(AliviaColor.surface)
            }
        }
        .background(AliviaColor.background)
        .hidesNavigationBar()
        .task { await viewModel.load() }
    }
}

private struct ResolutionField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(4...10)
                .font(AliviaFont.bodyLarge)
                .padding(12)
                .frame(minHeight: 110, alignment: .topLeading)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AliviaColor.outline, lineWidth: 1))
            Text("\(text.count)/\(ResolveIncidentUseCase.maxResolution)").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
                .padding(.leading, 16)
        }
    }
}
