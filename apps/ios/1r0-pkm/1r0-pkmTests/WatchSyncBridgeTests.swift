//
//  WatchSyncBridgeTests.swift
//  1r0-pkmTests
//
//  ADR-0016: il ponte Watch→iPhone applica gli eventi di sessione a
//  SwiftData e all'outbox. Qui senza WatchConnectivity — si chiama
//  direttamente handle(). Il trasporto WC è già validato (spike #1/#6).
//

import XCTest
import SwiftData
@testable import _r0_pkm

@MainActor
final class WatchSyncBridgeTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let c = try ModelContainer(
            for: Exercise.self, Routine.self, RoutineDay.self, RoutineExercise.self,
            WorkoutSession.self, SetLogEntry.self,
            PlateConfig.self, BodyMeasurement.self, OutboxEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return c.mainContext
    }

    func testWatchSessionRoundTripThroughTheBridge() throws {
        let ctx = try makeContext()
        let bridge = WatchSyncBridge(context: ctx)
        let sid = UUID().uuidString

        bridge.handle(["type": "session.start", "id": sid])
        bridge.handle([
            "type": "setlog.create", "id": UUID().uuidString, "sessionId": sid,
            "exerciseName": "Serie libera", "setIndex": 1, "weightKg": 80.0, "reps": 5,
        ])
        bridge.handle(["type": "session.end", "id": sid, "status": "completed"])

        let sessions = try ctx.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.source, "watch")
        XCTAssertEqual(sessions.first?.status, .completed)

        let sets = try ctx.fetch(FetchDescriptor<SetLogEntry>())
        XCTAssertEqual(sets.count, 1)
        XCTAssertEqual(sets.first?.weightKg, 80)
        XCTAssertEqual(sets.first?.reps, 5)

        let exercises = try ctx.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(exercises.map(\.name), ["Serie libera"])

        // outbox: exercise.create + setlog.create + session.create + session.update
        let kinds = Set(try ctx.fetch(FetchDescriptor<OutboxEntry>()).map(\.kind))
        XCTAssertTrue(kinds.isSuperset(of: [
            "session.create", "setlog.create", "session.update", "exercise.create",
        ]), "outbox kinds mancanti: \(kinds)")
    }

    func testCancelSetsStatusCancelled() throws {
        let ctx = try makeContext()
        let bridge = WatchSyncBridge(context: ctx)
        let sid = UUID().uuidString
        bridge.handle(["type": "session.start", "id": sid])
        bridge.handle(["type": "session.end", "id": sid, "status": "cancelled"])
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<WorkoutSession>()).first?.status, .cancelled)
    }

    func testUnknownEventIsIgnored() throws {
        let ctx = try makeContext()
        let bridge = WatchSyncBridge(context: ctx)
        bridge.handle(["type": "nonsense"])
        bridge.handle([:])
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<WorkoutSession>()).count, 0)
    }
}
