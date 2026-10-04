//
//  UserService.swift
//  AstroAI
//

import Foundation
import Observation

protocol UserServicing: AnyObject {
    var profile: UserProfile? { get }
    /// JPEG data of the user's photo, `nil` when no photo is set.
    var avatarData: Data? { get }
    var hasCompletedOnboarding: Bool { get }

    func save(_ profile: UserProfile)
    func updateName(_ name: String) throws
    func updateAvatar(_ imageData: Data?) throws
    func updatePersonal(_ personal: PersonalContext) throws
    func setPremium(_ isPremium: Bool)
    func signOut()
}

enum UserServiceError: LocalizedError {
    case invalidName
    case noProfile

    var errorDescription: String? {
        switch self {
        case .invalidName:
            "Name must be \(UserProfile.nameMinLength)–\(UserProfile.nameMaxLength) characters."
        case .noProfile:
            "Profile not found."
        }
    }
}

/// Stores the user's profile and photo locally. Observable so every screen showing
/// the name or avatar updates right after an edit. When Supabase is added this becomes
/// the place that syncs with the `profiles` table and Storage bucket.
@Observable
final class UserService: UserServicing {
    private(set) var profile: UserProfile?
    private(set) var avatarData: Data?

    @ObservationIgnored private let storage: StorageManaging
    @ObservationIgnored private let imageStorage: ImageStorageManaging
    @ObservationIgnored private let avatarFileName = "avatar"

    init(storage: StorageManaging, imageStorage: ImageStorageManaging) {
        self.storage = storage
        self.imageStorage = imageStorage
        profile = storage.load(UserProfile.self, for: .userProfile)
        avatarData = imageStorage.load(avatarFileName)
    }

    var hasCompletedOnboarding: Bool { profile != nil }

    func save(_ profile: UserProfile) {
        self.profile = profile
        storage.save(profile, for: .userProfile)
    }

    func updateName(_ name: String) throws {
        guard var profile else { throw UserServiceError.noProfile }
        guard let name = UserProfile.validatedName(name) else { throw UserServiceError.invalidName }
        profile.name = name
        save(profile)
    }

    func updateAvatar(_ imageData: Data?) throws {
        guard let imageData else {
            imageStorage.remove(avatarFileName)
            avatarData = nil
            return
        }
        avatarData = try imageStorage.save(imageData, as: avatarFileName)
    }

    func updatePersonal(_ personal: PersonalContext) throws {
        guard var profile else { throw UserServiceError.noProfile }
        profile.personal = personal.isEmpty ? nil : personal
        save(profile)
    }

    func setPremium(_ isPremium: Bool) {
        guard var profile else { return }
        profile.isPremium = isPremium
        save(profile)
    }

    func signOut() {
        profile = nil
        avatarData = nil
        imageStorage.remove(avatarFileName)
        storage.removeAll()
    }
}
