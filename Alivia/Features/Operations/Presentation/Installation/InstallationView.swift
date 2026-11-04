import SwiftUI

struct InstallationView: View {
    let onExit: () -> Void
    let onCompleted: (Int64) -> Void
    @State private var viewModel: InstallationViewModel

    init(orderId: Int64, onExit: @escaping () -> Void, onCompleted: @escaping (Int64) -> Void) {
        self.onExit = onExit
        self.onCompleted = onCompleted
        _viewModel = State(initialValue: InstallationViewModel(
            orderId: orderId, getOrder: OperationsModule.getOrder(), registerDevice: OperationsModule.registerDevice(),
            removeDevice: OperationsModule.removeDevice(), completeInstallation: OperationsModule.completeInstallation()))
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailTopBar(title: viewModel.step.screenTitle, subtitle: "Paso \(viewModel.step.number) · Instalación",
                         subtitleColor: AliviaColor.tealDark, onBack: { if !viewModel.back() { onExit() } }) {
                Button(action: onExit) {
                    Image(systemName: "xmark").font(.system(size: 18)).foregroundStyle(AliviaColor.ink).frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cerrar")
            }
            if let order = viewModel.order {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        StepProgress(step: viewModel.step, code: order.code)
                        switch viewModel.step {
                        case .home: HomeStep(order: order)
                        case .devices: DevicesStep(viewModel: viewModel, order: order)
                        case .tests: TestsStep(viewModel: viewModel, order: order)
                        case .closing: ClosingStep(viewModel: viewModel, order: order)
                        }
                        if let error = viewModel.error { ErrorBanner(message: error) }
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
                bottomActions(order)
                    .padding(16)
                    .background(AliviaColor.surface)
            } else if let loadError = viewModel.loadError {
                ErrorBanner(message: loadError).padding(16)
                Spacer()
            } else {
                LoadingView()
                Spacer()
            }
        }
        .background(AliviaColor.background)
        .hidesNavigationBar()
        .navigationBarBackButtonHidden(true)
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private func bottomActions(_ order: TechnicalOrder) -> some View {
        VStack(spacing: 10) {
            switch viewModel.step {
            case .home:
                PrimaryButton(text: "Confirmar hogar y continuar", container: AliviaColor.navy) { viewModel.goTo(.devices) }
            case .devices:
                PrimaryButton(text: "Registrar dispositivo", icon: "plus.circle", enabled: viewModel.canRegister,
                              busy: viewModel.busy, container: AliviaColor.navy) { viewModel.register() }
                SecondaryButton(text: order.installedDevices.isEmpty ? "Omitir por ahora y continuar" : "Continuar a pruebas") {
                    viewModel.goTo(.tests)
                }
            case .tests:
                PrimaryButton(text: viewModel.allTested ? "Continuar al cierre" : "Marca cada dispositivo probado",
                              enabled: viewModel.allTested, container: AliviaColor.navy) { viewModel.goTo(.closing) }
            case .closing:
                PrimaryButton(text: "Finalizar instalación", enabled: viewModel.result != nil, busy: viewModel.busy,
                              container: viewModel.result == .rejected ? AliviaColor.danger : AliviaColor.navy) {
                    viewModel.finish(onCompleted: onCompleted)
                }
            }
        }
    }
}

private struct StepProgress: View {
    let step: InstallationStep
    let code: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3").font(.system(size: 15)).foregroundStyle(AliviaColor.tealDark)
                Text("Paso \(step.number) de 4: \(step.title)").font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.tealDark)
                Spacer()
                Pill(text: code, container: AliviaColor.navy, content: .white)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(AliviaColor.surface)
                    Capsule().fill(AliviaColor.installation).frame(width: proxy.size.width * CGFloat(step.number) / 4)
                }
            }
            .frame(height: 6)
            HStack {
                Text("Hardware IoT").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.ink)
                Spacer()
                Text("\(step.number * 25)% completado").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.tealDark)
            }
        }
        .padding(14)
        .background(AliviaColor.navySoft, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AliviaColor.outline, lineWidth: 1))
    }
}

private struct HomeCard: View {
    let order: TechnicalOrder
    let verified: Bool

