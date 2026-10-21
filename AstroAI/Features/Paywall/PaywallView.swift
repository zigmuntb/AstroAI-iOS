//
//  PaywallView.swift
//  AstroAI
//

import SwiftUI

struct PaywallView: View {
    @State private var viewModel: PaywallViewModel
    @State private var legalDocument: LegalDocument?

    init(viewModel: PaywallViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private let ivory = AppColor.ivory
    private let gold = AppColor.champagne

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                topBar
                hero
                OrbitDiagram()
                    .frame(width: 256, height: 256)
                features
                plans
                cta
                legal
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.bottom, Spacing.lg)
        }
        .scrollIndicators(.hidden)
        .background(AppColor.midnight.ignoresSafeArea())
        .overlay(alignment: .top) {
            Circle()
                .fill(AppColor.primaryContainer.opacity(0.35))
                .frame(width: 320, height: 320)
                .blur(radius: 100)
                .offset(y: -40)
                .allowsHitTesting(false)
        }
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(viewModel.isPurchasing)
        .task { await viewModel.load() }
        .sheet(item: $legalDocument) { document in
            LegalDocumentView(document: document)
        }
        .alert(
            viewModel.alert?.title ?? "",
            isPresented: Binding(get: { viewModel.alert != nil }, set: { if !$0 { viewModel.alert = nil } }),
            presenting: viewModel.alert
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
    }

    // MARK: - Header

    private var topBar: some View {
        HStack {
            Button(action: viewModel.close) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(ivory.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(ivory.opacity(0.08), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss Paywall")

            Spacer()

            Image("AstroSeal")
                .resizable()
                .scaledToFill()
                .frame(width: 32, height: 32)
                .clipShape(.circle)
                .overlay(Circle().stroke(gold.opacity(0.3), lineWidth: 1))

            Spacer()

            Button("Restore") { Task { await viewModel.restore() } }
                .font(AppFont.labelMedium)
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(ivory.opacity(0.5))
                .frame(width: 64, alignment: .trailing)
                .disabled(viewModel.isBusy)
        }
        .padding(.top, Spacing.md)
    }

    private var hero: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Circle().fill(gold).frame(width: 5, height: 5)
                Text("AstroAI Sanctuary".uppercased())
                    .font(AppFont.labelSmall)
                    .tracking(2.4)
                    .foregroundStyle(gold)
                Circle().fill(gold).frame(width: 5, height: 5)
            }
            Text("More of your day, when you want it.")
                .font(AppFont.headlineLarge)
                .foregroundStyle(ivory)
            Text("Unlimited questions, a fuller chart, longer forecasts, and readings with the people close to you.")
                .font(AppFont.bodySmall)
                .foregroundStyle(ivory.opacity(0.7))
                .lineSpacing(3)
                .padding(.horizontal, Spacing.sm)
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Features

    private var features: some View {
        VStack(spacing: 10) {
            ForEach(viewModel.features) { feature in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(gold)
                        .frame(width: 28, height: 28)
                        .background(ivory.opacity(0.08), in: .rect(cornerRadius: 6))
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(AppFont.headlineSmall)
                            .foregroundStyle(ivory)
                        Text(feature.text)
                            .font(AppFont.bodySmall)
                            .foregroundStyle(ivory.opacity(0.65))
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(ivory.opacity(0.04), in: .rect(cornerRadius: Radius.sm))
            }
        }
    }

    // MARK: - Plans

    @ViewBuilder
    private var plans: some View {
        if viewModel.isLoading && viewModel.plans.isEmpty {
            ProgressView().tint(gold).frame(height: 120)
        } else {
            VStack(spacing: 12) {
                ForEach(viewModel.plans) { plan in
                    planCard(plan, isSelected: plan.id == viewModel.selectedPlanID)
                }
            }
            .padding(.top, Spacing.sm)
        }
    }

    private func planCard(_ plan: SubscriptionPlan, isSelected: Bool) -> some View {
        Button {
            viewModel.select(plan)
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .stroke(isSelected ? gold : AppColor.hairline.opacity(0.4), lineWidth: 1.5)
                    .frame(width: 20, height: 20)
                    .overlay {
                        if isSelected { Circle().fill(gold).frame(width: 10, height: 10) }
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title)
                        .font(AppFont.headlineSmall)
                        .foregroundStyle(ivory)
                    Text(plan.subtitle)
                        .font(AppFont.bodySmall)
                        .foregroundStyle(ivory.opacity(0.6))
                }
                Spacer(minLength: Spacing.sm)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.price)
                        .font(AppFont.headlineSmall)
                        .foregroundStyle(plan.badge != nil ? gold : ivory)
                    Text(plan.period.uppercased())
                        .font(AppFont.labelSmall)
                        .tracking(1.4)
                        .foregroundStyle(ivory.opacity(0.5))
                }
            }
            .padding(Spacing.md)
            .padding(.vertical, 2)
            .background(ivory.opacity(isSelected ? 0.07 : 0.03), in: .rect(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(isSelected ? gold : AppColor.hairline.opacity(0.3), lineWidth: isSelected ? 1.5 : 0.5)
            )
            .overlay(alignment: .topTrailing) {
                if let badge = plan.badge {
                    Text(badge.uppercased())
                        .font(AppFont.labelSmall)
                        .tracking(0.8)
                        .foregroundStyle(AppColor.midnight)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(gold, in: .capsule)
                        .offset(x: -Spacing.md, y: -10)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.2), value: isSelected)
    }

    // MARK: - CTA

    private var cta: some View {
        VStack(spacing: 10) {
            Button {
                Task { await viewModel.purchase() }
            } label: {
                HStack(spacing: Spacing.sm) {
                    if viewModel.isPurchasing {
                        ProgressView().tint(ivory)
                    } else {
                        Image(systemName: "infinity")
                            .foregroundStyle(gold)
                        Text(viewModel.ctaTitle.uppercased())
                            .tracking(1.2)
                    }
                }
                .font(AppFont.labelLarge)
                .foregroundStyle(ivory)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(AppColor.primaryContainer, in: .rect(cornerRadius: Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: Radius.sm).stroke(gold.opacity(0.35), lineWidth: 0.75))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.selectedPlan == nil || viewModel.isBusy)

            Text(viewModel.termsText)
                .font(AppFont.bodySmall)
                .foregroundStyle(ivory.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.sm)
        }
    }

    private var legal: some View {
        HStack(spacing: 12) {
            Button("Terms of Service") { legalDocument = .terms }
            Text("•")
            Button("Privacy Policy") { legalDocument = .privacy }
            Text("•")
            Button("Restore") { Task { await viewModel.restore() } }
                .disabled(viewModel.isBusy)
        }
        .buttonStyle(.plain)
        .font(AppFont.labelSmall)
        .tracking(1)
        .textCase(.uppercase)
        .foregroundStyle(ivory.opacity(0.4))
    }
}

