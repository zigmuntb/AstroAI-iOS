//
//  BalanceDeck.swift
//  AstroAI
//
//  Today's four leans as a deck. A sideways swipe tucks the open card
//  back under the pile and turns the next one face up. Nothing is discarded.
//

import SwiftUI
import UIKit

struct BalanceDeck: View {
    let dials: [LifeDial]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var front = 0
    @State private var dragX: CGFloat = 0
    @State private var mode: DragMode = .idle
    @State private var nudge: CGFloat = 0
    @State private var epoch = 0
    /// Bumps only when a card should spring into a new place. Finger-tracking stays instant.
    @State private var settle = 0
    @State private var cancelling = false

    private var count: Int { dials.count }

    var body: some View {
        if count > 0 {
            VStack(spacing: Spacing.sm) {
                pile
                if count > 1 {
                    pager
                }
            }
            .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: front)
            .task { await playNudge() }
        }
    }

    // MARK: - Pile

    private var pile: some View {
        ZStack {
            ForEach(dials.indices, id: \.self) { index in
                let pose = pose(for: index)
                card(at: index, pose: pose)
                    .scaleEffect(pose.lift, anchor: .center)
                    .rotationEffect(.degrees(pose.rotation), anchor: UnitPoint(x: 0.5, y: 0.62))
                    .offset(x: pose.x, y: pose.y)
                    .shadow(color: AppColor.midnight.opacity(pose.shadow), radius: pose.shadowRadius, y: pose.shadowY)
                    .animation(settleAnimation, value: settle)
                    .zIndex(Double(pose.drawOrder))
            }
        }
        .frame(height: cardHeight)
        .padding(.top, 14)
        .padding(.bottom, 32)
        .contentShape(.rect)
        .gesture(DeckPan(isEnabled: count > 1, onChanged: follow, onEnded: finish))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenCard)
        .accessibilityValue("Card \(front + 1) of \(count)")
        .accessibilityHint("Swipe sideways. The card stays in the deck.")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: show(step: 1)
            case .decrement: show(step: -1)
            @unknown default: break
            }
        }
    }

    private func card(at index: Int, pose: Pose) -> some View {
        let dial = dials[index]
        let tints = dialTints(dial)
        return BalanceCard(
            dial: dial,
            position: index + 1,
            count: count,
            showsFace: pose.showsFace,
            leftTint: tints.0,
            rightTint: tints.1,
            height: cardHeight,
            noteLines: noteLines
        )
    }

    // MARK: - Pager

    private var pager: some View {
        HStack(spacing: Spacing.md) {
            pagerButton("chevron.left", label: "Previous card", step: -1)
            HStack(spacing: 6) {
                ForEach(dials.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == front ? AppColor.primary : AppColor.outlineVariant.opacity(0.4))
                        .frame(width: index == front ? 16 : 6, height: 6)
                }
            }
            .animation(cycleAnimation, value: front)
            .accessibilityHidden(true)
            pagerButton("chevron.right", label: "Next card", step: 1)
        }
        .frame(maxWidth: .infinity)
    }

    private func pagerButton(_ name: String, label: String, step: Int) -> some View {
        Button {
            show(step: step)
        } label: {
            Image(systemName: name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColor.onSurfaceVariant)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Motion

    private var settleAnimation: Animation {
        cancelling ? cancelAnimation : cycleAnimation
    }

    private func pose(for index: Int) -> Pose {
        let depth = visualDepth(of: index)
        let isTop = slot(of: index) == 0
        let revealing = isCoverCard(index) && mode != .idle
        let progress = min(abs(dragX) / 108, 1)

        var y = CGFloat(min(depth, 2)) * 11
        if revealing {
            y *= (1 - progress)
        }
        if isTop, mode != .idle {
            y -= min(abs(dragX) / 26, 8)
        }

        var x: CGFloat = 0
        var rotation = 0.0
        if isTop {
            if mode == .idle {
                x = nudge
                if !reduceMotion {
                    rotation = max(-8, min(8, Double(nudge / 7)))
                }
            } else {
                x = dragX
                if !reduceMotion {
                    rotation = max(-8, min(8, Double(dragX / 16)))
                }
            }
        }

        let shadow = isTop ? 0.12 + 0.08 * progress : 0.05
        return Pose(
            x: x,
            y: y,
            lift: isTop && mode != .idle ? 1 + 0.018 * progress : 1,
            rotation: rotation,
            showsFace: isTop,
            drawOrder: count - depth,
            shadow: shadow,
            shadowRadius: isTop ? 18 : 6,
            shadowY: isTop ? 10 : 3
        )
    }

    /// Depth 0 is the open card. While a backward drag is in progress, the
    /// previous card sits in the slot directly underneath so the gap shows
    /// the card the finger is about to land on.
    private func visualDepth(of index: Int) -> Int {
        let base = slot(of: index)
        guard mode == .backward else { return base }
        if base == count - 1 { return 1 }
        if base == 1 { return count - 1 }
        return base
    }

    private func isCoverCard(_ index: Int) -> Bool {
        let base = slot(of: index)
        switch mode {
        case .backward: return base == count - 1
        case .forward: return base == 1
        case .idle: return false
        }
    }

    private func slot(of index: Int) -> Int {
        (index - front + count) % count
    }

    private func follow(_ translation: CGFloat) {
        guard count > 1 else { return }
        if mode == .idle {
            guard abs(translation) > 8 else { return }
            mode = translation < 0 ? .forward : .backward
            epoch += 1
            nudge = 0
        }
        let pulled = resist(translation)
        dragX = mode == .forward ? min(pulled, 0) : max(pulled, 0)
    }

    private func finish(_ velocity: CGFloat) {
        guard mode != .idle else { return }
        let projected = dragX + velocity * 0.12
        let forward = mode == .forward && (projected < -56 || velocity < -680)
        let backward = mode == .backward && (projected > 56 || velocity > 680)
        if forward {
            show(step: 1)
        } else if backward {
            show(step: -1)
        } else {
            springBack()
        }
    }

    private func show(step: Int) {
        guard count > 1 else { return }
        epoch += 1
        let next = (front + step + count) % count
        if reduceMotion {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                front = next
                dragX = 0
                mode = .idle
                nudge = 0
                cancelling = false
            }
            return
        }
        // Geometry springs via `settle`. Stacking order is outside that
        // animation, so the leaving card slips under the pile instead of
        // sliding back across the one that just opened.
        cancelling = false
        front = next
        dragX = 0
        mode = .idle
        nudge = 0
        settle += 1
    }

    /// The open card falls back into place. The card glimpsed underneath
    /// stays where it is until the gap has closed, then the resting order
    /// returns while the pile is covered again.
    private func springBack() {
        let captured = epoch
        cancelling = true
        dragX = 0
        nudge = 0
        settle += 1
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(480))
            guard epoch == captured else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                if abs(dragX) < 1 {
                    mode = .idle
                    cancelling = false
                }
            }
        }
    }

    private func resist(_ x: CGFloat) -> CGFloat {
        let cap: CGFloat = 124
        let sign: CGFloat = x < 0 ? -1 : 1
        let mag = abs(x)
        return sign * (cap * mag / (mag + 72))
    }

    private func playNudge() async {
        guard !reduceMotion, count > 1 else { return }
        try? await Task.sleep(for: .milliseconds(850))
        guard !Task.isCancelled, mode == .idle, epoch == 0 else { return }
        withAnimation(.easeInOut(duration: 0.4)) { nudge = -22 }
        try? await Task.sleep(for: .milliseconds(460))
        guard !Task.isCancelled, mode == .idle, epoch == 0 else { return }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.58)) { nudge = 0 }
    }

    private var cycleAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.52, dampingFraction: 0.78)
    }

    private var cancelAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.46, dampingFraction: 0.64)
    }

    private var cardHeight: CGFloat {
        if typeSize.isAccessibilitySize { return 440 }
        switch typeSize {
        case .xxxLarge, .xxLarge: return 372
        case .xLarge: return 336
        default: return 312
        }
    }

    private var noteLines: Int {
        typeSize.isAccessibilitySize ? 10 : 5
    }

    private var spokenCard: String {
        let dial = dials[front]
        return "\(dial.left) \(100 - dial.value) out of 100. \(dial.right) \(dial.value) out of 100. \(dial.note)"
    }

    private func dialTints(_ dial: LifeDial) -> (Color, Color) {
        switch dial.id {
        case "bonds": (AppColor.dustyRose, AppColor.secondary)
        case "circle": (AppColor.sage, AppColor.primaryContainer)
        case "tempo": (AppColor.secondary, AppColor.primary)
        default: (AppColor.primaryContainer, AppColor.dustyRose)
        }
    }
}

