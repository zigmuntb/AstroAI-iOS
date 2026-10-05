//
//  OracleOfflineView.swift
//  AstroAI
//

import SwiftUI

/// "System Offline / Ephemeris Error" state shown in place of the Oracle dialogue.
struct OracleOfflineView: View {
    let isRetrying: Bool
    let onRetry: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            statusBar
            hero
            ledger
            actions
            footnote
        }
    }

    private var statusBar: some View {
        HStack {
            Label("Sanctuary", systemImage: "smallcircle.filled.circle")
                .font(AppFont.headlineMedium)
                .foregroundStyle(AppColor.onSurface)
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(AppColor.secondary).frame(width: 5, height: 5)
                Text("OFFLINE MODE · EPHEMERIS CACHED")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(AppFont.labelSmall)
            .tracking(0.8)
            .foregroundStyle(AppColor.onSurfaceVariant)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppColor.surfaceContainerHigh, in: .capsule)
        }
    }

    private var hero: some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                OfflineAstrolabe()
                    .frame(width: 160, height: 160)
                Image(systemName: "icloud.slash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColor.primaryContainer)
                    .frame(width: 28, height: 28)
                    .background(AppColor.primaryContainer.opacity(0.08), in: .circle)
            }
            .padding(.vertical, Spacing.lg)

            Eyebrow(text: "Ephemeris Synchronization Paused")
            Text("The stars remain. The connection has drifted.")
                .font(AppFont.headlineLarge)
                .foregroundStyle(AppColor.onSurface)
            Text("We are unable to reach the planetary calculation matrix or your AI Oracle dialogue. Your cached natal chart, daily reflections, and saved folios remain accessible locally.")
                .font(AppFont.bodyMedium)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .padding(.top, Spacing.xs)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var ledger: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Label("Local Ephemeris Ledger", systemImage: "plus.circle")
                    .font(AppFont.bodyMedium.weight(.medium))
                    .foregroundStyle(AppColor.onSurface)
                Spacer()
                Text("DE431 Engine")
                    .font(AppFont.labelMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }
            HairlineDivider()
            ledgerRow(
                icon: "checkmark", title: "Available Offline",
                text: "Natal Blueprint (Placidus), Today's Transit Matrix, Past 14 Journal Entries",
                tint: AppColor.secondary, titleColor: AppColor.onSurface
            )
            ledgerRow(
                icon: "pause.fill", title: "Temporarily Suspended",
                text: "Real-time Oracle synthesis & Live Ingress sub-second tracking",
                tint: AppColor.primaryContainer, titleColor: AppColor.primaryContainer
            )
        }
        .card(.tinted, padding: Spacing.md + 4)
    }

    private func ledgerRow(icon: String, title: String, text: String, tint: Color, titleColor: Color) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 20, height: 20)
                .background(AppColor.surfaceContainerHighest, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.labelLarge.weight(.medium))
                    .tracking(0.4)
                    .foregroundStyle(titleColor)
                Text(text)
                    .font(AppFont.bodySmall)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: Spacing.sm) {
            Button(action: onRetry) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .symbolEffect(.rotate, isActive: isRetrying)
                    Text(isRetrying ? "Probing Celestial Mesh..." : "Retry Ephemeris Handshake")
                }
            }
            .buttonStyle(.astroPrimary)
            .disabled(isRetrying)

            Button(action: onContinue) {
                Label("Continue Reading Offline Folios", systemImage: "book")
                    .font(AppFont.bodyLarge.weight(.semibold))
                    .foregroundStyle(AppColor.onSurface)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(AppColor.surfaceContainer, in: .rect(cornerRadius: Radius.md))
            }
            .buttonStyle(.plain)
        }
    }

    private var footnote: some View {
        VStack(spacing: Spacing.xs) {
            Text("CODE: EPH_NETWORK_TIMEOUT (504)")
                .font(AppFont.labelMedium)
                .tracking(0.6)
            Text("Swiss Ephemeris DE431 local cache is intact · Last verified 14m ago")
                .font(AppFont.bodySmall)
        }
        .foregroundStyle(AppColor.outline)
        .multilineTextAlignment(.center)
    }
}

/// Hairline astrolabe with broken orbit arcs.
private struct OfflineAstrolabe: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 160
            context.scaleBy(x: scale, y: scale)
            let line = AppColor.outline

            context.stroke(
                Path(ellipseIn: CGRect(x: 6, y: 6, width: 148, height: 148)),
                with: .color(line.opacity(0.35)), style: StrokeStyle(lineWidth: 0.75, dash: [3, 4])
            )
            context.stroke(Path(ellipseIn: CGRect(x: 22, y: 22, width: 116, height: 116)), with: .color(line.opacity(0.45)), lineWidth: 0.75)

            var arcs = Path()
            arcs.addArc(center: CGPoint(x: 80, y: 80), radius: 48, startAngle: .degrees(180), endAngle: .degrees(315), clockwise: false)
            arcs.move(to: CGPoint(x: 128, y: 80))
            arcs.addArc(center: CGPoint(x: 80, y: 80), radius: 48, startAngle: .degrees(0), endAngle: .degrees(135), clockwise: false)
            context.stroke(arcs, with: .color(AppColor.onSurfaceVariant), style: StrokeStyle(lineWidth: 1, lineCap: .round))

            for (from, to) in [((80, 12), (80, 28)), ((80, 132), (80, 148)), ((12, 80), (28, 80)), ((132, 80), (148, 80))] {
                var tick = Path()
                tick.move(to: CGPoint(x: from.0, y: from.1))
                tick.addLine(to: CGPoint(x: to.0, y: to.1))
                context.stroke(tick, with: .color(line.opacity(0.5)), lineWidth: 0.75)
            }

            var cross = Path()
            cross.move(to: CGPoint(x: 38, y: 38)); cross.addLine(to: CGPoint(x: 122, y: 122))
            cross.move(to: CGPoint(x: 122, y: 38)); cross.addLine(to: CGPoint(x: 38, y: 122))
            context.stroke(cross, with: .color(line.opacity(0.3)), style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))

            let arcEnd1 = CGPoint(x: 80 + 48 * cos(CGFloat.pi * 7 / 4), y: 80 + 48 * sin(CGFloat.pi * 7 / 4))
            let arcEnd2 = CGPoint(x: 80 + 48 * cos(CGFloat.pi * 3 / 4), y: 80 + 48 * sin(CGFloat.pi * 3 / 4))
            for point in [arcEnd1, arcEnd2] {
                context.fill(Path(ellipseIn: CGRect(x: point.x - 2.5, y: point.y - 2.5, width: 5, height: 5)), with: .color(AppColor.onSurfaceVariant))
            }
        }
    }
}
