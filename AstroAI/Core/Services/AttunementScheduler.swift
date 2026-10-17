//
//  AttunementScheduler.swift
//  AstroAI
//

import Foundation
import UserNotifications
import WidgetKit

/// The lock-screen line. The widget reads the same JSON from the shared app group.
struct AttunementSnapshot: Codable {
    var moonGlyph: String
    var moonLine: String
    var transitLine: String
    var updated: Date
}

enum WidgetSnapshotStore {
    static let suite = "group.com.BogdanArsenkin.AstroAI"
    private static let key = "attunement.snapshot"

    static func save(_ snapshot: AttunementSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults(suiteName: suite)?.set(data, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func clear() {
        UserDefaults(suiteName: suite)?.removeObject(forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

protocol AttunementScheduling: AnyObject {
    /// Rebuilds the widget and the pending notifications without reporting permission state.
    func refresh()
    /// Rebuilds them and returns a sentence when iOS is blocking delivery.
    func sync() async -> String?
    func clear()
}

/// Local notifications and the lock-screen snapshot. Nothing leaves the phone.
final class AttunementScheduler: AttunementScheduling {
    private let astrology: AstrologyServicing
    private let userService: UserServicing
    private let preferences: PreferencesServicing
    private var ticket = 0

    init(astrology: AstrologyServicing, userService: UserServicing, preferences: PreferencesServicing) {
        self.astrology = astrology
        self.userService = userService
        self.preferences = preferences
    }

    func refresh() {
        Task { _ = await sync() }
    }

    func sync() async -> String? {
        ticket += 1
        return await run(ticket)
    }

    func clear() {
        ticket += 1
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        WidgetSnapshotStore.clear()
    }

    // MARK: - Run

    private func run(_ current: Int) async -> String? {
        let options = astrology.chartOptions
        let chart = userService.profile.map { NatalChartCalculator.chart(for: $0.birth, options: options) }
        guard current == ticket else { return nil }
        WidgetSnapshotStore.save(snapshot(chart: chart, options: options))

        let prefs = preferences.load()
        let center = UNUserNotificationCenter.current()
        let wants = prefs.morningAttunement || prefs.exactAspects || prefs.lunarPhases
        guard current == ticket else { return nil }
        center.removeAllPendingNotificationRequests()
        guard wants else { return nil }
        guard current == ticket else { return nil }

        let settings = await center.notificationSettings()
        guard current == ticket else { return nil }
        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard current == ticket else { return nil }
            guard granted else {
                return "Notifications are off, so the morning attunement stays in the app."
            }
        case .denied:
            return "Notifications are off in iOS Settings, so the morning attunement stays in the app."
        case .authorized, .provisional, .ephemeral:
            break
        @unknown default:
            break
        }

        if prefs.morningAttunement {
            await scheduleMornings(chart: chart, options: options, prefs: prefs, center: center, current: current)
        }
        if prefs.exactAspects, let chart {
            await scheduleExact(chart: chart, options: options, prefs: prefs, center: center, current: current)
        }
        if prefs.lunarPhases {
            await scheduleMoon(options: options, prefs: prefs, center: center, current: current)
        }
        return nil
    }

    private func snapshot(chart: NatalChart?, options: ChartOptions) -> AttunementSnapshot {
        let sky = TransitCalculator.sky(at: .now, natal: chart, options: options)
        let sign = sky.position(of: .moon)?.sign
        let transit = sky.keyTransit.map { "\($0.transiting.name) \($0.kind.glyph) natal \($0.natal.name)" } ?? sky.moonPhase.name
        return AttunementSnapshot(
            moonGlyph: sign?.glyph ?? "☽",
            moonLine: sign.map { "Moon in \($0.name)" } ?? "Moon",
            transitLine: chart == nil ? sky.moonPhase.name : transit,
            updated: .now
        )
    }

    // MARK: - Mornings

    private func scheduleMornings(
        chart: NatalChart?,
        options: ChartOptions,
        prefs: Preferences,
        center: UNUserNotificationCenter,
        current: Int
    ) async {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: .now)
        if let thisMorning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day), thisMorning <= .now {
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        }
        for offset in 0..<7 {
            guard current == ticket else { return }
            guard let date = calendar.date(byAdding: .day, value: offset, to: day),
                  let morning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: date) else { continue }
            let sky = TransitCalculator.sky(at: morning, natal: chart, options: options)
            let moon = sky.position(of: .moon)?.sign.name ?? "the sky"
            let body: String
            if let transit = sky.keyTransit {
                body = "Moon in \(moon). \(transit.transiting.name) \(SkyPeaks.word(transit.kind)) your \(transit.natal.name)."
            } else {
                body = "Moon in \(moon). \(sky.moonPhase.name)."
            }
            await add(
                id: "morning-\(Self.dayKey(morning))",
                title: "Morning attunement",
                body: body,
                at: morning,
                prefs: prefs,
                center: center,
                current: current
            )
        }
    }

    // MARK: - Exact aspects

    private func scheduleExact(
        chart: NatalChart,
        options: ChartOptions,
        prefs: Preferences,
        center: UNUserNotificationCenter,
        current: Int
    ) async {
        let peaks = PersonalTransitForecast.exactPeaks(
            chart: chart,
            options: options,
            from: .now,
            until: Date.now.addingTimeInterval(4 * 86_400)
        )
        var scheduled = 0
        for peak in peaks where scheduled < 3 {
            guard current == ticket else { return }
            let added = await add(
                id: "exact-\(peak.id)",
                title: peak.title,
                body: "\(peak.houseLine). \(peak.advice)",
                at: peak.when,
                prefs: prefs,
                center: center,
                current: current
            )
            if added { scheduled += 1 }
        }
    }

    // MARK: - Moon

    private func scheduleMoon(
        options: ChartOptions,
        prefs: Preferences,
        center: UNUserNotificationCenter,
        current: Int
    ) async {
        let horizon = Date.now.addingTimeInterval(7 * 86_400)
        var cursor = Date.now
        var announcedPhase = false
        for _ in 0..<3 {
            guard current == ticket, cursor < horizon else { return }
            let motion = MoonMotionCalculator.make(at: cursor, options: options)
            guard motion.ingress < horizon else { return }
            let void = motion.voidBegins != nil
            let body = void
                ? "Void of course ends as the Moon enters \(motion.nextSign.name)."
                : "The mood shifts toward \(motion.nextSign.qualities) themes."
            await add(
                id: "ingress-\(Int(motion.ingress.timeIntervalSince1970))",
                title: "Moon enters \(motion.nextSign.name)",
                body: body,
                at: motion.ingress,
                prefs: prefs,
                center: center,
                current: current
            )
            if !announcedPhase, let phase = motion.nextPhase, let name = motion.nextPhaseName, phase < horizon {
                let sign = ZodiacSign.containing(SkyPeaks.longitude(of: .moon, at: phase, options: options))
                await add(
                    id: "phase-\(Int(phase.timeIntervalSince1970))",
                    title: "\(name) in \(sign.name)",
                    body: "The Moon reaches \(name.lowercased()) in \(sign.name).",
                    at: phase,
                    prefs: prefs,
                    center: center,
                    current: current
                )
                announcedPhase = true
            }
            cursor = motion.ingress.addingTimeInterval(60 * 60)
        }
    }

    // MARK: - Delivery

    /// Returns false when the moment falls inside the quiet window or the request was superseded.
    @discardableResult
    private func add(
        id: String,
        title: String,
        body: String,
        at date: Date,
        prefs: Preferences,
        center: UNUserNotificationCenter,
        current: Int
    ) async -> Bool {
        guard current == ticket, date > .now, !isQuiet(date, prefs: prefs) else { return false }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        )
        do {
            try await center.add(request)
        } catch {
            return false
        }
        guard current == ticket else {
            center.removePendingNotificationRequests(withIdentifiers: [id])
            return false
        }
        return true
    }

    /// 22:00–07:30, matching the quiet-window control.
    private func isQuiet(_ date: Date, prefs: Preferences) -> Bool {
        guard prefs.quietWindow else { return false }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        return minutes >= 22 * 60 || minutes < 7 * 60 + 30
    }

    private static func dayKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
