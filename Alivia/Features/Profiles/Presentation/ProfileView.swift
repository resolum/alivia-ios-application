import PhotosUI
import SwiftUI

struct ProfileView: View {
    let session: Session
    let onSignOut: () -> Void
    @State private var viewModel = ProfileViewModel(getProfile: ProfilesModule.getMyProfile(),
                                                    updateProfile: ProfilesModule.updateMyProfile())
    @State private var pickedPhoto: PhotosPickerItem?

    private var roleLabel: String { session.role == .technician ? "Técnico" : "Cuidador" }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Perfil", subtitle: session.email, onOpenProfile: {})
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.loading {
                        LoadingView()
                    } else if let profile = viewModel.profile {
                        header(profile)
                        if let photoError = viewModel.photoError { ErrorBanner(message: photoError) }
                        personalInformation(profile)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ErrorBanner(message: viewModel.error ?? "No pudimos cargar tu perfil.")
                            Button("Reintentar") { Task { await viewModel.load() } }.foregroundStyle(AliviaColor.navyButton)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    signOutButton
                }
                .padding(16)
            }
            .refreshable { await viewModel.load() }
        }
        .background(AliviaColor.background)
        .task { await viewModel.load() }
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await viewModel.uploadPhoto(data)
                } else {
                    viewModel.photoPickFailed()
                }
                pickedPhoto = nil
            }
        }
        .sheet(isPresented: $viewModel.editing) { EditProfileSheet(viewModel: viewModel) }
    }

    private func header(_ profile: UserProfile) -> some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Avatar(profile: profile).frame(width: 104, height: 104)
                    .overlay { if viewModel.uploadingPhoto { Circle().fill(.black.opacity(0.35)); ProgressView().tint(.white) } }
                PhotosPicker(selection: $pickedPhoto, matching: .images) {
                    Image(systemName: "camera.fill").font(.system(size: 14)).foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(AliviaColor.navy, in: Circle())
                        .overlay(Circle().stroke(AliviaColor.background, lineWidth: 3))
                }
                .disabled(viewModel.uploadingPhoto)
                .accessibilityLabel("Cambiar foto")
            }
            Text(profile.fullName).font(AliviaFont.headlineSmall).foregroundStyle(AliviaColor.navy).multilineTextAlignment(.center)
            Pill(text: roleLabel, container: AliviaColor.tealSoft, content: AliviaColor.tealDark)
        }
        .frame(maxWidth: .infinity)
    }

    private func personalInformation(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(text: "Información personal")
                Button { viewModel.startEditing() } label: {
                    Label("Editar", systemImage: "pencil").font(AliviaFont.labelMedium).foregroundStyle(AliviaColor.navyButton)
                }
                .buttonStyle(.plain)
            }
            AliviaCard {
                row("person", "Nombres", profile.firstName)
                row("person", "Apellidos", profile.lastName)
                row("creditcard", "DNI", profile.dni ?? "—")
                row("phone", "Teléfono", profile.phoneNumber.map { "+\($0)" } ?? "—")
                row("envelope", "Correo", profile.email)
            }
        }
    }

    private func row(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(AliviaColor.inkMuted).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
                Text(value).font(AliviaFont.bodyLarge).foregroundStyle(AliviaColor.ink)
            }
        }
    }

    private var signOutButton: some View {
        Button(action: onSignOut) {
            Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                .font(AliviaFont.labelLarge)
                .foregroundStyle(AliviaColor.navyButton)
                .padding(.horizontal, 24)
                .frame(height: 44)
                .overlay(Capsule().stroke(AliviaColor.outline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }
}

private struct Avatar: View {
    let profile: UserProfile

    var body: some View {
        Group {
            if let url = profile.photoURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { initials }
                }
            } else {
                initials
            }
        }
        .clipShape(Circle())
        .overlay(Circle().stroke(AliviaColor.outline, lineWidth: 1))
    }

    private var initials: some View {
        ZStack {
            AliviaColor.navySoft
            Text(profile.initials).font(.system(size: 36, weight: .bold)).foregroundStyle(AliviaColor.navy)
        }
    }
}

private struct EditProfileSheet: View {
    @Bindable var viewModel: ProfileViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Editar información").font(AliviaFont.headlineSmall).foregroundStyle(AliviaColor.navy)
                Text("El correo, el DNI y la fecha de nacimiento no se pueden cambiar.")
                    .font(AliviaFont.bodyMedium).foregroundStyle(AliviaColor.inkMuted)
                field("Nombres", "Tus nombres", $viewModel.firstName, .givenName)
                field("Apellidos", "Tus apellidos", $viewModel.lastName, .familyName)
                field("Teléfono", "51987654321", $viewModel.phone, .telephoneNumber, keyboard: .numberPad)
                if let error = viewModel.saveError { ErrorBanner(message: error) }
                PrimaryButton(text: "Guardar", icon: "checkmark", enabled: viewModel.canSave, busy: viewModel.saving,
                              container: AliviaColor.navy) {
                    Task { await viewModel.save() }
                }
                SecondaryButton(text: "Cancelar", container: AliviaColor.surfaceMuted, enabled: !viewModel.saving) {
                    viewModel.editing = false
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

    private func field(_ label: String, _ placeholder: String, _ text: Binding<String>, _ content: UITextContentType,
                       keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: label)
            TextField(placeholder, text: text)
                .textContentType(content)
                .keyboardType(keyboard)
                .font(AliviaFont.bodyLarge)
                .padding(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AliviaColor.outline, lineWidth: 1))
        }
    }
}
