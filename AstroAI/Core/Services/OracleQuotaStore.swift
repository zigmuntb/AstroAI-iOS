//
//  OracleQuotaStore.swift
//  AstroAI
//

import Foundation

/// Free Oracle inquiries used today. Survives relaunch and returns to zero at local midnight.
protocol OracleQuotaStoring: AnyObject {
    var quota: OracleQuota { get }
    func recordUse()
}

final class OracleQuotaStore: OracleQuotaStoring {
    private let storage: StorageManaging
    private let calendar: Calendar
    private let limit: Int

    init(storage: StorageManaging, calendar: Calendar = .current, limit: Int = 3) {
        self.storage = storage
        self.calendar = calendar
        self.limit = limit
    }

    var quota: OracleQuota {
        OracleQuota(used: record().used, limit: limit)
    }

    func recordUse() {
        var current = record()
        current.used += 1
        storage.save(current, for: .oracleQuota)
    }

    /// Today's count, or a fresh zero once the saved day is no longer today.
    private func record() -> OracleDailyUse {
        let start = calendar.startOfDay(for: .now)
        if let saved = storage.load(OracleDailyUse.self, for: .oracleQuota),
           calendar.isDate(saved.day, inSameDayAs: start) {
            return saved
        }
        return OracleDailyUse(day: start, used: 0)
    }
}

private struct OracleDailyUse: Codable {
    var day: Date
    var used: Int
}
