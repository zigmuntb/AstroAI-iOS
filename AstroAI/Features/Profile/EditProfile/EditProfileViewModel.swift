//
//  EditProfileViewModel.swift
//  AstroAI
//

import Foundation
import Observation

@Observable
final class EditProfileViewModel {
    var name: String {
        didSet {
            if name.count > UserProfile.nameMaxLength {
                name = String(name.prefix(UserProfile.nameMaxLength))
            }
        }
    }

    var personal: PersonalContext

    /// Photo shown in the editor. Saved only when the user taps Save.
    private(set) var photoData: Data?
    private(set) var isLoadingPhoto = false
    private(set) var isSaving = false
    var errorMessage: String?

    @ObservationIgnored private let originalName: String
    @ObservationIgnored private let originalPersonal: PersonalContext
    @ObservationIgnored private var photoChanged = false
    @ObservationIgnored private let userService: UserServicing
    @ObservationIgnored private weak var router: MainRouting?

    init(userService: UserServicing, router: MainRouting) {
        self.userService = userService
        self.router = router
        originalName = userService.profile?.name ?? ""
        name = originalName
        originalPersonal = userService.profile?.personal ?? PersonalContext()
        personal = originalPersonal
        photoData = userService.avatarData
    }

    // MARK: - Display

    var avatar: AvatarContent { AvatarContent(imageData: photoData, name: name) }
    var hasPhoto: Bool { photoData != nil }
    var counterText: String { "\(name.count)/\(UserProfile.nameMaxLength)" }
    var isNameValid: Bool { UserProfile.validatedName(name) != nil }

    var nameHint: String? {
        isNameValid ? nil : "At least \(UserProfile.nameMinLength) characters."
    }

    var canSave: Bool {
        guard isNameValid, !isSaving, !isLoadingPhoto else { return false }
        let nameChanged = UserProfile.validatedName(name) != originalName
        return nameChanged || photoChanged || personal != originalPersonal
    }

    // MARK: - Actions

    func photoLoadingStarted() {
        isLoadingPhoto = true
    }

    func setPhoto(_ data: Data?) {
        isLoadingPhoto = false
        guard let data else {
            errorMessage = "We couldn't load this photo. Try another one."
            return
        }
        photoData = data
        photoChanged = true
    }

    func removePhoto() {
        photoData = nil
        photoChanged = true
    }

    func save() {
        guard canSave else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try userService.updateName(name)
            if photoChanged {
                try userService.updateAvatar(photoData)
            }
            if personal != originalPersonal {
                try userService.updatePersonal(personal)
            }
            router?.dismissSheet()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func close() {
        router?.dismissSheet()
    }
}
