//
//  LaunchAnimationView.swift
//  AstroAI
//
//  Opening plate. The page is already there; a pen traces the celestial mark,
//  one planet settles on the orbit, the name arrives, and the page fades
//  into the app. Tunables live in `LaunchTiming`.
//

import SwiftUI
import UIKit

/// Cold-start overlay. Plays once, then calls `onFinished`.
/// A tap skips to the fade. Reduced Motion and VoiceOver get a still plate.
struct LaunchAnimationView: View {
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock = 0.0
    @State private var veil = 1.0
    @State private var didStart = false
    @State private var didFinish = false

    var body: some View {
        LaunchPlate(time: clock * LaunchTiming.draw)
            .opacity(veil)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { beginExit(duration: LaunchTiming.skip) }
            .onAppear(perform: start)
            .task { await holdThenExit() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("AstroAI")
            .accessibilityAddTraits(.isModal)
    }

    private var prefersStill: Bool {
        reduceMotion || UIAccessibility.isVoiceOverRunning
    }

    private func start() {
        guard !didStart else { return }
        didStart = true
        if prefersStill {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { clock = 1 }
        } else {
            withAnimation(.linear(duration: LaunchTiming.draw)) {
                clock = 1
            }
        }
    }

    private func holdThenExit() async {
        let pause = prefersStill ? LaunchTiming.stillHold : LaunchTiming.play
        let exit = prefersStill ? LaunchTiming.stillExit : LaunchTiming.exit
        try? await Task.sleep(for: .seconds(pause))
        guard !Task.isCancelled else { return }
        beginExit(duration: exit)
    }

    private func beginExit(duration: TimeInterval) {
        guard !didFinish else { return }
        didFinish = true
        withAnimation(.easeInOut(duration: duration)) {
            veil = 0
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            onFinished()
        }
    }
}

// MARK: - Timing

/// All durations are seconds from the first frame. Edit these to retune the pace.
enum LaunchTiming {
    /// Pen traces the plate. The whole drawing lives inside this window.
    static let draw: TimeInterval = 1.35
    /// Quiet beat so the finished plate can be read.
    static let hold: TimeInterval = 0.38
    /// Crossfade into the first screen.
    static let exit: TimeInterval = 0.42
    /// Fade used when the plate is tapped.
    static let skip: TimeInterval = 0.22

    static let stillHold: TimeInterval = 0.32
    static let stillExit: TimeInterval = 0.28

    static var play: TimeInterval { draw + hold }

    /// Outer dashed ring.
    static let outerRing: ClosedRange<Double> = 0.00...0.82
    /// Tilted orbit.
    static let orbit: ClosedRange<Double> = 0.22...1.02
    /// Cardinal ticks.
    static let ticks: ClosedRange<Double> = 0.38...0.72
    /// Moon disc.
    static let moon: ClosedRange<Double> = 0.46...0.98
    /// Planet gliding into its resting place on the orbit.
    static let planet: ClosedRange<Double> = 0.68...1.28
    /// Second body, already at rest.
    static let companion: ClosedRange<Double> = 0.96...1.26
    /// Wordmark.
    static let word: ClosedRange<Double> = 0.86...1.32

    /// Where the traveling planet starts and rests, as a fraction of the orbit.
    /// 0 is the upper right, matching the celestial mark. Clockwise.
    static let planetDeparture = 0.62
    static let planetRest = 1.0
    static let companionPlace = 0.42
}

// MARK: - Plate

private struct LaunchPlate: View {
    /// Seconds since the drawing began. Clamped by the caller to `LaunchTiming.draw`.
    let time: Double

    var body: some View {
        GeometryReader { proxy in
            let mark = min(min(proxy.size.width, proxy.size.height) * 0.78, 420)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height * 0.44)
            let scale = mark / 100

            ZStack {
                AppColor.surface

                RadialGradient(
                    colors: [AppColor.secondaryContainer.opacity(0.55), .clear],
                    center: UnitPoint(x: 0.5, y: 0.44),
                    startRadius: 0,
                    endRadius: mark * 0.85
                )

                stars(in: proxy.size)

                plate(mark: mark, scale: scale)
                    .frame(width: mark, height: mark)
                    .position(center)

                wordmark
                    .position(x: center.x, y: center.y + mark / 2 + 36)
            }
        }
    }

