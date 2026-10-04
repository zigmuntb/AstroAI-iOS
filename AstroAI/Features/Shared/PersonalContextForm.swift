//
//  PersonalContextForm.swift
//  AstroAI
//

import SwiftUI

/// Optional life-context questions used in onboarding and Edit Profile.
/// Tapping a selected chip again clears the answer.
struct PersonalContextForm: View {
    @Binding var context: PersonalContext
    @FocusState private var isFocusFieldActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            section("Relationship", icon: "heart") {
                chips(RelationshipStatus.allCases, selection: $context.relationship, title: \.title)
            }
            section("Life stage", icon: "figure.walk") {
                chips(LifeStage.allCases, selection: $context.lifeStage, title: \.title)
            }
            section("Pronouns", icon: "person") {
                chips(Pronouns.allCases, selection: $context.pronouns, title: \.title)
            }
            section("What's on your mind lately?", icon: "text.bubble") {
                focusField
            }
            section("How should the Oracle speak to you?", icon: "sparkles") {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    chips(AnswerTone.allCases, selection: $context.tone, title: \.title)
                    chips(AnswerLength.allCases, selection: $context.length, title: \.title)
                }
            }
        }
    }

    private func section(_ title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Eyebrow(text: title, icon: icon, color: AppColor.onSurfaceVariant)
            content()
        }
    }

    private func chips<Option: Identifiable & Equatable>(_ options: [Option], selection: Binding<Option?>, title: KeyPath<Option, String>) -> some View {
        FlowLayout(spacing: Spacing.sm) {
            ForEach(options) { option in
                Chip(title: option[keyPath: title], isSelected: selection.wrappedValue == option) {
                    selection.wrappedValue = selection.wrappedValue == option ? nil : option
                }
            }
        }
    }

    private var focusField: some View {
        let text = Binding(
            get: { context.currentFocus ?? "" },
            set: { context.currentFocus = String($0.prefix(PersonalContext.focusMaxLength)) }
        )
        return VStack(alignment: .trailing, spacing: Spacing.xs) {
            TextField("e.g. Thinking about moving abroad, a new relationship, burnout at work…", text: text, axis: .vertical)
                .font(AppFont.bodyMedium)
                .foregroundStyle(AppColor.onSurface)
                .lineLimit(3...6)
                .focused($isFocusFieldActive)
                .padding(Spacing.md)
                .background(AppColor.surfaceContainerLowest, in: .rect(cornerRadius: Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(isFocusFieldActive ? AppColor.champagne : AppColor.hairline.opacity(0.18), lineWidth: isFocusFieldActive ? 1 : 0.5)
                )
            Text("\(text.wrappedValue.count)/\(PersonalContext.focusMaxLength)")
                .font(AppFont.labelMedium)
                .foregroundStyle(AppColor.outline)
                .monospacedDigit()
        }
    }
}

/// Wraps children onto new lines when they don't fit the width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows.filter { !$0.indices.isEmpty }
    }
}
