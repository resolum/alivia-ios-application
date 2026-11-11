import Observation
import SwiftUI

/// The backend password rules, checked as the user types.
enum PasswordRules {
    static let special = "@$!%*?&#"

    struct Check: Identifiable {
        let label: String
        let passed: Bool
        var id: String { label }
    }

    static func checks(_ password: String) -> [Check] {
        [
            Check(label: "8 caracteres como mínimo", passed: password.count >= 8),
            Check(label: "Al menos una mayúscula y una minúscula",
                  passed: password.contains(where: \.isUppercase) && password.contains(where: \.isLowercase)),
            Check(label: "Al menos un número", passed: password.contains(where: \.isNumber)),
            Check(label: "Al menos un símbolo (\(special))", passed: password.contains(where: { special.contains($0) })),
        ]
    }

    static func isValid(_ password: String) -> Bool {
        checks(password).allSatisfy(\.passed) && password.utf8.count <= 72
    }
}

nonisolated private struct ForgotPasswordRequest: Encodable { let email: String }
nonisolated private struct ResetPasswordRequest: Encodable { let email: String; let code: String; let password: String }

enum PasswordResetService {
    /// Always 202, whether or not the email has an account.
    static func sendCode(email: String) async -> NetworkResult<Void> {
        await BaseRepository.safeCall {
            try await SharedModule.apiClient.sendWithoutResponse("POST", "api/v1/auth/forgot-password",
                                                                 body: ForgotPasswordRequest(email: email))
        }
    }

    /// 204 when the password changed; 400 for a wrong, expired or exhausted code, or a weak password.
    static func reset(email: String, code: String, password: String) async -> NetworkResult<Void> {
        await BaseRepository.safeCall {
            try await SharedModule.apiClient.sendWithoutResponse("POST", "api/v1/auth/reset-password",
                                                                 body: ResetPasswordRequest(email: email, code: code, password: password))
        }
    }
}

enum RecoveryStep { case email, code, password, done }

/// Forgot-password flow: email, 6-digit code, new password and confirmation.
@Observable
final class PasswordRecoveryViewModel {
    static let invalidCode = "El código no es válido o ya venció. Revísalo o pide uno nuevo."

    var step: RecoveryStep = .email
    var email = "" { didSet { if oldValue != email { error = nil } } }
    var code = "" {
        didSet {
            let digits = String(code.filter(\.isNumber).prefix(6))
            if digits != code { code = digits }
        }
    }
    var password = ""
    var confirmation = ""
    var showPassword = false
    private(set) var busy = false
    private(set) var error: String?
    var notice: String?
    private(set) var resendSeconds = 0
    private var countdown: Task<Void, Never>?

    var maskedEmail: String {
        guard let at = email.firstIndex(of: "@"), email.distance(from: email.startIndex, to: at) > 1 else { return email }
        return "\(email.first!)***\(email[email.index(before: at)])\(email[at...])"
    }

    func submitEmail() async {
        let clean = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil else {
            error = "Escribe un correo electrónico válido."
            return
        }
        email = clean
        await send()
    }

    func resend() async {
        if resendSeconds == 0 { await send() }
    }

    private func send() async {
        guard !busy else { return }
        busy = true
        error = nil
        switch await PasswordResetService.sendCode(email: email) {
        case .success:
            step = .code
            code = ""
            notice = "Código enviado a tu correo"
            startCountdown()
        case .error(let message, _):
            error = message
        }
        busy = false
    }

    private func startCountdown() {
        countdown?.cancel()
        countdown = Task { @MainActor in
            for seconds in stride(from: 60, through: 0, by: -1) {
                resendSeconds = seconds
                if seconds > 0 { try? await Task.sleep(for: .seconds(1)) }
                if Task.isCancelled { return }
            }
        }
    }

    /// The backend checks the code together with the new password, so this step only collects it.
    func submitCode() {
        if code.count == 6 {
            error = nil
            step = .password
        } else {
            error = "Ingresa los 6 dígitos del código."
        }
    }

    var canChangePassword: Bool { PasswordRules.isValid(password) && password == confirmation && !busy }

    func submitPassword() async {
        guard canChangePassword else { return }
        busy = true
        error = nil
        switch await PasswordResetService.reset(email: email, code: code, password: password) {
        case .success:
            password = ""
            confirmation = ""
            step = .done
        case .error(_, 400):
            // A wrong code sends the user back to type it again.
            code = ""
            step = .code
            error = Self.invalidCode
        case .error(let message, _):
            error = message
        }
        busy = false
    }

    /// Back arrow: one step back, or false when the flow should close.
    func back() -> Bool {
        error = nil
        switch step {
        case .email, .done: return false
        case .code: step = .email
        case .password: step = .code
        }
        return true
    }
}