// MARK: - Pose

private enum DragMode {
    case idle, forward, backward
}

private struct Pose {
    var x: CGFloat
    var y: CGFloat
    var lift: CGFloat
    var rotation: Double
    var showsFace: Bool
    /// Lower values are drawn first, so the open card stays on top of the pile.
    var drawOrder: Int
    var shadow: Double
    var shadowRadius: CGFloat
    var shadowY: CGFloat
}

// MARK: - Card

private struct BalanceCard: View {
    let dial: LifeDial
    let position: Int
    let count: Int
    let showsFace: Bool
    let leftTint: Color
    let rightTint: Color
    let height: CGFloat
    let noteLines: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isEven: Bool { dial.value == 50 }
    private var focusIsRight: Bool { dial.value > 50 }

    private var focusTitle: String {
        if isEven { return "Even" }
        return focusIsRight ? dial.right : dial.left
    }

    private var focusIcon: String {
        if isEven { return "circle.lefthalf.filled" }
        return focusIsRight ? dial.rightIcon : dial.leftIcon
    }

    private var focusTint: Color {
        if isEven { return AppColor.primary }
        return focusIsRight ? rightTint : leftTint
    }

    private var focusScore: Int {
        focusIsRight ? dial.value : 100 - dial.value
    }

    private var caption: String {
        if isEven { return "\(dial.left) and \(dial.right) share the day." }
        let toward = focusIsRight ? dial.right : dial.left
        let other = focusIsRight ? dial.left : dial.right
        return "\(focusScore) toward \(toward.lowercased()), \(100 - focusScore) toward \(other.lowercased())."
    }

