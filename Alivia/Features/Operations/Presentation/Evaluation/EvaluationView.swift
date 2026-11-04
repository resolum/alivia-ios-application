import SwiftUI

struct EvaluationView: View {
    let onBack: () -> Void
    let onNext: (EvaluationNext) -> Void
    @State private var viewModel: EvaluationViewModel

    init(orderId: Int64, onBack: @escaping () -> Void, onNext: @escaping (EvaluationNext) -> Void) {
        self.onBack = onBack
        self.onNext = onNext
        _viewModel = State(initialValue: EvaluationViewModel(orderId: orderId, getOrder: OperationsModule.getOrder(),
                                                             recordEvaluation: OperationsModule.recordEvaluation()))
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailTopBar(title: "Resultado de la evaluación",
                         subtitle: viewModel.order.map { "\($0.code) · \($0.homeName)" }, onBack: onBack)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.order == nil, let loadError = viewModel.loadError {
                        ErrorBanner(message: loadError)
                    } else if viewModel.order == nil {
                        LoadingView()
                    } else {
                        Text("¿El hogar puede recibir la configuración contratada?")
                            .font(AliviaFont.titleMedium).foregroundStyle(AliviaColor.navy)
                        ResultOption(value: .viable, selected: viewModel.result, icon: "checkmark.circle",
                                     tint: AliviaColor.installation, soft: AliviaColor.tealSoft, title: "Viable",
                                     description: "El hogar cumple. La familia confirma la configuración en la web y luego se abre la instalación.") {
                            viewModel.select($0)
                        }
                        ResultOption(value: .notViable, selected: viewModel.result, icon: "nosign",
                                     tint: AliviaColor.danger, soft: AliviaColor.dangerSoft, title: "No viable",
                                     description: "Se cierra la solicitud y se devuelve a la familia el monto que pagó.") {
                            viewModel.select($0)
                        }
                        SectionLabel(text: "Notas").padding(.top, 8)
                        AliviaCard {
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("Observaciones de la visita", text: $viewModel.notes, axis: .vertical)
                                    .lineLimit(5...10)
                                    .font(AliviaFont.bodyLarge)
                                    .padding(12)
                                    .frame(minHeight: 120, alignment: .topLeading)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AliviaColor.outline, lineWidth: 1))
                                Text("\(viewModel.notes.count)/300").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
                                    .padding(.leading, 16)
                            }
                        }
                        if let error = viewModel.error { ErrorBanner(message: error) }
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            if viewModel.order != nil {
                let notViable = viewModel.result == .notViable
                PrimaryButton(text: buttonText, enabled: viewModel.result != nil, busy: viewModel.saving,
                              container: notViable ? AliviaColor.danger : AliviaColor.navy) {
                    viewModel.submit(onNext: onNext)
                }
                .padding(16)
                .background(AliviaColor.surface)
            }
        }
        .background(AliviaColor.background)
        .hidesNavigationBar()
        .task { await viewModel.load() }
        .alert("¿Marcar el hogar como no viable?", isPresented: $viewModel.confirmingRejection) {
            Button("Sí, rechazar", role: .destructive) { viewModel.submit(confirmed: true, onNext: onNext) }
            Button("Cancelar", role: .cancel) { viewModel.dismissRejection() }
        } message: {
            Text("La solicitud se cerrará y se liberará el pago retenido de la familia. Esta acción no se puede deshacer.")
        }
    }

    private var buttonText: String {
        switch viewModel.result {
        case nil: return "Elige un resultado"
        case .notViable: return "Rechazar y devolver el pago"
        default: return "Confirmar y continuar con la instalación"
        }
    }
}

private struct ResultOption: View {
    let value: EvaluationResult
    let selected: EvaluationResult?
    let icon: String
    let tint: Color
    let soft: Color
    let title: String
    let description: String
    let onSelect: (EvaluationResult) -> Void

    var body: some View {
        let isSelected = value == selected
        Button { onSelect(value) } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(soft).frame(width: 42, height: 42)
                    Image(systemName: icon).font(.system(size: 20)).foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.ink)
                    Text(description).font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? tint : AliviaColor.inkMuted)
            }
            .padding(14)
            .background(isSelected ? soft : AliviaColor.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? tint : AliviaColor.outline, lineWidth: isSelected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
