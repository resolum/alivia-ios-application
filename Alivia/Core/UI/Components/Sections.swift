import SwiftUI

struct SectionLabel: View {
    let text: String
    var color: Color = AliviaColor.inkMuted

    var body: some View {
        Text(text.uppercased(with: Formats.locale))
            .font(AliviaFont.labelSmall)
            .tracking(0.6)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// White rounded card with a hairline border, as the designs use for every block.
struct AliviaCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AliviaColor.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(AliviaColor.outline, lineWidth: 1))
    }
}

/// Full-width navy action with an optional leading icon and a busy state.
struct PrimaryButton: View {
    let text: String
    var icon: String? = nil
    var enabled: Bool = true
    var busy: Bool = false
    var container: Color = AliviaColor.navyButton
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if busy {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 10) {
                        if let icon { Image(systemName: icon) }
                        Text(text).font(AliviaFont.labelLarge)
                    }
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(enabled && !busy ? container : container.opacity(0.38), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(!enabled || busy)
    }
}

/// Soft navy action used for secondary choices ("Cancelar", "Continuar a pruebas").
struct SecondaryButton: View {
    let text: String
    var container: Color = AliviaColor.navySoft
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(AliviaFont.labelLarge)
                .foregroundStyle(AliviaColor.navy)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(container, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(AliviaFont.bodyMedium)
            .foregroundStyle(AliviaColor.danger)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AliviaColor.dangerSoft, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct LoadingView: View {
    var body: some View {
        ProgressView()
            .tint(AliviaColor.navy)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .padding(48)
    }
}

/// Placeholder for the sections that are not built yet.
struct ComingSoonView: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(AliviaColor.navySoft).frame(width: 80, height: 80)
                Image(systemName: icon).font(.system(size: 32)).foregroundStyle(AliviaColor.navy)
            }
            Text(title).font(AliviaFont.titleLarge).foregroundStyle(AliviaColor.navy).multilineTextAlignment(.center)
            Text(description).font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.inkMuted).multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Title of a main tab with the profile shortcut on the right.
struct ScreenHeader: View {
    let title: String
    var subtitle: String? = nil
    var overline: String? = nil
    let onOpenProfile: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                if let overline {
                    Text(overline.uppercased(with: Formats.locale)).font(AliviaFont.labelSmall).tracking(0.6)
                        .foregroundStyle(AliviaColor.inkMuted)
                }
                Text(title).font(AliviaFont.headlineSmall).foregroundStyle(AliviaColor.navy)
                if let subtitle { Text(subtitle).font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted) }
            }
            Spacer()
            Button(action: onOpenProfile) {
                Image(systemName: "person")
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(AliviaColor.navy, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Perfil")
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.vertical, 12)
    }
}

/// Top bar of the screens pushed over the tabs, with the back action.
struct DetailTopBar<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var subtitleColor: Color = AliviaColor.inkMuted
    let onBack: () -> Void
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onBack) {
                Image(systemName: "arrow.left").font(.system(size: 20)).foregroundStyle(AliviaColor.ink).frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Volver")
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AliviaFont.titleLarge).foregroundStyle(AliviaColor.navy)
                if let subtitle { Text(subtitle).font(AliviaFont.bodySmall).foregroundStyle(subtitleColor) }
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(AliviaColor.surface)
    }
}

extension DetailTopBar where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, onBack: @escaping () -> Void) {
        self.init(title: title, subtitle: subtitle, onBack: onBack) { EmptyView() }
    }
}
