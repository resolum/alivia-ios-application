import Foundation

/// Profile as `/api/v1/profiles/me` returns it.
struct ProfileDto: Decodable {
    var emailAddress: String?
    var photoUrl: String?
    var phoneNumber: String?
    var firstName: String?
    var lastName: String?
    var dni: String?
    var birthDate: String?
}

enum ProfileMapper {
    static func toDomain(_ dto: ProfileDto) -> UserProfile {
        UserProfile(
            firstName: dto.firstName ?? "",
            lastName: dto.lastName ?? "",
            email: dto.emailAddress ?? "",
            phoneNumber: nonBlank(dto.phoneNumber),
            dni: nonBlank(dto.dni),
            birthDate: LocalDate(iso: dto.birthDate),
            photoURL: nonBlank(dto.photoUrl).flatMap { URL(string: $0) })
    }

    private static func nonBlank(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

final class ProfileFacadeService {
    private let client: APIClient
    init(client: APIClient) { self.client = client }

    func me() async throws -> ProfileDto { try await client.send("GET", "api/v1/profiles/me") }

    func update(_ changes: ProfileChanges) async throws -> ProfileDto {
        var form = MultipartForm()
        if let firstName = changes.firstName { form.fields["firstName"] = firstName }
        if let lastName = changes.lastName { form.fields["lastName"] = lastName }
        if let phoneNumber = changes.phoneNumber { form.fields["phoneNumber"] = phoneNumber }
        if let photo = changes.photo {
            form.file = MultipartForm.File(field: "photo", filename: "photo.jpg", mimeType: "image/jpeg", data: photo)
        }
        return try await client.sendMultipart("PATCH", "api/v1/profiles/me", form: form)
    }
}
