//
//  GymStatsTests.swift
//  1r0-pkmTests
//
//  Aggregazioni per la vista storico gym (ADR-0027 step 3).
//

import XCTest
import SwiftData
@testable import _r0_pkm

@MainActor
final class GymStatsTests: XCTestCase {

    private func ctx() throws -> ModelContext {
        try ModelContainer(for: GymData.schema,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true)).mainContext
    }

    private func session(_ ctx: ModelContext, day: Int,
                         _ sets: [(ex: String, idx: Int, kg: Double, reps: Int?, warm: Bool)]) -> WorkoutSession {
        let d = Calendar.current.date(byAdding: .day, value: day, to: Date())!
        let s = WorkoutSession(startedAt: d, routineLabel: "R")
        ctx.insert(s)
        for x in sets {
            let sl = SetLogEntry(exerciseName: x.ex, setIndex: x.idx, weightKg: x.kg,
                                 reps: x.reps, isWarmup: x.warm, completedAt: d)
            sl.session = s
            ctx.insert(sl)
        }
        try? ctx.save()
        return s
    }

    func testWorkingSetsFiltersWarmupZeroAndTimeBased() throws {
        let c = try ctx()
        let s = session(c, day: -1, [
            ("Panca", 1, 40, 10, true),   // warmup
            ("Panca", 2, 0, 8, false),    // 0 kg
            ("Panca", 3, 80, nil, false), // a tempo (reps nil)
            ("Panca", 4, 80, 8, false),   // valida
        ])
        let ws = GymStats.workingSets(s.sets)
        XCTAssertEqual(ws.count, 1)
        XCTAssertEqual(ws.first?.weightKg, 80)
        XCTAssertEqual(ws.first?.reps, 8)
    }

    func testExercisesOrderedBySetCount() throws {
        let c = try ctx()
        let s = session(c, day: -1, [
            ("Squat", 1, 100, 5, false), ("Squat", 2, 100, 5, false), ("Squat", 3, 100, 5, false),
            ("Panca", 1, 80, 8, false), ("Panca", 2, 80, 8, false),
            ("Curl", 1, 15, 12, false),
        ])
        XCTAssertEqual(GymStats.exercises(in: [s]), ["Squat", "Panca", "Curl"])
    }

    func testOneRMSeriesIsChronologicalAndSkipsEmptySessions() throws {
        let c = try ctx()
        let s1 = session(c, day: -10, [("Panca", 1, 80, 5, false)])
        let s2 = session(c, day: -3,  [("Squat", 1, 120, 5, false)])   // niente Panca
        let s3 = session(c, day: -1,  [("Panca", 1, 90, 5, false)])

        let series = GymStats.oneRMSeries([s3, s2, s1], exercise: "panca")
        XCTAssertEqual(series.count, 2)
        XCTAssertTrue(series[0].date < series[1].date)
        XCTAssertEqual(series[0].value, GymMath.epley1RM(weightKg: 80, reps: 5), accuracy: 0.001)
        XCTAssertEqual(series[1].value, GymMath.epley1RM(weightKg: 90, reps: 5), accuracy: 0.001)
    }

    func testVolumeSeriesSumsWorkingSets() throws {
        let c = try ctx()
        let s = session(c, day: -1, [
            ("Panca", 1, 40, 10, true),   // warmup escluso
            ("Panca", 2, 80, 8, false),
            ("Panca", 3, 80, 6, false),
        ])
        let series = GymStats.volumeSeries([s], exercise: "Panca")
        XCTAssertEqual(series.count, 1)
        XCTAssertEqual(series[0].value, 80 * 8 + 80 * 6, accuracy: 0.001)
    }
}
