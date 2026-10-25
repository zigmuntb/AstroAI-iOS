//
//  OnDeviceOracleSupportTests.swift
//  AstroAITests
//

import FoundationModels
import XCTest
@testable import AstroAI

final class OnDeviceOracleSupportTests: XCTestCase {
    func testTurnedOffAppleIntelligenceUsesTheDownloadableModel() {
        XCTAssertFalse(OnDeviceOracleService.supports(.unavailable(.appleIntelligenceNotEnabled)))
        XCTAssertFalse(OnDeviceOracleService.supports(.unavailable(.deviceNotEligible)))
    }

    func testReadyOrDownloadingAppleIntelligenceStaysOnDevice() {
        XCTAssertTrue(OnDeviceOracleService.supports(.available))
        XCTAssertTrue(OnDeviceOracleService.supports(.unavailable(.modelNotReady)))
    }
}
