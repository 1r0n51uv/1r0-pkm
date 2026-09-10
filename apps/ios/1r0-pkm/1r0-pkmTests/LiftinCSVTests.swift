//
//  LiftinCSVTests.swift
//  1r0-pkmTests
//
//  Parser dell'export CSV Liftin' (ADR-0027 step 3). Puro, nessuna
//  dipendenza da SwiftData.
//

import XCTest
@testable import _r0_pkm

final class LiftinCSVTests: XCTestCase {

    private let header = "Date;Duration;Routine;Exercise;Set;Warmup;Weight;Reps/Time;Goal;Perception"

    func testParsesRepsAndWeightWithComma() throws {
        let csv = """
        \(header)
        2026-03-01;00:45:00;Push;Panca piana;1;false;80,5;8;8-10;7
        """
        let rows = try LiftinCSV.parse(csv)
        XCTAssertEqual(rows.count, 1)
        let r = rows[0]
        XCTAssertEqual(r.exercise, "Panca piana")
        XCTAssertEqual(r.setIndex, 1)
        XCTAssertEqual(r.weightKg, 80.5, accuracy: 0.001)
        XCTAssertEqual(r.reps, 8)
        XCTAssertNil(r.setDurationSeconds)
        XCTAssertEqual(r.perception, 7)
        XCTAssertFalse(r.isWarmup)
        XCTAssertEqual(r.routine, "Push")
        XCTAssertEqual(r.workoutDurationSeconds, 45 * 60)
    }

    func testRepsTimeAsClockBecomesDuration() throws {
        let csv = "\(header)\n2026-03-01;;;Plank;1;0;0;01:30;;"
        let r = try LiftinCSV.parse(csv)[0]
        XCTAssertNil(r.reps)
        XCTAssertEqual(r.setDurationSeconds, 90)
        XCTAssertEqual(r.weightKg, 0)
    }

    func testWarmupTruthyVariants() throws {
        let csv = """
        \(header)
        2026-03-01;;;Squat;1;true;60;5;;
        2026-03-01;;;Squat;2;1;80;5;;
        2026-03-01;;;Squat;3;x;100;5;;
        2026-03-01;;;Squat;4;no;120;5;;
        """
        let rows = try LiftinCSV.parse(csv)
        XCTAssertEqual(rows.map(\.isWarmup), [true, true, true, false])
    }

    func testColumnsFoundByNameNotPosition() throws {
        let csv = """
        Exercise;Set;Weight;Reps/Time;Date
        Stacco;1;140;5;2026-03-02
        """
        let r = try LiftinCSV.parse(csv)[0]
        XCTAssertEqual(r.exercise, "Stacco")
        XCTAssertEqual(r.weightKg, 140)
        XCTAssertEqual(r.reps, 5)
    }

    func testMissingRequiredColumnThrows() {
        let csv = "Duration;Routine;Weight\n00:10;Push;80"
        XCTAssertThrowsError(try LiftinCSV.parse(csv)) { err in
            guard case LiftinCSV.ParseError.missingColumns(let cols) = err else {
                return XCTFail("wrong error: \(err)")
            }
            XCTAssertEqual(Set(cols), ["Date", "Exercise", "Set"])
        }
    }

    func testSkipsRowsWithUnparseableDate() throws {
        let csv = """
        \(header)
        garbage;;;Panca;1;0;80;8;;
        2026-03-01;;;Panca;1;0;80;8;;
        """
        let rows = try LiftinCSV.parse(csv)
        XCTAssertEqual(rows.count, 1)
    }

    func testEmptyFileThrows() {
        XCTAssertThrowsError(try LiftinCSV.parse("   \n  ")) { err in
            XCTAssertEqual(err as? LiftinCSV.ParseError, .emptyFile)
        }
    }

    func testDurationHumanFormat() throws {
        let csv = "\(header)\n2026-03-01;1h 5m;;Panca;1;0;80;8;;"
        let r = try LiftinCSV.parse(csv)[0]
        XCTAssertEqual(r.workoutDurationSeconds, 65 * 60)
    }
}
