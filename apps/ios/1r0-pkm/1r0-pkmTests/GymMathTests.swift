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

    // MARK: - piastre

    private let stdPlates = [1.25, 2.5, 5, 10, 15, 20, 25.0]

    func testPlates_exactLoad() {
        // 100kg, bar 20 -> 40 per lato -> 25 + 15
        let l = GymMath.platesPerSide(targetKg: 100, barKg: 20, availablePlatesKg: stdPlates)
        XCTAssertEqual(l.perSide, [25, 15])
        XCTAssertEqual(l.achievable, 100, accuracy: 0.0001)
        XCTAssertEqual(l.leftover, 0, accuracy: 0.0001)
    }

    func testPlates_greedyWithRepeats() {
        // 142.5kg, bar 20 -> 61.25 per lato -> 25+25+10+1.25
        let l = GymMath.platesPerSide(targetKg: 142.5, barKg: 20, availablePlatesKg: stdPlates)
        XCTAssertEqual(l.perSide, [25, 25, 10, 1.25])
        XCTAssertEqual(l.achievable, 142.5, accuracy: 0.0001)
    }

    func testPlates_notFullyLoadable_reportsLeftover() {
        // 101kg, bar 20 -> 40.5 per lato -> 25+15+0.25 non caricabile
        let l = GymMath.platesPerSide(targetKg: 101, barKg: 20, availablePlatesKg: stdPlates)
        XCTAssertEqual(l.achievable, 100, accuracy: 0.0001)
        XCTAssertEqual(l.leftover, 1, accuracy: 0.0001)
    }

    func testPlates_targetBelowBar() {
        let l = GymMath.platesPerSide(targetKg: 15, barKg: 20, availablePlatesKg: stdPlates)
        XCTAssertEqual(l.perSide, [])
        XCTAssertEqual(l.achievable, 20, accuracy: 0.0001)
    }

    func testPlates_limitedDenominations() {
        // solo dischi da 20 e 10, target 120, bar 20 -> 50 per lato -> 20+20+10
        let l = GymMath.platesPerSide(targetKg: 120, barKg: 20, availablePlatesKg: [10, 20])
        XCTAssertEqual(l.perSide, [20, 20, 10])
        XCTAssertEqual(l.achievable, 120, accuracy: 0.0001)
    }

    // MARK: - warm-up

    func testWarmupRamp_percentagesAndMonotonic() {
        let ramp = GymMath.warmupRamp(workingWeightKg: 100, barKg: 20, availablePlatesKg: stdPlates)
        XCTAssertEqual(ramp.map(\.percent), [0.4, 0.6, 0.8])
        // 40kg, 60kg, 80kg tutti caricabili esattamente e crescenti
        XCTAssertEqual(ramp[0].load.achievable, 40, accuracy: 0.0001)
        XCTAssertEqual(ramp[1].load.achievable, 60, accuracy: 0.0001)
        XCTAssertEqual(ramp[2].load.achievable, 80, accuracy: 0.0001)
        XCTAssertLessThan(ramp[0].load.achievable, ramp[2].load.achievable)
    }
}