    var body: some View {
        ZStack {
            back
            face
                .opacity(showsFace ? 1 : 0)
                .offset(y: showsFace ? 0 : 18)
                .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.48, dampingFraction: 0.82), value: showsFace)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(cardShape)
        .overlay {
            cardShape.strokeBorder(AppColor.outlineVariant.opacity(0.55), lineWidth: 1)
        }
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
    }

    private var back: some View {
        ZStack {
            AppColor.surfaceContainerLow
            RadialGradient(
                colors: [AppColor.secondaryContainer.opacity(0.9), .clear],
                center: .center,
                startRadius: 12,
                endRadius: 180
            )
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppColor.champagne.opacity(0.55), lineWidth: 1)
                .padding(14)
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(AppColor.champagne.opacity(0.28), lineWidth: 0.5)
                .padding(20)
            Image(systemName: "sparkle")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(AppColor.secondary)
                .accessibilityHidden(true)
        }
    }

    private var face: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text("\(dial.left)  ·  \(dial.right)")
                    .font(AppFont.labelMedium)
                    .foregroundStyle(AppColor.secondary)
                    .lineLimit(1)
                Spacer(minLength: Spacing.sm)
                Text("\(position) of \(count)")
                    .font(AppFont.labelMedium)
                    .monospacedDigit()
                    .foregroundStyle(AppColor.outline)
            }

            Spacer(minLength: Spacing.md)

            HStack(alignment: .center, spacing: Spacing.sm) {
                Image(systemName: focusIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(focusTint)
                    .frame(width: 36, height: 36)
                    .background(focusTint.opacity(0.14), in: .circle)
                    .accessibilityHidden(true)
                Text(focusTitle)
                    .font(AppFont.displayMobile)
                    .foregroundStyle(AppColor.onSurface)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Spacer(minLength: Spacing.sm)
                if !isEven {
                    Text("\(focusScore)")
                        .font(AppFont.displayMobile)
                        .foregroundStyle(focusTint)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }

            Text(caption)
                .font(AppFont.bodyMedium)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.sm)

            BalanceMeter(dial: dial, leftTint: leftTint, rightTint: rightTint, showsFace: showsFace)
                .padding(.top, Spacing.md)

            Spacer(minLength: Spacing.md)

            Text(dial.note)
                .font(AppFont.bodySmall)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .lineSpacing(2)
                .lineLimit(noteLines)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            ZStack {
                AppColor.surfaceContainerLowest
                RadialGradient(
                    colors: [focusTint.opacity(0.16), .clear],
                    center: .topTrailing,
                    startRadius: 8,
                    endRadius: 240
                )
            }
        }
    }
}

