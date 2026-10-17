//
//  Ephemeris.swift
//  AstroAI
//

import AstronomyEngine
import Foundation

/// Geocentric tropical positions computed on-device with Astronomy Engine (±1 arcminute).
nonisolated enum Ephemeris {
    struct Position: Hashable {
        let planet: Planet
        /// Ecliptic longitude 0..<360, tropical zodiac.
        let longitude: Double
        let isRetrograde: Bool

        var sign: ZodiacSign { ZodiacSign.containing(longitude) }
        var degreeInSign: Double { longitude.truncatingRemainder(dividingBy: 30) }
    }

    struct Angles: Hashable {
        let ascendant: Double
        let midheaven: Double
    }

    static let bodies: [Planet] = [.sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn, .uranus, .neptune, .pluto]

    /// Positions of the Sun, Moon, planets and the mean North Node at `date`.
    static func positions(at date: Date) -> [Position] {
        let time = astroTime(date)
        var result = bodies.map { planet in
            let now = longitude(of: planet, at: time)
            let later = longitude(of: planet, at: Astronomy_AddDays(time, 0.5))
            return Position(planet: planet, longitude: now, isRetrograde: signedDifference(later, now) < 0)
        }
        result.append(Position(planet: .northNode, longitude: meanNode(at: time), isRetrograde: true))
        return result
    }

    static func position(of planet: Planet, at date: Date) -> Position? {
        positions(at: date).first { $0.planet == planet }
    }

    /// Ascendant and Midheaven for an observer at the given coordinates.
    static func angles(at date: Date, latitude: Double, longitude: Double) -> Angles {
        var time = astroTime(date)
        let siderealHours = Astronomy_SiderealTime(&time)
        let ramc = radians(normalized(siderealHours * 15 + longitude))
        let obliquity = radians(obliquityDegrees(at: time))
        let phi = radians(latitude)

        let ascendant = atan2(cos(ramc), -(sin(ramc) * cos(obliquity) + tan(phi) * sin(obliquity)))
        let midheaven = atan2(sin(ramc), cos(ramc) * cos(obliquity))
        return Angles(ascendant: normalized(degrees(ascendant)), midheaven: normalized(degrees(midheaven)))
    }

    /// Osculating ("true") lunar ascending node: where the Moon's instantaneous orbital plane
    /// crosses the ecliptic of date.
    static func trueNode(at date: Date) -> Double {
        let time = astroTime(date)
        let r1 = eclipticVector(of: BODY_MOON, at: time)
        let r2 = eclipticVector(of: BODY_MOON, at: Astronomy_AddDays(time, 1.0 / 24))
        let h = (x: r1.y * r2.z - r1.z * r2.y, y: r1.z * r2.x - r1.x * r2.z)
        return normalized(degrees(atan2(h.x, -h.y)))
    }

    /// Fagan/Bradley ayanamsa: offset between the tropical and sidereal zodiacs.
    static func ayanamsa(at date: Date) -> Double {
        let years = (date.timeIntervalSince1970 - 946_728_000) / 31_557_600
        return 24.736 + years * 50.29 / 3600
    }

    /// Twelve house cusps (cusp 1 = Ascendant), expressed in a zodiac shifted back by `zodiacOffset`
    /// (the ayanamsa for sidereal charts). `nil` when Placidus is undefined (polar latitudes).
    static func houseCusps(_ system: HouseSystem, at date: Date, latitude: Double, longitude: Double, zodiacOffset: Double = 0) -> [Double]? {
        let angles = angles(at: date, latitude: latitude, longitude: longitude)
        let ascendant = normalized(angles.ascendant - zodiacOffset)
        switch system {
        case .wholeSign:
            let first = Double(Int(ascendant / 30) * 30)
            return (0..<12).map { normalized(first + Double($0) * 30) }
        case .equal:
            return (0..<12).map { normalized(ascendant + Double($0) * 30) }
        case .placidus:
            var time = astroTime(date)
            let ramc = normalized(Astronomy_SiderealTime(&time) * 15 + longitude)
            let obliquity = radians(obliquityDegrees(at: time))
            guard abs(latitude) < 66,
                  let c11 = placidusCusp(ramc: ramc, fraction: 1.0 / 3, above: true, latitude: latitude, obliquity: obliquity),
                  let c12 = placidusCusp(ramc: ramc, fraction: 2.0 / 3, above: true, latitude: latitude, obliquity: obliquity),
                  let c2 = placidusCusp(ramc: ramc, fraction: 2.0 / 3, above: false, latitude: latitude, obliquity: obliquity),
                  let c3 = placidusCusp(ramc: ramc, fraction: 1.0 / 3, above: false, latitude: latitude, obliquity: obliquity)
            else { return nil }
            let asc = angles.ascendant
            let mc = angles.midheaven
            let firstHalf = [asc, c2, c3, normalized(mc + 180), normalized(c11 + 180), normalized(c12 + 180)]
            return (firstHalf + firstHalf.map { $0 + 180 }).map { normalized($0 - zodiacOffset) }
        }
    }

    /// Placidus intermediate cusp: the ecliptic point that has covered `fraction` of its
    /// semi-arc from the meridian. Above the horizon cusps 11/12, below cusps 2/3.
    private static func placidusCusp(ramc: Double, fraction: Double, above: Bool, latitude: Double, obliquity: Double) -> Double? {
        let phi = radians(latitude)
        var ra = above ? ramc + 90 * fraction : ramc + 180 - 90 * fraction
        for _ in 0..<50 {
            let lambda = atan2(sin(radians(ra)), cos(radians(ra)) * cos(obliquity))
            let delta = asin(sin(obliquity) * sin(lambda))
            let x = -tan(phi) * tan(delta)
            guard abs(x) <= 1 else { return nil }
            let diurnal = degrees(acos(x))
            let next = above ? ramc + fraction * diurnal : ramc + 180 - fraction * (180 - diurnal)
            if abs(Ephemeris.signedDifference(next, ra)) < 1e-7 { ra = next; break }
            ra = next
        }
        return normalized(degrees(atan2(sin(radians(ra)), cos(radians(ra)) * cos(obliquity))))
    }

    /// Declination relative to the true equator of date, in degrees (north positive).
    static func declination(of planet: Planet, at date: Date) -> Double? {
        guard let body = body(for: planet) else { return nil }
        var time = astroTime(date)
        let j2000 = Astronomy_GeoVector(body, time, ABERRATION)
        let ofDate = Astronomy_RotateVector(Astronomy_Rotation_EQJ_EQD(&time), j2000)
        return Astronomy_EquatorFromVector(ofDate).dec
    }

    /// Obliquity of the ecliptic at `date`; declinations beyond it are "out of bounds".
    static func obliquity(at date: Date) -> Double {
        obliquityDegrees(at: astroTime(date))
    }

    struct SolarEclipse: Hashable {
        let date: Date
        /// "Total", "Annular" or "Partial".
        let kind: String
    }

    /// Tropical ecliptic longitude of one body. Cheaper than `positions(at:)` when only one planet is needed.
    static func tropicalLongitude(of planet: Planet, at date: Date) -> Double {
        let time = astroTime(date)
        if planet == .northNode { return meanNode(at: time) }
        return longitude(of: planet, at: time)
    }

    /// The next global solar eclipses after `date`, earliest first.
    static func upcomingSolarEclipses(from date: Date, count: Int) -> [SolarEclipse] {
        guard count > 0 else { return [] }
        var eclipse = Astronomy_SearchGlobalSolarEclipse(astroTime(date))
        var found: [SolarEclipse] = []
        var previous = Date.distantPast
        var guardrail = 0
        while eclipse.status == ASTRO_SUCCESS, found.count < count, guardrail < count + 4 {
            guardrail += 1
            let when = dateFromUT(eclipse.peak.ut)
            guard when > previous else { break }
            previous = when
            if when >= date.addingTimeInterval(-3_600) {
                found.append(SolarEclipse(date: when, kind: solarEclipseKind(eclipse.kind)))
            }
            eclipse = Astronomy_NextGlobalSolarEclipse(eclipse.peak)
        }
        return found
    }

    /// Smallest signed angle from `b` to `a`, in -180..<180.
    static func signedDifference(_ a: Double, _ b: Double) -> Double {
        var diff = (a - b).truncatingRemainder(dividingBy: 360)
        if diff >= 180 { diff -= 360 }
        if diff < -180 { diff += 360 }
        return diff
    }

    static func separation(_ a: Double, _ b: Double) -> Double {
        abs(signedDifference(a, b))
    }

    // MARK: - Private

    private static func astroTime(_ date: Date) -> astro_time_t {
        // Astronomy Engine counts UT days from 2000-01-01 12:00 UTC.
        Astronomy_TimeFromDays((date.timeIntervalSince1970 - 946_728_000) / 86_400)
    }

    private static func longitude(of planet: Planet, at time: astro_time_t) -> Double {
        guard let body = body(for: planet) else { return 0 }
        let vector = Astronomy_GeoVector(body, time, ABERRATION)
        return normalized(Astronomy_Ecliptic(vector).elon)
    }

    private static func eclipticVector(of body: astro_body_t, at time: astro_time_t) -> (x: Double, y: Double, z: Double) {
        let vector = Astronomy_Ecliptic(Astronomy_GeoVector(body, time, NO_ABERRATION)).vec
        return (vector.x, vector.y, vector.z)
    }

    private static func body(for planet: Planet) -> astro_body_t? {
        switch planet {
        case .sun: BODY_SUN
        case .moon: BODY_MOON
        case .mercury: BODY_MERCURY
        case .venus: BODY_VENUS
        case .mars: BODY_MARS
        case .jupiter: BODY_JUPITER
        case .saturn: BODY_SATURN
        case .uranus: BODY_URANUS
        case .neptune: BODY_NEPTUNE
        case .pluto: BODY_PLUTO
        case .ascendant, .northNode: nil
        }
    }

    /// Mean lunar ascending node (Meeus, Astronomical Algorithms, ch. 47).
    private static func meanNode(at time: astro_time_t) -> Double {
        let t = time.tt / 36_525
        return normalized(125.0445479 - 1934.1362891 * t + 0.0020754 * t * t + t * t * t / 467_441)
    }

    /// Mean obliquity of the ecliptic (IAU 1980); precise enough for house angles.
    private static func obliquityDegrees(at time: astro_time_t) -> Double {
        let t = time.tt / 36_525
        return 23.439291 - 0.0130042 * t - 1.64e-7 * t * t + 5.04e-7 * t * t * t
    }

    private static func normalized(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }

    /// Inverse of `astroTime`: Astronomy Engine counts UT days from 2000-01-01 12:00 UTC.
    private static func dateFromUT(_ ut: Double) -> Date {
        Date(timeIntervalSince1970: ut * 86_400 + 946_728_000)
    }

    private static func solarEclipseKind(_ kind: astro_eclipse_kind_t) -> String {
        if kind == ECLIPSE_TOTAL { return "Total" }
        if kind == ECLIPSE_ANNULAR { return "Annular" }
        return "Partial"
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    private static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
}

extension ZodiacSign {
    nonisolated static func containing(_ longitude: Double) -> ZodiacSign {
        let index = Int(longitude / 30) % 12
        return allCases[(index + 12) % 12]
    }
}
