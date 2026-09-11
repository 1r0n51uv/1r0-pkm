//
//  MissingMealReminderTests.swift
//  1r0-pkmTests
//
//  Valutazione pura di `MissingMealReminder.plan(now:context:env:)` + `MealSlotAck`
//  (ADR-0027 step 2). Nessuna dipendenza da `UNUserNotificationCenter`.
//

import XCTest
import SwiftData
@testable import _r0_pkm

@MainActor
final class MissingMealReminderTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let c = try ModelContainer(for: GymData.schema,
                                   configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return c.mainContext
    }

    private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.reminders.\(UUID().uuidString)")!
    }

    /// `now` a un'ora del giorno data, sulla data odierna.
    private func today(at hour: Int, _ minute: Int = 0) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
    }

    private func logMeal(_ slot: MealSlot, at date: Date, in ctx: ModelContext) {
        ctx.insert(MealEntry(consumedAt: date, mealSlot: slot))
        try? ctx.save()
    }

    func testEarlyMorning_allThreeSlotsPlanned() throws {
        let ctx = try makeContext()
        let rule = MissingMealReminder(acksDefaults: isolatedDefaults())
        let planned = rule.plan(now: today(at: 7), context: ctx, env: ReminderEnv())

        XCTAssertEqual(Set(planned.map { $0.userInfo["slot"] }), ["breakfast", "lunch", "dinner"])
        XCTAssertTrue(planned.allSatisfy { $0.category == .missingMeal })
        XCTAssertTrue(planned.allSatisfy { $0.fireDate > today(at: 7) })
        XCTAssertTrue(planned.allSatisfy { $0.id.hasPrefix("missing-meal.") })
    }

    func testLoggedLunch_lunchNotPlanned() throws {
        let ctx = try makeContext()
        logMeal(.lunch, at: today(at: 12, 30), in: ctx)
        let rule = MissingMealReminder(acksDefaults: isolatedDefaults())
        let planned = rule.plan(now: today(at: 7), context: ctx, env: ReminderEnv())

        XCTAssertEqual(Set(planned.map { $0.userInfo["slot"] }), ["breakfast", "dinner"])
    }

    func testYesterdaysMealDoesNotCount() throws {
        let ctx = try makeContext()
        logMeal(.dinner, at: today(at: 20).addingTimeInterval(-86_400), in: ctx)
        let rule = MissingMealReminder(acksDefaults: isolatedDefaults())
        let planned = rule.plan(now: today(at: 7), context: ctx, env: ReminderEnv())

        XCTAssertTrue(planned.contains { $0.userInfo["slot"] == "dinner" })
    }

    func testAckedSlot_notPlanned() throws {
        let ctx = try makeContext()
        let defaults = isolatedDefaults()
        MealSlotAck.record(slotRaw: "breakfast", dayStamp: MealSlotAck.stamp(Date()), defaults: defaults)
        let rule = MissingMealReminder(acksDefaults: defaults)
        let planned = rule.plan(now: today(at: 7), context: ctx, env: ReminderEnv())

        XCTAssertFalse(planned.contains { $0.userInfo["slot"] == "breakfast" })
        XCTAssertEqual(Set(planned.map { $0.userInfo["slot"] }), ["lunch", "dinner"])
    }

    func testLateEvening_nothingPlanned() throws {
        let ctx = try makeContext()
        let rule = MissingMealReminder(acksDefaults: isolatedDefaults())
        let planned = rule.plan(now: today(at: 23), context: ctx, env: ReminderEnv())

        XCTAssertTrue(planned.isEmpty, "tutti gli orari attesi + tolleranza sono passati")
    }

    func testMealSlotAck_roundTripAndIsolation() {
        let a = UserDefaults(suiteName: "test.ack.\(UUID().uuidString)")!
        let stamp = MealSlotAck.stamp(Date())
        XCTAssertFalse(MealSlotAck.isAcked(slotRaw: "lunch", dayStamp: stamp, defaults: a))
        MealSlotAck.record(slotRaw: "lunch", dayStamp: stamp, defaults: a)
        XCTAssertTrue(MealSlotAck.isAcked(slotRaw: "lunch", dayStamp: stamp, defaults: a))
        XCTAssertFalse(MealSlotAck.isAcked(slotRaw: "dinner", dayStamp: stamp, defaults: a))
    }

    func testMealSlotAck_prunesOldEntries() {
        let a = UserDefaults(suiteName: "test.ack.\(UUID().uuidString)")!
        let now = Date()
        let old = MealSlotAck.stamp(now.addingTimeInterval(-10 * 86_400))
        MealSlotAck.record(slotRaw: "lunch", dayStamp: old, defaults: a)
        // una scrittura successiva "oggi" pota i token vecchi
        MealSlotAck.record(slotRaw: "dinner", dayStamp: MealSlotAck.stamp(now), now: now, defaults: a)

        XCTAssertFalse(MealSlotAck.isAcked(slotRaw: "lunch", dayStamp: old, defaults: a))
        XCTAssertTrue(MealSlotAck.isAcked(slotRaw: "dinner", dayStamp: MealSlotAck.stamp(now), defaults: a))
    }
}
