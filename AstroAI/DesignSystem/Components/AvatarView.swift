//
//  AvatarView.swift
//  AstroAI
//

import SwiftUI

/// What an avatar shows: the user's photo, or the initial of their name.
struct AvatarContent: Equatable {
    var imageData: Data?
    var name: String = ""

    var initial: String {
        name.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? ""
    }
}

/// Circular user avatar. Falls back to an aubergine circle with the name's initial.
struct AvatarView: View {
    let content: AvatarContent
    var size: CGFloat = 32

    var body: some View {
        Group {
            if let data = content.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    AppColor.primaryContainer
                    if content.initial.isEmpty {
                        Image(systemName: "person")
                            .font(.system(size: size * 0.42, weight: .medium))
                    } else {
                        Text(content.initial)
                            .font(.system(size: size * 0.45, weight: .regular, design: .serif))
                    }
                }
                .foregroundStyle(AppColor.onPrimary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityLabel(content.name.isEmpty ? "Profile photo" : "\(content.name) profile photo")
    }
}

extension EnvironmentValues {
    /// Current user's avatar, provided once by the main coordinator for every top bar.
    @Entry var userAvatar = AvatarContent()
    /// True after a Sanctuary purchase. The coordinator publishes it so open screens unlock immediately.
    @Entry var isSanctuaryMember = false
}
