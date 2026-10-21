//
//  AstrologyDisclosure.swift
//  AstroAI
//

import SwiftUI

/// Collapsed by default. Shown only when there is a real explanation to read.
struct AstrologyDisclosure: View {
    var title: String = "The astrology behind it"
    let text: String

    var body: some View {
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            DisclosureGroup {
                Text(text)
                    .font(AppFont.bodySmall)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Spacing.xs)
            } label: {
                Text(title)
                    .font(AppFont.labelLarge)
                    .foregroundStyle(AppColor.secondary)
                    .multilineTextAlignment(.leading)
            }
            .tint(AppColor.secondary)
        }
    }
}
