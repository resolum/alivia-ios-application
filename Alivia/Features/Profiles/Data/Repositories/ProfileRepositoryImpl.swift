import Foundation

final class ProfileRepositoryImpl: ProfileRepository {
    private let facade: ProfileFacadeService

    init(facade: ProfileFacadeService) {
        self.facade = facade
    }

    func me() async -> NetworkResult<UserProfile> {
        await BaseRepository.safeCall { ProfileMapper.toDomain(try await facade.me()) }
    }

    func update(_ changes: ProfileChanges) async -> NetworkResult<UserProfile> {
        await BaseRepository.safeCall { ProfileMapper.toDomain(try await facade.update(changes)) }
    }
}