/// Fine orbit diagram of the hero: rings, aspect chords, Sun core and two orbiting tags.
private struct OrbitDiagram: View {
    private let ivory = AppColor.ivory
    private let gold = AppColor.champagne

    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2
                let line = AppColor.hairline

                func circle(_ factor: CGFloat) -> Path {
                    let r = radius * factor
                    return Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                }
                context.stroke(circle(1), with: .color(line.opacity(0.35)), style: StrokeStyle(lineWidth: 0.75, dash: [1, 4]))
                context.stroke(circle(0.82), with: .color(line.opacity(0.35)), lineWidth: 0.5)
                context.stroke(circle(0.6), with: .color(line.opacity(0.25)), lineWidth: 0.5)
                context.stroke(circle(0.4), with: .color(line.opacity(0.3)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))

                var axes = Path()
                axes.move(to: CGPoint(x: center.x - radius * 0.82, y: center.y))
                axes.addLine(to: CGPoint(x: center.x + radius * 0.82, y: center.y))
                axes.move(to: CGPoint(x: center.x, y: center.y - radius * 0.82))
                axes.addLine(to: CGPoint(x: center.x, y: center.y + radius * 0.82))
                context.stroke(axes, with: .color(line.opacity(0.2)), lineWidth: 0.5)

                func point(_ degrees: Double, _ factor: CGFloat) -> CGPoint {
                    let angle = CGFloat(degrees * .pi / 180)
                    return CGPoint(x: center.x + radius * factor * cos(angle), y: center.y - radius * factor * sin(angle))
                }
                var chord = Path()
                chord.move(to: point(150, 0.6))
                chord.addLine(to: point(70, 0.82))
                chord.addLine(to: point(-50, 0.68))
                context.stroke(chord, with: .color(gold.opacity(0.7)), lineWidth: 0.75)

                var dashed = Path()
                dashed.move(to: point(150, 0.6))
                dashed.addLine(to: center)
                dashed.addLine(to: point(-50, 0.68))
                context.stroke(dashed, with: .color(AppColor.dustyRose.opacity(0.7)), style: StrokeStyle(lineWidth: 0.75, dash: [3, 3]))
            }

            VStack(spacing: 2) {
                Text("☉")
                    .font(.system(size: 18, design: .serif))
                    .foregroundStyle(gold)
                Text("SCORPIO")
                    .font(AppFont.labelSmall)
                    .tracking(1)
                    .foregroundStyle(ivory.opacity(0.7))
            }
            .frame(width: 64, height: 64)
            .background(AppColor.midnight, in: .circle)
            .overlay(Circle().stroke(gold.opacity(0.4), lineWidth: 0.75))
            .shadow(color: .black.opacity(0.4), radius: 10)

            tag(glyph: "♄", title: "Saturn Transit", caption: "Trine Exact", glyphColor: gold, captionColor: gold.opacity(0.8))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(Spacing.md)
            tag(glyph: "☽", title: "Taurus Moon", caption: "14° 22' • H6", glyphColor: AppColor.dustyRose, captionColor: ivory.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, Spacing.md)
                .padding(.bottom, 20)
        }
    }

    private func tag(glyph: String, title: String, caption: String, glyphColor: Color, captionColor: Color) -> some View {
        HStack(spacing: 6) {
            Text(glyph)
                .font(AppFont.bodySmall)
                .foregroundStyle(glyphColor)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .foregroundStyle(ivory)
                Text(caption)
                    .foregroundStyle(captionColor)
            }
            .font(AppFont.labelSmall)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(AppColor.midnight.opacity(0.85), in: .capsule)
        .overlay(Capsule().stroke(gold.opacity(0.35), lineWidth: 0.75))
    }
}
