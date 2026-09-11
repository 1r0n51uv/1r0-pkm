//
//  WaterReminderTests.swift
//  1r0-pkmTests
//
//  Valutazione pura di `WaterReminder.plan(now:context:env:)` (ADR-0027
//  step 4).
//

import XCTest
import SwiftData
@testable import _r0_pkm

@MainActor
final class WaterReminderTests: XCTestCase {

    private func ctx() throws -> ModelContext {
        try ModelContainer(for: GymData.schema,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true)).mainContext
    }
    private func at(_ h: Int, _ m: Int = 0) -> Date {
        Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date())!
    }
    private func addWater(_ ml: Double, at date: Date, in c: ModelContext) {
        c.insert(WaterLog(loggedAt: date, amountMl: ml))
        try? c.save()
    }

    func testUnderQuotaSchedulesOneNudge() throws {
        let c = try ctx()
        addWater(200, at: at(9), in: c)                 // molto sotto
        let planned = WaterReminder().plan(now: at(13), context: c, env: ReminderEnv())
        XCTAssertEqual(planned.count, 1)
        XCTAssertEqual(planned.first?.category, .water)
        XCTAssertTrue(planned.first!.userInfo.isEmpty)  // nessuna azione
        XCTAssertTrue(planned.first!.id.hasPrefix("water."))
        XCTAssertTrue(planned.first!.fireDate > at(13))
    }

    func testAtQuotaSchedulesNothing() throws {
        let c = try ctx()
        // fascia 8–22, prossimo check dopo le 13 è alle 14 → quota ~ 6/14 * 2000
        addWater(1500, at: at(10), in: c)
        let planned = WaterReminder().plan(now: at(13), context: c, env: ReminderEnv())
        XCTAssertTrue(planned.isEmpty)
    }

    func testHealthKitWaterCountsTowardTotal() throws {
        let c = try ctx()
        addWater(300, at: at(10), in: c)
        let underNoHK = WaterReminder().plan(now: at(13), context: c, env: ReminderEnv())
        XCTAssertEqual(underNoHK.count, 1)
        let withHK = WaterReminder().plan(now: at(13), context: c,
                                          env: ReminderEnv(healthKitWaterMl: 1400))
        XCTAssertTrue(withHK.isEmpty, "300 locali + 1400 HealthKit coprono la quota")
    }

    func testAfterLastCheckHourNothing() throws {
        let c = try ctx()
        let planned = WaterReminder().plan(now: at(21, 30), context: c, env: ReminderEnv())
        XCTAssertTrue(planned.isEmpty)
    }

    func testUsesNutritionGoalTargetWhenSet() throws {
        let c = try ctx()
        c.insert(NutritionGoal(mode: .manual,
                               macros: Macros(kcal: 2000, proteinG: 150, carbsG: 200, fatG: 60),
                               waterMlTarget: 3500))
        try? c.save()
        addWater(1200, at: at(10), in: c)  // ok per 2000, sotto per 3500
        let planned = WaterReminder().plan(now: at(16), context: c, env: ReminderEnv())
        XCTAssertEqual(planned.count, 1)
    }
}