    var body: some View {
        AliviaCard {
            HStack(spacing: 8) {
                Image(systemName: "house").font(.system(size: 17)).foregroundStyle(AliviaColor.navy)
                Text("Hogar asignado").font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.ink)
                Spacer()
                if verified { Pill(text: "Verificado", container: AliviaColor.tealSoft, content: AliviaColor.tealDark) }
            }
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(AliviaColor.navySoft).frame(width: 40, height: 40)
                    Image(systemName: "mappin.and.ellipse").foregroundStyle(AliviaColor.navy)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(order.homeName).font(AliviaFont.titleMedium).foregroundStyle(AliviaColor.navy)
                    Text(order.directions ?? "Sin indicaciones registradas").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.ink)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(AliviaColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct HomeStep: View {
    let order: TechnicalOrder

    var body: some View {
        HomeCard(order: order, verified: false)
        AliviaCard {
            Text("Antes de instalar").font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.navy)
            ForEach([
                "Confirma con la familia los ambientes donde irán los dispositivos.",
                "Verifica que haya red Wi-Fi y tomacorrientes cerca de cada punto.",
                "Ten a mano la etiqueta con la dirección MAC de cada dispositivo.",
            ], id: \.self) { line in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle").font(.system(size: 16)).foregroundStyle(AliviaColor.tealDark)
                    Text(line).font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.ink)
                }
            }
        }
    }
}

private struct DevicesStep: View {
    let viewModel: InstallationViewModel
    let order: TechnicalOrder

    var body: some View {
        HomeCard(order: order, verified: true)
        HStack(spacing: 6) {
            Image(systemName: "info.circle").font(.system(size: 14)).foregroundStyle(AliviaColor.inkMuted)
            Text("Todos los campos marcados con (*) son obligatorios").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
        }
        AliviaCard {
            FieldTitle(title: "1. Alias del dispositivo", hint: "Identificador único")
            FilledField(icon: "tag") {
                TextField("Micrófono Cabecera", text: Binding(get: { viewModel.form.alias }, set: { viewModel.updateAlias($0) }))
                    .sentenceKeyboard()
            }
            Text("Asigna un nombre descriptivo para la ubicación física del paciente.").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.ink)
        }
        AliviaCard {
            FieldTitle(title: "2. Dirección MAC", hint: nil)
            FilledField(icon: "wifi.router") {
                TextField("00:1A:2B:3C:4D:5E", text: Binding(get: { viewModel.form.macAddress }, set: { viewModel.updateMac($0) }))
                    .font(.system(size: 16, design: .monospaced))
                    .uppercaseKeyboard()
                if !viewModel.form.macAddress.isEmpty {
                    Button { viewModel.clearMac() } label: {
                        Image(systemName: "xmark.circle").foregroundStyle(AliviaColor.ink)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Borrar")
                }
            }
            if viewModel.form.macComplete && viewModel.form.macValid {
                Notice(icon: "checkmark.seal", tint: AliviaColor.tealDark, container: AliviaColor.navySoft,
                       title: "Formato válido de 12 dígitos", detail: "Hexadecimales en mayúsculas separados por pares con dos puntos (:).")
                if viewModel.duplicateMac {
                    Notice(icon: "exclamationmark.triangle", tint: AliviaColor.danger, container: AliviaColor.dangerSoft,
                           title: "Este dispositivo ya está registrado en la orden actual.", detail: nil)
                } else {
                    Notice(icon: "checkmark.circle", tint: AliviaColor.tealDark, container: AliviaColor.tealSoft,
                           title: "Verificación: no se detectan duplicidades en la orden actual.", detail: nil)
                }
            } else {
                Text("Escribe los 12 dígitos; los dos puntos se agregan solos.").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
            }
        }
        AliviaCard {
            FieldTitle(title: "3. Tipo de dispositivo", hint: nil)
            Menu {
                ForEach(DeviceType.allCases, id: \.self) { type in
                    Button { viewModel.updateType(type) } label: { Label(type.label, systemImage: deviceIcon(type)) }
                }
            } label: {
                FilledField(icon: deviceIcon(viewModel.form.type), iconTint: AliviaColor.tealDark) {
                    Text(viewModel.form.type?.label ?? "Elige el tipo")
                        .foregroundStyle(viewModel.form.type == nil ? AliviaColor.inkMuted : AliviaColor.ink)
                    Spacer()
                    Image(systemName: "chevron.down").foregroundStyle(AliviaColor.inkMuted)
                }
            }
            .buttonStyle(.plain)
            Text("Categoría del módulo de asistencia para mapeo en el hub central.").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.ink)
        }
        if !order.installedDevices.isEmpty {
            AliviaCard {
                Text("Registrados en esta orden (\(order.installedDevices.count))").font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.navy)
                ForEach(Array(order.installedDevices.enumerated()), id: \.element.macAddress) { index, device in
                    if index > 0 { Divider().overlay(AliviaColor.outline) }
                    HStack(spacing: 10) {
                        Image(systemName: deviceIcon(device.type)).foregroundStyle(AliviaColor.tealDark)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.alias).font(AliviaFont.bodyLarge).foregroundStyle(AliviaColor.ink)
                            Text("\(device.type.label) · \(device.macAddress)").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
                        }
                        Spacer()
                        Button { viewModel.remove(device.macAddress) } label: {
                            Image(systemName: "trash").foregroundStyle(AliviaColor.danger).frame(width: 40, height: 40)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.busy)
                        .accessibilityLabel("Quitar \(device.alias)")
                    }
                }
            }
        }
    }
}