// MARK: - Meter

private struct BalanceMeter: View {
    let dial: LifeDial
    let leftTint: Color
    let rightTint: Color
    let showsFace: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0.5

    private var lean: CGFloat { CGFloat(dial.value) / 100 }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            HStack {
                poleIcon(dial.leftIcon, tint: leftTint, emphasized: dial.value < 50)
                Spacer()
                poleIcon(dial.rightIcon, tint: rightTint, emphasized: dial.value > 50)
            }
            bar
        }
        .accessibilityHidden(true)
        .onChange(of: showsFace, initial: true) { _, show in
            if show {
                reveal()
            } else {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { progress = 0.5 }
            }
        }
    }

    private var bar: some View {
        GeometryReader { geo in
            let knob: CGFloat = 16
            let width = geo.size.width
            let travel = max(width - knob, 0)
            let split = travel * progress + knob / 2
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(rightTint.opacity(0.72))
                    .frame(height: 6)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(leftTint.opacity(0.9))
                            .frame(width: max(split, 0))
                    }
                    .clipShape(Capsule())
                Circle()
                    .fill(AppColor.surfaceContainerLowest)
                    .overlay { Circle().stroke(knobTint, lineWidth: 1.5) }
                    .shadow(color: AppColor.primary.opacity(0.16), radius: 2, y: 1)
                    .frame(width: knob, height: knob)
                    .offset(x: travel * progress)
            }
            .frame(width: width, height: knob, alignment: .leading)
        }
        .frame(height: 16)
    }

    private var knobTint: Color {
        if dial.value < 50 { return leftTint }
        if dial.value > 50 { return rightTint }
        return AppColor.primaryContainer
    }

    private func poleIcon(_ name: String, tint: Color, emphasized: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(emphasized ? tint : AppColor.outline)
            .frame(width: 16, height: 16)
    }

    private func reveal() {
        if reduceMotion {
            progress = lean
            return
        }
        progress = 0.5
        withAnimation(.spring(response: 0.72, dampingFraction: 0.84).delay(0.05)) {
            progress = lean
        }
    }
}

// MARK: - Pan

/// Horizontal pan that lets a vertical drag fall through to the page scroll.
private struct DeckPan: UIGestureRecognizerRepresentable {
    var isEnabled: Bool
    var onChanged: (CGFloat) -> Void
    var onEnded: (CGFloat) -> Void

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        pan.maximumNumberOfTouches = 1
        return pan
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began, .changed:
            let width = recognizer.translation(in: recognizer.view).x
            context.coordinator.onChanged(width)
        case .ended:
            context.coordinator.onEnded(recognizer.velocity(in: recognizer.view).x)
        case .cancelled, .failed:
            context.coordinator.onEnded(0)
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChanged: (CGFloat) -> Void = { _ in }
        var onEnded: (CGFloat) -> Void = { _ in }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y) * 1.2
        }
    }
}

#Preview {
    ScrollView {
        BalanceDeck(dials: [
            LifeDial(id: "bonds", left: "Relationships", right: "Work", leftIcon: "heart", rightIcon: "briefcase", value: 64, note: "Give the day to the work itself. A Capricorn Moon favors effort you can finish."),
            LifeDial(id: "circle", left: "Friends", right: "Family", leftIcon: "person.2", rightIcon: "house", value: 71, note: "Family has the clearer claim. The Moon is home, in the house of roots."),
            LifeDial(id: "tempo", left: "New", right: "Routine", leftIcon: "sparkles", rightIcon: "repeat", value: 38, note: "Try one thing that isn't already in the plan. A mutable Moon loosens the script."),
            LifeDial(id: "energy", left: "Rest", right: "Action", leftIcon: "moon.stars", rightIcon: "bolt", value: 44, note: "Move slowly. Rest is doing something. The Moon is waning.")
        ])
        .padding(.horizontal, Spacing.margin)
        .padding(.top, 40)
    }
    .screenBackground()
}
