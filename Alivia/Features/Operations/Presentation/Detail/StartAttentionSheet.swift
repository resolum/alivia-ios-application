import SwiftUI

/// Confirms the start of the visit before the order moves to In progress, as the design asks.
struct StartAttentionSheet: View {
    let order: TechnicalOrder
    let starting: Bool
    let error: String?
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18).fill(AliviaColor.navySoft).frame(width: 64, height: 64)
                    Image(systemName: "wrench.and.screwdriver").font(.system(size: 26)).foregroundStyle(AliviaColor.navy)
                }
                Text("¿Iniciar atención?").font(AliviaFont.headlineSmall).foregroundStyle(AliviaColor.navy)
                Text("Confirma el inicio de la visita técnica presencial").font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.inkMuted)
                VStack(spacing: 0) {
                    row("Código de orden") { Text(order.code).font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.ink) }
                    Divider().overlay(AliviaColor.outline)
                    row("Tipo de servicio") {
                        HStack(spacing: 6) {
                            Dot(color: order.serviceType.color, size: 8)
                            Text(order.serviceType.longLabel).font(AliviaFont.titleSmall).foregroundStyle(order.serviceType.color)
                        }
                    }
                    Divider().overlay(AliviaColor.outline)
                    row("Hogar beneficiario") { Text(order.homeName).font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.ink) }
                    Divider().overlay(AliviaColor.outline)
                    row("Horario programado") {
                        Text(Formats.window(order.startTime, order.endTime) + (order.date == Formats.today() ? " (Hoy)" : ""))
                            .font(AliviaFont.titleSmall).foregroundStyle(AliviaColor.ink)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(AliviaColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AliviaColor.outline, lineWidth: 1))
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle").font(.system(size: 16)).foregroundStyle(AliviaColor.inkMuted)
                    Text("La orden cambiará al estado \(Text("En proceso").bold().foregroundStyle(AliviaColor.ink)) y se registrará la hora exacta de inicio para trazabilidad asistencial.")
                        .font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
                }
                if let error { ErrorBanner(message: error) }
                PrimaryButton(text: "Iniciar atención", icon: "play.fill", busy: starting, container: AliviaColor.navy, action: onConfirm)
                SecondaryButton(text: "Cancelar", container: AliviaColor.surfaceMuted, enabled: !starting, action: onDismiss)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 8)
        }
        .background(AliviaColor.surface)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(starting)
    }

    private func row<Value: View>(_ label: String, @ViewBuilder value: () -> Value) -> some View {
        HStack {
            Text(label).font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.inkMuted)
            Spacer()
            value()
        }
        .padding(.vertical, 12)
    }
}
