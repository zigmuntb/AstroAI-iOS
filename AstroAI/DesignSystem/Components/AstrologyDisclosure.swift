//
//  AstrologyDisclosure.swift
//  AstroAI
//

import SwiftUI

/// Collapsed by default. Shown only when there is a real explanation to read.
struct AstrologyDisclosure: View {
    var title: String = "The astrology behind it"
    let text: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded: Bool

    init(title: String = "The astrology behind it", text: String, initiallyExpanded: Bool = false) {
        self.title = title
        self.text = text
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            DisclosureGroup(isExpanded: $isExpanded) {
                Text(text)
                    .font(AppFont.bodySmall)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.sm)
            } label: {
                Text(title)
                    .font(AppFont.labelLarge)
                    .foregroundStyle(AppColor.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .tint(AppColor.secondary)
            .animation(reduceMotion ? nil : .smooth(duration: 0.28), value: isExpanded)
        }
    }
}
