import Foundation

enum ProfilesModule {
    private static let repository: ProfileRepository = ProfileRepositoryImpl(
        facade: ProfileFacadeService(client: SharedModule.apiClient))

    static func getMyProfile() -> GetMyProfileUseCase { GetMyProfileUseCase(repository: repository) }
    static func updateMyProfile() -> UpdateMyProfileUseCase { UpdateMyProfileUseCase(repository: repository) }
}