    private func plate(mark: CGFloat, scale: CGFloat) -> some View {
        let ink = AppColor.charcoal
        let orbitInk = AppColor.primaryContainer
        let ringTrim = launchProgress(LaunchTiming.outerRing, at: time)
        let orbitTrim = launchProgress(LaunchTiming.orbit, at: time)
        let tickOpacity = launchProgress(LaunchTiming.ticks, at: time)
        let moonOpacity = launchProgress(LaunchTiming.moon, at: time, curve: easeInOutCubic)
        let travel = launchProgress(LaunchTiming.planet, at: time)
        let companionOpacity = launchProgress(LaunchTiming.companion, at: time)
        let planetT = CGFloat(lerp(LaunchTiming.planetDeparture, LaunchTiming.planetRest, travel))

        return ZStack {
            Circle()
                .stroke(ink.opacity(0.14), style: StrokeStyle(lineWidth: 1.2 * scale, dash: [2 * scale, 3 * scale]))
                .rotationEffect(.degrees(-90))
            Circle()
                .trim(from: 0, to: ringTrim)
                .stroke(ink.opacity(0.55), style: StrokeStyle(lineWidth: 1.2 * scale, lineCap: .round, dash: [2 * scale, 3 * scale]))
                .rotationEffect(.degrees(-90))

            LaunchOrbit()
                .stroke(orbitInk.opacity(0.16), lineWidth: 1.4 * scale)
            LaunchOrbit()
                .trim(from: 0, to: orbitTrim)
                .stroke(orbitInk, style: StrokeStyle(lineWidth: 1.4 * scale, lineCap: .round))

            ticks(opacity: tickOpacity, scale: scale, ink: ink)
            moon(opacity: moonOpacity, scale: scale)
        }
        .overlay {
            let bounds = CGRect(x: 0, y: 0, width: mark, height: mark)
            ZStack {
                orbitBody(at: CGFloat(LaunchTiming.companionPlace), in: bounds, diameter: 5 * scale, color: AppColor.dustyRose, opacity: companionOpacity)
                orbitBody(at: planetT, in: bounds, diameter: 7 * scale, color: AppColor.champagne, opacity: min(travel * 2.4, 1))
            }
        }
    }

    private func ticks(opacity: Double, scale: CGFloat, ink: Color) -> some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = size.width / 2 - 0.6 * scale
            let inner = outer - 10 * scale
            var path = Path()
            for quadrant in 0..<4 {
                let angle = CGFloat(quadrant) * .pi / 2 - .pi / 2
                path.move(to: CGPoint(x: center.x + inner * cos(angle), y: center.y + inner * sin(angle)))
                path.addLine(to: CGPoint(x: center.x + outer * cos(angle), y: center.y + outer * sin(angle)))
            }
            context.stroke(path, with: .color(ink.opacity(opacity)), style: StrokeStyle(lineWidth: 1.15 * scale, lineCap: .round))
        }
    }

    private func moon(opacity: Double, scale: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(AppColor.midnight)
                .frame(width: 28 * scale, height: 28 * scale)
            Circle()
                .fill(AppColor.moonLit)
                .frame(width: 22 * scale, height: 22 * scale)
            Circle()
                .fill(AppColor.primaryContainer)
                .frame(width: 8 * scale, height: 8 * scale)
        }
        .scaleEffect(0.94 + 0.06 * opacity)
        .opacity(opacity)
    }

    private func orbitBody(at t: CGFloat, in bounds: CGRect, diameter: CGFloat, color: Color, opacity: Double) -> some View {
        Circle()
            .fill(color)
            .frame(width: diameter, height: diameter)
            .position(LaunchOrbit.point(t: t, in: bounds))
            .opacity(opacity)
    }

    private func stars(in size: CGSize) -> some View {
        let appear = launchProgress(0.04...0.62, at: time)
        return ZStack {
            ForEach(Array(LaunchStar.field.enumerated()), id: \.offset) { index, star in
                Circle()
                    .fill(AppColor.charcoal.opacity(star.alpha * appear))
                    .frame(width: star.size, height: star.size)
                    .position(x: size.width * star.x, y: size.height * star.y)
                    .opacity(index.isMultiple(of: 2) ? 1 : 0.85 + 0.15 * appear)
            }
        }
        .allowsHitTesting(false)
    }

    private var wordmark: some View {
        let appear = launchProgress(LaunchTiming.word, at: time)
        return Text("ASTROAI")
            .font(.title3.weight(.semibold))
            .tracking(CGFloat(lerp(8, 2.5, appear)))
            .foregroundStyle(AppColor.onSurface)
            .opacity(appear)
            .offset(y: CGFloat(lerp(8, 0, appear)))
            .accessibilityHidden(true)
    }
}

