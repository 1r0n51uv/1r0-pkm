//
//  NutritionMathTests.swift
//  1r0-pkmTests
//
//  Helper puri di ADR-0019 amendata da ADR-0027: quota calorica del giorno
//  (base + energia attiva) e quota d'acqua proporzionata all'ora.
//

import XCTest
@testable import _r0_pkm

final class NutritionMathTests: XCTestCase {

    func testDailyCalorieQuotaAddsActiveEnergy() {
        XCTAssertEqual(NutritionMath.dailyCalorieQuota(baseKcal: 2000, activeEnergyKcal: 350), 2350)
    }

    func testDailyCalorieQuotaCapsBonusAndIgnoresNegative() {
        XCTAssertEqual(NutritionMath.dailyCalorieQuota(baseKcal: 2000, activeEnergyKcal: 5000,
                                                       maxBonusKcal: 1200), 3200)
        XCTAssertEqual(NutritionMath.dailyCalorieQuota(baseKcal: 2000, activeEnergyKcal: -100), 2000)
    }

    private func at(_ h: Int, _ m: Int = 0) -> Date {
        Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date())!
    }

    func testWaterQuotaZeroBeforeWindow() {
        XCTAssertEqual(NutritionMath.waterQuotaMl(targetMl: 2000, now: at(6)), 0)
    }

    func testWaterQuotaFullAfterWindow() {
        XCTAssertEqual(NutritionMath.waterQuotaMl(targetMl: 2000, now: at(23)), 2000)
    }

    func testWaterQuotaHalfwayThroughWindow() {
        // fascia default 8–22 (14h), a metà (ora 15) ⇒ metà del target
        XCTAssertEqual(NutritionMath.waterQuotaMl(targetMl: 2000, now: at(15)), 1000, accuracy: 1)
    }
}
