import SwiftUI

/// Form to register whether the dose was given or omitted, and when.
struct MedicationOutcomeSheet: View {
    @Bindable var viewModel: MedicationDetailViewModel
    let administration: MedicationAdministration

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Registrar resultado").font(AliviaFont.headlineSmall).foregroundStyle(AliviaColor.navy)
                Text("\(administration.medication) · \(administration.assistedPerson)")
                    .font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.inkMuted)
                resultPicker
                SectionLabel(text: "Hora real")
                DatePicker("Hora real", selection: $viewModel.occurredAt, in: ...Date(),
                           displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .environment(\.locale, Formats.locale)
                    .environment(\.timeZone, LocalDate.zone)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if viewModel.result == .omitted {
                    SectionLabel(text: "Motivo (obligatorio)")
                    field("¿Por qué se omitió?", text: $viewModel.reason)
                }
                SectionLabel(text: "Notas (opcional)")
                field("Observaciones sobre la administración", text: $viewModel.notes)
                if let error = viewModel.recordError { ErrorBanner(message: error) }
                PrimaryButton(text: "Confirmar", icon: "checkmark", enabled: viewModel.canSubmit, busy: viewModel.saving,
                              container: AliviaColor.navy) {
                    Task { await viewModel.submit() }
                }
                SecondaryButton(text: "Cancelar", container: AliviaColor.surfaceMuted, enabled: !viewModel.saving) {
                    viewModel.recording = false
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 8)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AliviaColor.surface)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(viewModel.saving)
    }

    private var resultPicker: some View {
        HStack(spacing: 4) {
            option(.administered, "Administrado", "checkmark.circle")
            option(.omitted, "Omitido", "xmark.circle")
        }
        .padding(4)
        .background(AliviaColor.navySoft, in: RoundedRectangle(cornerRadius: 14))
    }

    private func option(_ value: AdministrationResult, _ label: String, _ icon: String) -> some View {
        let selected = viewModel.result == value
        return Button { viewModel.result = value } label: {
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
        .disabled(viewModel.saving)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(placeholder, text: text, axis: .vertical)
                .lineLimit(3...6)
                .font(AliviaFont.bodyLarge)
                .padding(12)
                .frame(minHeight: 80, alignment: .topLeading)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AliviaColor.outline, lineWidth: 1))
            Text("\(text.wrappedValue.count)/\(MedicationDetailViewModel.maxText)")
                .font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted).padding(.leading, 16)
        }
    }
}
