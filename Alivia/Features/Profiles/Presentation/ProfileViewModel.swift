import Foundation
import Observation
import UIKit

@Observable
final class ProfileViewModel {
    private(set) var loading = true
    private(set) var profile: UserProfile?
    private(set) var error: String?

    var editing = false
    var firstName = "" { didSet { saveError = nil } }
    var lastName = "" { didSet { saveError = nil } }
    var phone = "" { didSet { saveError = nil } }
    private(set) var saving = false
    private(set) var saveError: String?

    private(set) var uploadingPhoto = false
    private(set) var photoError: String?

    private let getProfile: GetMyProfileUseCase
    private let updateProfile: UpdateMyProfileUseCase

    init(getProfile: GetMyProfileUseCase, updateProfile: UpdateMyProfileUseCase) {
        self.getProfile = getProfile
        self.updateProfile = updateProfile
    }

    var canSave: Bool {
        !saving && !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func load() async {
        loading = profile == nil
        error = nil
        switch await getProfile() {
        case .success(let data): profile = data
        case .error(let message, _):
            // A failed reload must not hide the profile already on screen.
            if profile == nil { error = message }
        }
        loading = false
    }

    func startEditing() {
        guard let profile else { return }
        firstName = profile.firstName
        lastName = profile.lastName
        phone = profile.phoneNumber ?? ""
        saveError = nil
        editing = true
    }

    func save() async {
        guard let profile, canSave else { return }
        saving = true
        saveError = nil
        switch await updateProfile(current: profile, firstName: firstName, lastName: lastName, phone: phone) {
        case .success(let data):
            self.profile = data
            editing = false
        case .error(let message, _):
            saveError = message
        }
        saving = false
    }

    /// Compresses the picked image to JPEG and sends it; on failure the profile stays as it was.
    func uploadPhoto(_ imageData: Data) async {
        guard !uploadingPhoto else { return }
        uploadingPhoto = true
        photoError = nil
        guard let jpeg = Self.compressed(imageData) else {
            photoError = "No pudimos leer esa imagen. Elige otra."
            uploadingPhoto = false
            return
        }
        switch await updateProfile(photo: jpeg) {
        case .success(let data): profile = data
        case .error(let message, _): photoError = message
        }
        uploadingPhoto = false
    }

    func photoPickFailed() {
        photoError = "No pudimos abrir esa imagen. Elige otra."
    }

    /// JPEG of at most 1024 px on the long side, enough for an avatar.
    private static func compressed(_ data: Data, maxSide: CGFloat = 1024) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longSide = max(image.size.width, image.size.height)
        let scale = longSide > maxSide ? maxSide / longSide : 1
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }
}
