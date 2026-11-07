import Foundation

protocol ProfileRepository: AnyObject {
    func me() async -> NetworkResult<UserProfile>
    func update(_ changes: ProfileChanges) async -> NetworkResult<UserProfile>
}
