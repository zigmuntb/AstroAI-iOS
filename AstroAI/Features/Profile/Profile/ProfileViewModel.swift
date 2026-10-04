//
//  ProfileViewModel.swift
//  AstroAI
//

import Foundation
import Observation

@Observable
final class ProfileViewModel {
    struct BigThreeTile: Identifiable {
        var id: Planet { planet }
        let planet: Planet
        let glyph: String
        let label: String
        let sign: String
        let detail: String
    }

    struct Folio: Identifiable {
        var id: String { title }
        let icon: String
        let title: String
        let subtitle: String
        let tint: Tint
    }

    enum Tint { case champagne, aubergine, rose }

    struct Nudge: Identifiable {
        var id: String { title }
        let icon: String
        let title: String
        let text: String
        let actionTitle: String?
    }

    struct PreferenceRow: Identifiable {
        enum Trailing { case icon(String), picker(String), verified, button(String) }

        var id: String { title }
        let icon: String
        let title: String
        let subtitle: String
        let trailing: Trailing
    }

    private(set) var name = "Your Profile"
    private(set) var birthLine = ""
    private(set) var isPremium = false
    private(set) var bigThree: [BigThreeTile] = []
    private(set) var nudges: [Nudge] = []
    private(set) var houseSystem = HouseSystem.placidus.title
    private(set) var prompt: JournalPrompt
    private(set) var recentEntries: [JournalEntry] = []
    private(set) var entryCount = 0
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    let folios = [
        Folio(icon: "scalemass", title: "The Taurus-Scorpio Axis in Motion", subtitle: "Saved Oct 24 • Depth Psychological Reading", tint: .champagne),
        Folio(icon: "house", title: "4th House Anchors & Domestic Sanctuary", subtitle: "Saved Oct 21 • Natal House Analysis", tint: .aubergine),
        Folio(icon: "heart", title: "Synastry Synthesis with Julian", subtitle: "Saved Oct 19 • Dual Chart Harmony", tint: .rose)
    ]

    var preferenceRows: [PreferenceRow] {
        [
            PreferenceRow(icon: "bell.badge", title: "Notification Cadence", subtitle: "Daily Context @ 8:00 AM • Major Transits", trailing: .icon("slider.horizontal.3")),
            PreferenceRow(icon: "safari", title: "Astrological House System", subtitle: "Used for your natal chart", trailing: .picker(houseSystem)),
            PreferenceRow(icon: "gearshape.2", title: "Ephemeris Engine", subtitle: "Astronomy Engine • Calculated on-device", trailing: .verified),
            PreferenceRow(icon: "lock", title: "Privacy & Chart Encryption", subtitle: "Zero-knowledge storage • On-device keys", trailing: .button("Export"))
        ]
    }

    let footerQuote = "\u{201C}The soul moves in circles, not straight lines.\u{201D}"
    let versionLine = "AstroAI v2.4 • Ephemeris Synchronized"

    var membershipTitle: String {
        isPremium ? "AstroAI Sanctuary • Sanctuary Member" : "AstroAI Seeker • Free Member"
    }

    /// Read live from the observable user service, so the photo updates right after editing.
    var avatar: AvatarContent {
        AvatarContent(imageData: userService.avatarData, name: userService.profile?.name ?? "")
    }

    var folioCountTitle: String { "\(entryCount) Folios" }
    var viewAllTitle: String { "View All \(entryCount) Entries" }

    @ObservationIgnored private let userService: UserServicing
    @ObservationIgnored private let astrology: AstrologyServicing
    @ObservationIgnored private let journal: JournalServicing
    @ObservationIgnored private weak var router: MainRouting?

    init(userService: UserServicing, astrology: AstrologyServicing, journal: JournalServicing, router: MainRouting) {
        self.userService = userService
        self.astrology = astrology
        self.journal = journal
        self.router = router
        prompt = journal.prompt
    }

    /// Refreshes profile and journal state; called every time the screen appears.
    func load() async {
        refresh()

        guard let birth = userService.profile?.birth else {
            bigThree = Self.tiles(from: MockData.natalChart)
            return
        }
        if bigThree.isEmpty { isLoading = true }
        do {
            let chart = try await astrology.natalChart(for: birth)
            bigThree = Self.tiles(from: chart)
            houseSystem = chart.houseSystem
            errorMessage = nil
        } catch is CancellationError {
            // View disappeared, keep the previous state.
        } catch {
            errorMessage = "We couldn't calculate your chart right now."
            if bigThree.isEmpty { bigThree = Self.tiles(from: MockData.natalChart) }
        }
        isLoading = false
    }

    func refresh() {
        let profile = userService.profile
        name = (profile?.name).flatMap { $0.isEmpty ? nil : $0 } ?? "Your Profile"
        isPremium = profile?.isPremium ?? false
        birthLine = profile.map { Self.birthLine(for: $0.birth) } ?? ""
        nudges = profile.map(Self.nudges(for:)) ?? []

        prompt = journal.prompt
        let entries = journal.entries()
        entryCount = entries.count
        recentEntries = Array(entries.prefix(2))
    }

    // MARK: - Actions

    func editProfile() {
        router?.present(.editProfile)
    }

    func exploreMembership() {
        router?.present(.paywall)
    }

    func openJournal() {
        router?.show(.journal)
    }

    func openSettings() {
        router?.show(.settings)
    }

    // MARK: - Mapping

    private static func nudges(for profile: UserProfile) -> [Nudge] {
        var result: [Nudge] = []
        let birth = profile.birth
        if !birth.isTimeKnown {
            result.append(Nudge(
                icon: "clock.badge.questionmark",
                title: birth.time == nil ? "Your birth time is unknown" : "Your birth time is approximate",
                text: "Your Rising sign and houses are estimated. An exact time from a birth certificate makes every reading sharper.",
                actionTitle: nil
            ))
        }
        if profile.personal?.isEmpty ?? true {
            result.append(Nudge(
                icon: "sparkles",
                title: "Tell the Oracle about you",
                text: "Share your relationship status, life stage and what's on your mind for more personal answers.",
                actionTitle: "Add Details"
            ))
        }
        return result
    }

    private static func birthLine(for birth: BirthData) -> String {
        var date = "Born " + birth.date.formatted(.dateTime.month(.abbreviated).day().year())
        if let time = birth.time {
            date += ", " + (birth.isTimeApproximate == true ? "~" : "") + time.formatted(.dateTime.hour(.twoDigits(amPM: .abbreviated)).minute(.twoDigits))
        }
        guard let place = birth.place else { return date }
        return "\(place.title) • \(date)"
    }

    private static func tiles(from chart: NatalChart) -> [BigThreeTile] {
        chart.bigThree.map { placement in
            let house = placement.house == "Ascendant"
                ? "Asc"
                : placement.house.replacingOccurrences(of: "House ", with: "")
            return BigThreeTile(
                planet: placement.planet,
                glyph: placement.planet.glyph,
                label: placement.planet.name,
                sign: placement.sign.name,
                detail: "\(placement.degree) • \(house)"
            )
        }
    }
}
