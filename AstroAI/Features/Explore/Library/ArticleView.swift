//
//  ArticleView.swift
//  AstroAI
//

import SwiftUI

/// Static reading page for a library article or compendium tome.
struct ArticleView: View {
    let article: Article

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text(article.glyph)
                        .font(.system(size: 26, design: .serif).italic())
                        .foregroundStyle(AppColor.primary)
                        .frame(width: 56, height: 56)
                        .background(AppColor.surfaceContainer, in: .rect(cornerRadius: Radius.md))

                    Eyebrow(text: article.eyebrow)

                    Text(article.title)
                        .font(AppFont.displayMobile)
                        .foregroundStyle(AppColor.onSurface)

                    Label(article.meta, systemImage: "book.closed")
                        .font(AppFont.labelMedium)
                        .foregroundStyle(AppColor.outline)
                }

                Text(article.summary)
                    .font(AppFont.quote)
                    .foregroundStyle(AppColor.onSurface)
                    .lineSpacing(4)
                    .padding(.leading, Spacing.md)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(AppColor.champagne).frame(width: 3)
                    }
                    .card(.tinted, padding: Spacing.lg)

                ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .font(AppFont.bodyLarge)
                        .foregroundStyle(AppColor.onSurface)
                        .lineSpacing(5)
                        .card(.elevated, padding: Spacing.lg)
                }

                PrivacyFootnote(text: "Symbolic language, not fixed fate", icon: "sparkles")
                    .padding(.top, Spacing.md)
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.vertical, Spacing.lg)
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
    }

    private var paragraphs: [String] {
        [
            "\(article.title) is best read slowly. Begin by locating where this theme lives in your own chart: the sign, the house and the planets that touch it. The archetype becomes meaningful only when it is anchored to a concrete area of your life.",
            "As you read, notice which passages feel familiar and which feel distant. Both are useful. Familiar ideas describe patterns you already live; distant ones often point to qualities waiting to be developed. Return to this chapter when a related transit activates your chart, and write down what has changed since your last reading."
        ]
    }
}
