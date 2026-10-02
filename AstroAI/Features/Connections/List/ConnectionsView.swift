//
//  ConnectionsView.swift
//  AstroAI
//

import SwiftUI

struct ConnectionsView: View {
    @State private var viewModel: ConnectionsViewModel

    init(viewModel: ConnectionsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                AppTopBar(title: "Connections")

                Group {
                    if viewModel.isEmpty {
                        emptyState
                    } else {
                        list
                    }
                }
                .padding(.horizontal, Spacing.margin)
                .padding(.bottom, Spacing.xl)
            }
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .toolbarVisibility(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            OrbitIllustration()
                .frame(width: 260, height: 220)
                .padding(.top, Spacing.lg)

            VStack(spacing: Spacing.sm) {
                Eyebrow(text: "The Relational Ephemeris")
                Text("No charts in orbit yet.")
                    .font(AppFont.displayMobile)
                    .foregroundStyle(AppColor.onSurface)
                Text("Synastry is the study of how two personal skies interact — illuminating where emotional tides align, where friction sparks growth, and how communication flows between two unique configurations.")
                    .font(AppFont.bodyLarge)
                    .lineSpacing(4)
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }
            .multilineTextAlignment(.center)

            VStack(spacing: Spacing.sm) {
                ForEach(viewModel.suggestions) { suggestion in
                    Button(action: viewModel.addConnection) {
                        SuggestionRow(suggestion: suggestion)
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(spacing: Spacing.lg) {
                Button(action: viewModel.addConnection) {
                    Label("Add First Connection", systemImage: "plus")
                }
                .buttonStyle(.astroPrimary)

                Text("Read introduction to synastry geometry →")
                    .font(.system(size: 19, design: .serif).italic())
                    .foregroundStyle(AppColor.secondary)

                PrivacyFootnote(text: "Zero-Knowledge Privacy: Names and birth coordinates never leave your device unencrypted.")
            }
            .padding(.top, Spacing.md)
        }
    }

    // MARK: - Saved people

    private var list: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Eyebrow(text: "The Relational Ephemeris")
                Text("Charts in orbit")
                    .font(AppFont.displayMobile)
                    .foregroundStyle(AppColor.onSurface)
                Text("Tap a person to read how your skies interact. Long-press to remove.")
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }
            .padding(.top, Spacing.md)

            VStack(spacing: Spacing.sm) {
                ForEach(viewModel.rows) { row in
                    Button { viewModel.open(row) } label: {
                        ConnectionRow(row: row)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Remove", systemImage: "trash", role: .destructive) {
                            viewModel.remove(row)
                        }
                    }
                }
            }

            Button(action: viewModel.addConnection) {
                Label("Add Connection", systemImage: "plus")
            }
            .buttonStyle(.astroPrimary)
            .padding(.top, Spacing.sm)

            PrivacyFootnote(text: "Zero-Knowledge Privacy: Names and birth coordinates never leave your device unencrypted.")
        }
    }
}

// MARK: - Rows

private struct SuggestionRow: View {
    let suggestion: ConnectionsViewModel.Suggestion

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            IconBadge(systemName: suggestion.icon, size: 40, background: AppColor.surfaceContainerHighest)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(suggestion.title)
                    .font(AppFont.headlineMedium)
                    .foregroundStyle(AppColor.onSurface)
                Text(suggestion.text)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(Spacing.md + 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surfaceContainerLow, in: .rect(cornerRadius: Radius.lg))
        .contentShape(.rect)
    }
}

private struct ConnectionRow: View {
    let row: ConnectionsViewModel.Row

    var body: some View {
        HStack(spacing: Spacing.md) {
            GlyphBadge(glyph: row.signGlyph, size: 44, background: AppColor.surfaceContainerHighest)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(row.name)
                    .font(AppFont.headlineMedium)
                    .foregroundStyle(AppColor.onSurface)
                HStack(spacing: Spacing.xs) {
                    Image(systemName: row.kinshipIcon)
                    Text("\(row.kinship) · \(row.signName)")
                }
                .font(AppFont.bodySmall)
                .foregroundStyle(AppColor.onSurfaceVariant)
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColor.outline)
        }
        .padding(Spacing.md + 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surfaceContainerLow, in: .rect(cornerRadius: Radius.lg))
        .contentShape(.rect)
    }
}

// MARK: - Illustration

/// Two intersecting orbits with planet nodes (the design's empty-state SVG).
private struct OrbitIllustration: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [AppColor.secondaryContainer.opacity(0.3), .clear],
                    center: .center, startRadius: 0, endRadius: 70
                ))
                .frame(width: 140, height: 140)

            Canvas { context, size in
                // Design viewBox is 260x260; the drawing occupies y 54...206.
                context.translateBy(x: (size.width - 260) / 2, y: (size.height - 260) / 2)
                let line = AppColor.onSurface

                for x in [105.0, 155.0] {
                    context.stroke(circle(x, 130, 76), with: .color(line.opacity(0.18)), lineWidth: 0.75)
                    context.stroke(circle(x, 130, 54), with: .color(line.opacity(0.10)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                }

                context.stroke(segment(82, 72, 178, 188), with: .color(AppColor.secondary.opacity(0.45)), style: StrokeStyle(lineWidth: 0.75, dash: [3, 3]))
                context.stroke(segment(60, 140, 200, 120), with: .color(AppColor.charcoal.opacity(0.35)), lineWidth: 0.75)
                context.stroke(segment(130, 58, 130, 202), with: .color(AppColor.primaryContainer.opacity(0.25)), style: StrokeStyle(lineWidth: 0.5, dash: [1, 4]))

                context.fill(circle(82, 72, 3.5), with: .color(AppColor.surface))
                context.stroke(circle(82, 72, 3.5), with: .color(AppColor.primaryContainer), lineWidth: 1.2)
                context.fill(circle(178, 188, 3.5), with: .color(AppColor.surface))
                context.stroke(circle(178, 188, 3.5), with: .color(AppColor.secondary), lineWidth: 1.2)
                context.fill(circle(60, 140, 2.5), with: .color(AppColor.primaryContainer))
                context.fill(circle(200, 120, 2.5), with: .color(AppColor.secondary))
                context.fill(circle(130, 85, 1.5), with: .color(AppColor.primary.opacity(0.6)))
                context.fill(circle(130, 175, 1.5), with: .color(AppColor.primary.opacity(0.6)))

                context.draw(Text("☉").font(.system(size: 9, design: .serif)).foregroundStyle(AppColor.primaryContainer), at: CGPoint(x: 76, y: 62))
                context.draw(Text("☽").font(.system(size: 9, design: .serif)).foregroundStyle(AppColor.secondary), at: CGPoint(x: 186, y: 195))
            }
        }
    }

    private func circle(_ x: Double, _ y: Double, _ r: Double) -> Path {
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }

    private func segment(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: x1, y: y1))
        path.addLine(to: CGPoint(x: x2, y: y2))
        return path
    }
}
