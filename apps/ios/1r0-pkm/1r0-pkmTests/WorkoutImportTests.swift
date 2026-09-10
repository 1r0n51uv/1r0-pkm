//
//  WorkoutImportTests.swift
//  1r0-pkmTests
//
//  Merge deduplicato del CSV Liftin' nello store locale (ADR-0027 step 3).
//

import XCTest
import SwiftData
@testable import _r0_pkm

@MainActor
final class WorkoutImportTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let c = try ModelContainer(for: GymData.schema,
                                   configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return c.mainContext
    }

    private let header = "Date;Duration;Routine;Exercise;Set;Warmup;Weight;Reps/Time;Goal;Perception"

    private func sessions(_ ctx: ModelContext) -> [WorkoutSession] {
        (try? ctx.fetch(FetchDescriptor<WorkoutSession>())) ?? []
    }
    private func sets(_ ctx: ModelContext) -> [SetLogEntry] {
        (try? ctx.fetch(FetchDescriptor<SetLogEntry>())) ?? []
    }

    func testFreshImportCreatesSessionsAndSets() throws {
        let ctx = try makeContext()
        let csv = """
        \(header)
        2026-03-01;00:50:00;Push;Panca piana;1;true;40;10;;
        2026-03-01;00:50:00;Push;Panca piana;2;false;80;8;;7
        2026-03-01;00:50:00;Push;Alzate laterali;1;false;12;15;;
        2026-03-03;;Pull;Stacco;1;false;140;5;;
        """
        let s = try WorkoutImport.merge(csv: csv, into: ctx)
        XCTAssertEqual(s.sessionsCreated, 2)
        XCTAssertEqual(s.setsCreated, 4)
        XCTAssertEqual(sessions(ctx).count, 2)
        XCTAssertEqual(sets(ctx).count, 4)

        let push = sessions(ctx).first { $0.routineLabel == "Push" }
        XCTAssertEqual(push?.durationSeconds, 50 * 60)
        XCTAssertEqual(push?.sets.count, 3)
        let warmup = push?.sets.first { $0.setIndex == 1 && $0.exerciseKey == "panca piana" }
        XCTAssertEqual(warmup?.isWarmup, true)
        XCTAssertEqual(warmup?.weightKg, 40)
    }

    func testReimportSameCsvIsIdempotent() throws {
        let ctx = try makeContext()
        let csv = """
        \(header)
        2026-03-01;;Push;Panca piana;1;false;80;8;;
        2026-03-01;;Push;Panca piana;2;false;80;7;;
        """
        _ = try WorkoutImport.merge(csv: csv, into: ctx)
        let second = try WorkoutImport.merge(csv: csv, into: ctx)

        XCTAssertEqual(second.sessionsCreated, 0)
        XCTAssertEqual(second.setsCreated, 0)
        XCTAssertEqual(second.setsUpdated, 0)
        XCTAssertEqual(sessions(ctx).count, 1)
        XCTAssertEqual(sets(ctx).count, 2)
    }

    func testReimportWithChangedWeightUpdatesInPlace() throws {
        let ctx = try makeContext()
        let v1 = "\(header)\n2026-03-01;;Push;Panca piana;1;false;80;8;;"
        let v2 = "\(header)\n2026-03-01;;Push;Panca piana;1;false;82,5;8;;"
        _ = try WorkoutImport.merge(csv: v1, into: ctx)
        let s = try WorkoutImport.merge(csv: v2, into: ctx)

        XCTAssertEqual(s.setsUpdated, 1)
        XCTAssertEqual(s.setsCreated, 0)
        XCTAssertEqual(sets(ctx).count, 1)
        XCTAssertEqual(sets(ctx).first?.weightKg, 82.5)
        XCTAssertNil(sets(ctx).first?.syncedAt)
    }

    func testAddedSetRowOnReimport() throws {
        let ctx = try makeContext()
        let v1 = "\(header)\n2026-03-01;;Push;Panca;1;false;80;8;;"
        let v2 = """
        \(header)
        2026-03-01;;Push;Panca;1;false;80;8;;
        2026-03-01;;Push;Panca;2;false;80;6;;
        """
        _ = try WorkoutImport.merge(csv: v1, into: ctx)
        let s = try WorkoutImport.merge(csv: v2, into: ctx)
        XCTAssertEqual(s.setsCreated, 1)
        XCTAssertEqual(sets(ctx).count, 2)
    }

    func testTimeBasedSetHasNoReps() throws {
        let ctx = try makeContext()
        let csv = "\(header)\n2026-03-01;;Core;Plank;1;false;0;01:00;;"
        _ = try WorkoutImport.merge(csv: csv, into: ctx)
        let set = try XCTUnwrap(sets(ctx).first)
        XCTAssertNil(set.reps)
        XCTAssertEqual(set.durationSeconds, 60)
    }

    func testSameDayDifferentRoutineIsTwoSessions() throws {
        let ctx = try makeContext()
        let csv = """
        \(header)
        2026-03-01;;Morning;Panca;1;false;80;8;;
        2026-03-01;;Evening;Stacco;1;false;140;5;;
        """
        let s = try WorkoutImport.merge(csv: csv, into: ctx)
        XCTAssertEqual(s.sessionsCreated, 2)
        XCTAssertEqual(sessions(ctx).count, 2)
    }

    func testExerciseNameCaseAndSpaceInsensitiveDedup() throws {
        let ctx = try makeContext()
        let v1 = "\(header)\n2026-03-01;;Push;Panca  Piana;1;false;80;8;;"
        let v2 = "\(header)\n2026-03-01;;Push;panca piana;1;false;85;8;;"
        _ = try WorkoutImport.merge(csv: v1, into: ctx)
        let s = try WorkoutImport.merge(csv: v2, into: ctx)
        XCTAssertEqual(s.setsCreated, 0)
        XCTAssertEqual(s.setsUpdated, 1)
        XCTAssertEqual(sets(ctx).count, 1)
        XCTAssertEqual(sets(ctx).first?.weightKg, 85)
    }
}