private struct TestsStep: View {
    let viewModel: InstallationViewModel
    let order: TechnicalOrder

    var body: some View {
        AliviaCard {
            Text("Prueba cada dispositivo").font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.navy)
            Text("Verifica que encienda, se conecte al hub y responda antes de marcarlo.").font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.ink)
            ForEach(order.installedDevices, id: \.macAddress) { device in
                let checked = viewModel.tested.contains(device.macAddress)
                Button { viewModel.toggleTested(device.macAddress) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: checked ? "checkmark.square.fill" : "square")
                            .font(.system(size: 22))
                            .foregroundStyle(checked ? AliviaColor.installation : AliviaColor.inkMuted)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.alias).font(AliviaFont.bodyLarge).foregroundStyle(AliviaColor.ink)
                            Text("\(device.type.label) · \(device.macAddress)").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
                        }
                        Spacer()
                        Image(systemName: deviceIcon(device.type)).foregroundStyle(AliviaColor.tealDark)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AliviaColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(checked ? .isSelected : [])
            }
        }
    }
}

private struct ClosingStep: View {
    let viewModel: InstallationViewModel
    let order: TechnicalOrder

    var body: some View {
        AliviaCard {
            Text("Resultado de la instalación").font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.navy)
            Text(order.installedDevices.isEmpty
                 ? "Sin dispositivos registrados. Podrás completar este paso posteriormente desde la aplicación web."
                 : "\(order.installedDevices.count) dispositivos registrados y probados.")
                .font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.ink)
            ResultRow(title: "Aprobada", description: "El hogar queda en servicio y la familia ya puede usar Alivia.",
                      selected: viewModel.result == .approved, tint: AliviaColor.installation) { viewModel.selectResult(.approved) }
            ResultRow(title: "Rechazada", description: "La instalación no se pudo completar; la central reprogramará la visita.",
                      selected: viewModel.result == .rejected, tint: AliviaColor.danger) { viewModel.selectResult(.rejected) }
        }
        AliviaCard {
            Text("Notas").font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.navy)
            VStack(alignment: .leading, spacing: 4) {
                TextField("Observaciones del cierre (opcional)",
                          text: Binding(get: { viewModel.notes }, set: { viewModel.updateNotes($0) }), axis: .vertical)
                    .lineLimit(4...10)
                    .font(AliviaFont.bodyLarge)
                    .padding(12)
                    .frame(minHeight: 110, alignment: .topLeading)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AliviaColor.outline, lineWidth: 1))
                Text("\(viewModel.notes.count)/300").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted).padding(.leading, 16)
            }
        }
    }
}

private struct ResultRow: View {
    let title: String
    let description: String
    let selected: Bool
    let tint: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 22)).foregroundStyle(selected ? tint : AliviaColor.inkMuted)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.ink)
                    Text(description).font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(selected ? AliviaColor.surfaceMuted : AliviaColor.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? tint : AliviaColor.outline, lineWidth: selected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct FieldTitle: View {
    let title: String
    let hint: String?

    var body: some View {
        HStack(spacing: 0) {
            Text(title).font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.ink)
            Text(" *").font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.danger)
            Spacer()
            if let hint { Text(hint).font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted) }
        }
    }
}

private struct FilledField<Content: View>: View {
    let icon: String
    var iconTint: Color = AliviaColor.inkMuted
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(iconTint)
            content
        }
        .font(AliviaFont.bodyLarge)
        .foregroundStyle(AliviaColor.ink)
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .background(AliviaColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct Notice: View {
    let icon: String
    let tint: Color
    let container: Color
    let title: String
    let detail: String?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AliviaFont.labelMedium).foregroundStyle(tint == AliviaColor.danger ? AliviaColor.danger : AliviaColor.ink)
                if let detail { Text(detail).font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.ink) }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(container, in: RoundedRectangle(cornerRadius: 12))
    }
}