struct PasswordRecoveryView: View {
    let onClose: () -> Void
    @State private var viewModel = PasswordRecoveryViewModel()
    @FocusState private var codeFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if viewModel.step != .done {
                    Button { if !viewModel.back() { onClose() } } label: {
                        Image(systemName: "arrow.left").font(.system(size: 18, weight: .medium)).foregroundStyle(AliviaColor.navy)
                            .frame(width: 44, height: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Volver")
                }
                switch viewModel.step {
                case .email: emailStep
                case .code: codeStep
                case .password: passwordStep
                case .done: doneStep
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AliviaColor.background)
        .overlay(alignment: .bottom) {
            if let notice = viewModel.notice {
                HStack {
                    Label(notice, systemImage: "checkmark.circle").font(AliviaFont.bodySmall).foregroundStyle(.white)
                    Spacer()
                    Button("CERRAR") { viewModel.notice = nil }.font(AliviaFont.labelMedium).foregroundStyle(AliviaColor.teal)
                }
                .padding(14)
                .background(AliviaColor.navy, in: RoundedRectangle(cornerRadius: 12))
                .padding(16)
                .task {
                    try? await Task.sleep(for: .seconds(4))
                    viewModel.notice = nil
                }
            }
        }
    }

    private func title(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(AliviaFont.headlineSmall).foregroundStyle(AliviaColor.navy)
            Text(subtitle).font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.inkMuted)
        }
        .padding(.bottom, 16)
    }

    private func box<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 8) { content() }
            .font(AliviaFont.bodyLarge)
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(AliviaColor.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AliviaColor.outline, lineWidth: 1))
    }

    @ViewBuilder
    private var emailStep: some View {
        title("Recuperar contraseña", "Ingresa el correo asociado a tu cuenta para recibir un código de verificación de 6 dígitos.")
        Text("Correo electrónico").font(AliviaFont.labelMedium).foregroundStyle(AliviaColor.ink)
        box {
            TextField("correo@ejemplo.com", text: $viewModel.email).emailKeyboard().textContentType(.username)
        }
        if let error = viewModel.error { ErrorBanner(message: error).padding(.top, 8) }
        PrimaryButton(text: "Enviar código", enabled: !viewModel.email.isEmpty, busy: viewModel.busy, container: AliviaColor.navy) {
            Task { await viewModel.submitEmail() }
        }
        .padding(.top, 16)
        Button("Volver al inicio de sesión", action: onClose)
            .font(AliviaFont.labelLarge).foregroundStyle(AliviaColor.navy)
            .frame(maxWidth: .infinity).padding(.top, 12)
    }

    @ViewBuilder
    private var codeStep: some View {
        title("Verifica tu correo", "Hemos enviado un código a \(viewModel.maskedEmail)")
        Text("Código de 6 dígitos").font(AliviaFont.labelMedium).foregroundStyle(AliviaColor.ink)
        ZStack {
            TextField("", text: $viewModel.code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($codeFocused)
                .opacity(0.01)
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    let digits = Array(viewModel.code)
                    let active = index == digits.count
                    Text(index < digits.count ? String(digits[index]) : "")
                        .font(AliviaFont.titleLarge).foregroundStyle(AliviaColor.navy)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(AliviaColor.surface, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(active ? AliviaColor.navy : AliviaColor.outline, lineWidth: active ? 2 : 1))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { codeFocused = true }
        }
        .onAppear { codeFocused = true }
        Text("Revisa también la carpeta de spam.").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
        HStack {
            Text(viewModel.resendSeconds > 0 ? String(format: "Reenviar código en: 0:%02d", viewModel.resendSeconds) : "¿No te llegó?")
                .font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.ink)
            Spacer()
            Button("Reenviar código") { Task { await viewModel.resend() } }
                .font(AliviaFont.labelMedium)
                .disabled(viewModel.resendSeconds > 0 || viewModel.busy)
        }
        .padding(.top, 8)
        if let error = viewModel.error { ErrorBanner(message: error) }
        PrimaryButton(text: "Verificar", enabled: viewModel.code.count == 6, container: AliviaColor.navy) { viewModel.submitCode() }
            .padding(.top, 8)
    }

    @ViewBuilder
    private var passwordStep: some View {
        title("Nueva contraseña", "Crea una contraseña segura para tu cuenta")
        passwordField("Nueva contraseña", $viewModel.password)
        VStack(alignment: .leading, spacing: 6) {
            Text("REQUISITOS DE SEGURIDAD").font(AliviaFont.labelSmall).foregroundStyle(AliviaColor.navy)
            ForEach(PasswordRules.checks(viewModel.password)) { check in
                Label(check.label, systemImage: check.passed ? "checkmark.circle" : "circle")
                    .font(AliviaFont.bodySmall)
                    .foregroundStyle(check.passed ? AliviaColor.tealDark : AliviaColor.inkMuted)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AliviaColor.tealSoft.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
        passwordField("Confirmar contraseña", $viewModel.confirmation)
        if !viewModel.confirmation.isEmpty && viewModel.confirmation != viewModel.password {
            Text("Las contraseñas no coinciden.").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.danger)
        }
        if let error = viewModel.error { ErrorBanner(message: error) }
        PrimaryButton(text: "Cambiar contraseña", enabled: viewModel.canChangePassword, busy: viewModel.busy,
                      container: AliviaColor.navy) {
            Task { await viewModel.submitPassword() }
        }
        .padding(.top, 8)
    }

    private func passwordField(_ label: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(AliviaFont.labelMedium).foregroundStyle(AliviaColor.ink)
            box {
                Group {
                    if viewModel.showPassword { TextField("", text: text) } else { SecureField("", text: text) }
                }
                .textContentType(.newPassword)
                .plainTextKeyboard()
                Button { viewModel.showPassword.toggle() } label: {
                    Image(systemName: viewModel.showPassword ? "eye.slash" : "eye").foregroundStyle(AliviaColor.inkMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.showPassword ? "Ocultar contraseña" : "Mostrar contraseña")
            }
        }
    }

    private var doneStep: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark").font(.system(size: 26, weight: .semibold)).foregroundStyle(AliviaColor.tealDark)
                .frame(width: 64, height: 64).background(AliviaColor.tealSoft, in: Circle())
            Text("Contraseña actualizada").font(AliviaFont.headlineSmall).foregroundStyle(AliviaColor.navy)
            Text("Tu contraseña ha sido restablecida exitosamente. Ya puedes ingresar con tus nuevas credenciales.")
                .font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.inkMuted).multilineTextAlignment(.center)
            PrimaryButton(text: "Volver a iniciar sesión", container: AliviaColor.navy, action: onClose).padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 160)
    }
}
