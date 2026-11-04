import SwiftUI

/// Sign-in for technicians and caregivers; other roles are told to use the web.
struct LoginView: View {
    let onSignedIn: (Session) -> Void
    @State private var viewModel = LoginViewModel(signIn: AuthModule.signInUseCase())
    @FocusState private var focus: Field?

    private enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                AliviaLogo(markSize: 26, textSize: 20)
                Spacer().frame(height: 28)
                Text("Bienvenido a Alivia").font(AliviaFont.headlineSmall).foregroundStyle(AliviaColor.navy)
                Text("Ingresa para continuar").font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.inkMuted)
                Spacer().frame(height: 20)

                Text("Correo electrónico").font(AliviaFont.labelMedium).foregroundStyle(AliviaColor.ink)
                field {
                    TextField("tecnico@alivia.pe", text: $viewModel.email)
                        .textContentType(.username)
                        .emailKeyboard()
                        .submitLabel(.next)
                        .focused($focus, equals: .email)
                        .onSubmit { focus = .password }
                    Image(systemName: "envelope").foregroundStyle(AliviaColor.inkMuted)
                }
                Text("Ingresa el correo institucional o de cuidador").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
                Spacer().frame(height: 12)

                Text("Contraseña").font(AliviaFont.labelMedium).foregroundStyle(AliviaColor.ink)
                field {
                    Group {
                        if viewModel.showPassword {
                            TextField("", text: $viewModel.password)
                        } else {
                            SecureField("", text: $viewModel.password)
                        }
                    }
                    .textContentType(.password)
                    .plainTextKeyboard()
                    .submitLabel(.done)
                    .focused($focus, equals: .password)
                    .onSubmit { viewModel.submit(onSignedIn: onSignedIn) }
                    Button { viewModel.showPassword.toggle() } label: {
                        Image(systemName: viewModel.showPassword ? "eye.slash" : "eye").foregroundStyle(AliviaColor.inkMuted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(viewModel.showPassword ? "Ocultar contraseña" : "Mostrar contraseña")
                }
                Spacer().frame(height: 16)
                if let error = viewModel.error { ErrorBanner(message: error) }
                Spacer().frame(height: 8)
                PrimaryButton(text: "Ingresar", enabled: viewModel.canSubmit, busy: viewModel.loading, container: AliviaColor.navy) {
                    focus = nil
                    viewModel.submit(onSignedIn: onSignedIn)
                }
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AliviaColor.background)
        .onChange(of: viewModel.email) { viewModel.clearError() }
        .onChange(of: viewModel.password) { viewModel.clearError() }
    }

    private func field<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 8) { content() }
            .font(AliviaFont.bodyLarge)
            .foregroundStyle(AliviaColor.ink)
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .background(AliviaColor.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AliviaColor.outline, lineWidth: 1))
    }
}