/// Tilted orbit from the celestial mark, drawn in a square that maps 0...100.
private struct LaunchOrbit: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 100
        let orbit = CGRect(x: 12 * scale, y: 34 * scale, width: 76 * scale, height: 32 * scale)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path(ellipseIn: orbit)
        path = path.applying(
            CGAffineTransform(translationX: -center.x, y: -center.y)
                .concatenating(CGAffineTransform(rotationAngle: -25 * .pi / 180))
                .concatenating(CGAffineTransform(translationX: center.x, y: center.y))
        )
        return path
    }

    /// Point on the orbit. `t` is 0...1 clockwise from the right of the unrotated ellipse.
    static func point(t: CGFloat, in rect: CGRect) -> CGPoint {
        let scale = min(rect.width, rect.height) / 100
        let radiusX = 38 * scale
        let radiusY = 16 * scale
        let theta = t * 2 * .pi
        let local = CGPoint(x: radiusX * cos(theta), y: radiusY * sin(theta))
        let tilt = -25 * CGFloat.pi / 180
        let rotated = CGPoint(
            x: local.x * cos(tilt) - local.y * sin(tilt),
            y: local.x * sin(tilt) + local.y * cos(tilt)
        )
        return CGPoint(x: rect.midX + rotated.x, y: rect.midY + rotated.y)
    }
}

private struct LaunchStar {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let alpha: Double

    static let field: [LaunchStar] = [
        .init(x: 0.16, y: 0.12, size: 2.2, alpha: 0.45),
        .init(x: 0.78, y: 0.10, size: 1.6, alpha: 0.32),
        .init(x: 0.90, y: 0.22, size: 2.4, alpha: 0.40),
        .init(x: 0.08, y: 0.30, size: 1.5, alpha: 0.28),
        .init(x: 0.84, y: 0.36, size: 1.8, alpha: 0.30),
        .init(x: 0.12, y: 0.58, size: 2.0, alpha: 0.34),
        .init(x: 0.88, y: 0.62, size: 1.4, alpha: 0.26),
        .init(x: 0.22, y: 0.78, size: 1.7, alpha: 0.30),
        .init(x: 0.70, y: 0.84, size: 2.2, alpha: 0.36),
        .init(x: 0.48, y: 0.90, size: 1.5, alpha: 0.24),
        .init(x: 0.34, y: 0.16, size: 1.3, alpha: 0.22)
    ]
}

// MARK: - Curves

private func launchProgress(
    _ range: ClosedRange<Double>,
    at time: Double,
    curve: (Double) -> Double = easeOutCubic
) -> Double {
    let span = range.upperBound - range.lowerBound
    guard span > 0 else { return time >= range.lowerBound ? 1 : 0 }
    let raw = min(max((time - range.lowerBound) / span, 0), 1)
    return curve(raw)
}

private func easeOutCubic(_ t: Double) -> Double {
    1 - pow(1 - t, 3)
}

private func easeInOutCubic(_ t: Double) -> Double {
    t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
}

private func lerp(_ from: Double, _ to: Double, _ t: Double) -> Double {
    from + (to - from) * t
}

#Preview {
    LaunchAnimationView(onFinished: {})
}
