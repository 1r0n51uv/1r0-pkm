//
//  GymMathTests.swift
//  1r0-pkmTests
//
//  Regole di dominio pure di 1r0-gym (ADR-0021: unit test dedicati).
//

import XCTest
@testable import _r0_pkm

final class GymMathTests: XCTestCase {

    func testEpley1RM_singleRep_isTheWeight() {
        XCTAssertEqual(GymMath.epley1RM(weightKg: 100, reps: 1), 100, accuracy: 0.0001)
    }

    func testEpley1RM_knownValue() {
        // 100kg × 5  ->  100 * (1 + 5/30) = 116.666…
        XCTAssertEqual(GymMath.epley1RM(weightKg: 100, reps: 5), 116.6667, accuracy: 0.001)
    }

    func testEpley1RM_moreRepsGivesHigherEstimate() {
        XCTAssertGreaterThan(
            GymMath.epley1RM(weightKg: 80, reps: 8),
            GymMath.epley1RM(weightKg: 80, reps: 3)
        )
    }

    func testEpley1RM_guards() {
        XCTAssertEqual(GymMath.epley1RM(weightKg: 100, reps: 0), 0)
        XCTAssertEqual(GymMath.epley1RM(weightKg: -10, reps: 5), 0)
        XCTAssertEqual(GymMath.epley1RM(weightKg: 0, reps: 5), 0)
    }

    func testVolume() {
        let sets: [(weightKg: Double, reps: Int)] = [(100, 5), (102.5, 5), (60, 10)]
        // 500 + 512.5 + 600
        XCTAssertEqual(GymMath.volume(sets), 1612.5, accuracy: 0.0001)
    }

    func testVolume_empty() {
        XCTAssertEqual(GymMath.volume([(weightKg: Double, reps: Int)]()), 0)
    }

    func testBestEstimated1RM_picksTheStrongestSet() {
        let sets: [(weightKg: Double, reps: Int)] = [(120, 1), (100, 5), (90, 8)]
        // 120 vs 116.67 vs 114 -> 120
        XCTAssertEqual(GymMath.bestEstimated1RM(sets), 120, accuracy: 0.001)
    }
}
