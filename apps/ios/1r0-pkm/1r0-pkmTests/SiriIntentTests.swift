//
//  SiriIntentTests.swift
//  1r0-pkmTests
//
//  ADR-0014: gli App Intent leggono i RoutineDay e avviano una
//  WorkoutSession come l'avvio manuale. Container in-memory sostituito in
//  GymData.
//

import XCTest
import SwiftData
@testable import _r0_pkm

@MainActor
final class SiriIntentTests: XCTestCase {

    override func setUpWithError() throws {
        GymData.container = try ModelContainer(
            for: GymData.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func seedDay(_ dayName: String, _ routineName: String) throws -> RoutineDay {
        let ctx = GymData.container.mainContext
        let r = Routine(name: routineName)
        ctx.insert(r)
        let d = RoutineDay(routine: r, name: dayName, orderIndex: 0)
        ctx.insert(d)
        try ctx.save()
        return d
    }

    func testStartWorkoutIntent_fromRoutineDay() async throws {
        let d = try seedDay("Pull", "PPL")
        var intent = StartWorkoutIntent()
        intent.day = RoutineDayEntity(id: d.id, dayName: "Pull", routineName: "PPL")

        _ = try await intent.perform()

        let ctx = GymData.container.mainContext
        let sessions = try ctx.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.routineDayId, d.id)
        XCTAssertEqual(sessions.first?.source, "app")
        XCTAssertEqual(sessions.first?.status, .active)

        let payloads = try ctx.fetch(FetchDescriptor<OutboxEntry>())
            .filter { $0.kind == "session.create" }
        XCTAssertEqual(payloads.count, 1)
        let json = try JSONSerialization.jsonObject(with: payloads[0].payload) as? [String: Any]
        XCTAssertEqual(json?["routineDayId"] as? String, d.id.uuidString)
    }

    func testStartWorkoutIntent_freeSessionWhenNoDay() async throws {
        var intent = StartWorkoutIntent()
        intent.day = nil
        _ = try await intent.perform()

        let s = try GymData.container.mainContext.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(s.count, 1)
        XCTAssertNil(s.first?.routineDayId)
    }

    func testRoutineDayQuery_suggestsAllDays() async throws {
        _ = try seedDay("Push", "PPL")
        _ = try seedDay("Legs", "PPL")
        let suggested = try await RoutineDayQuery().suggestedEntities()
        XCTAssertEqual(Set(suggested.map(\.dayName)), ["Push", "Legs"])
        XCTAssertEqual(suggested.first?.routineName, "PPL")
    }
}
