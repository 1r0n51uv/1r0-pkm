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

    // MARK: - streak / costanza (ADR-0016)

    private func day(_ s: String, _ cal: Calendar) -> Date {
        let f = DateFormatter(); f.calendar = cal; f.timeZone = cal.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)!
    }

    func testStreak_threeConsecutiveDaysEndingToday() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let today = day("2026-09-06", cal)
        let dates = [day("2026-09-06", cal), day("2026-09-05", cal), day("2026-09-04", cal),
                     day("2026-09-01", cal)]  // buco: non conta
        XCTAssertEqual(GymMath.currentStreakDays(completedDates: dates, asOf: today, calendar: cal), 3)
    }

    func testStreak_countsFromYesterdayIfNoWorkoutToday() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let today = day("2026-09-06", cal)
        let dates = [day("2026-09-05", cal), day("2026-09-04", cal)]
        XCTAssertEqual(GymMath.currentStreakDays(completedDates: dates, asOf: today, calendar: cal), 2)
    }

    func testStreak_brokenIfLastWorkoutOlderThanYesterday() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let today = day("2026-09-06", cal)
        let dates = [day("2026-09-03", cal), day("2026-09-02", cal)]
        XCTAssertEqual(GymMath.currentStreakDays(completedDates: dates, asOf: today, calendar: cal), 0)
    }

    func testStreak_multipleSessionsSameDayCountOnce() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let today = day("2026-09-06", cal)
        let dates = [day("2026-09-06", cal), day("2026-09-06", cal), day("2026-09-05", cal)]
        XCTAssertEqual(GymMath.currentStreakDays(completedDates: dates, asOf: today, calendar: cal), 2)
    }

    func testStreak_emptyIsZero() {
        XCTAssertEqual(GymMath.currentStreakDays(completedDates: []), 0)
    }

    func testWorkoutsThisWeek() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        cal.firstWeekday = 2  // lunedì
        let now = day("2026-09-06", cal)  // domenica
        let dates = [day("2026-09-06", cal), day("2026-09-02", cal),  // stessa settimana (lun-dom)
                     day("2026-08-30", cal)]                          // settimana prima
        XCTAssertEqual(GymMath.workoutsThisWeek(completedDates: dates, asOf: now, calendar: cal), 2)
    }

    // MARK: - trend peso corporeo (ADR-0012)

    func testWeightTrend_lossOverTwoWeeks() {
        let day = 86_400.0
        let t0 = Date(timeIntervalSince1970: 0)
        let pts: [(date: Date, kg: Double)] = [
            (t0, 80), (t0.addingTimeInterval(14 * day), 78),
        ]
        let tr = GymMath.weightTrend(pts)!
        XCTAssertEqual(tr.latestKg, 78, accuracy: 0.0001)
        XCTAssertEqual(tr.deltaKg, -2, accuracy: 0.0001)
        XCTAssertEqual(tr.perWeekKg, -1, accuracy: 0.0001)   // -2 kg in 2 settimane
    }

    // MARK: - double progression (ADR-0011)

    func testRepRange_parsing() {
        XCTAssertEqual(GymMath.RepRange("8-12"), GymMath.RepRange("8-12"))
        XCTAssertEqual(GymMath.RepRange("8-12")?.min, 8)
        XCTAssertEqual(GymMath.RepRange("8-12")?.max, 12)
        XCTAssertEqual(GymMath.RepRange("5")?.min, 5)
        XCTAssertEqual(GymMath.RepRange("5")?.max, 5)
        XCTAssertNil(GymMath.RepRange("12-8"))   // invertito
        XCTAssertNil(GymMath.RepRange("abc"))
        XCTAssertNil(GymMath.RepRange("0-5"))
    }

    func testDoubleProgression_allAtTop_addsWeight() {
        let last: [(weightKg: Double, reps: Int)] = [(60, 12), (60, 12), (60, 12)]
        XCTAssertEqual(
            GymMath.doubleProgression(targetSets: 3, repRange: GymMath.RepRange("8-12")!,
                                      incrementKg: 2.5, lastSets: last),
            .addWeight(toKg: 62.5)
        )
    }

    func testDoubleProgression_completedNotAtTop_addsReps() {
        let last: [(weightKg: Double, reps: Int)] = [(60, 10), (60, 9), (60, 8)]
        XCTAssertEqual(
            GymMath.doubleProgression(targetSets: 3, repRange: GymMath.RepRange("8-12")!,
                                      incrementKg: 2.5, lastSets: last),
            .addReps
        )
    }

    func testDoubleProgression_missedRange_repeats() {
        let last: [(weightKg: Double, reps: Int)] = [(60, 8), (60, 6), (60, 5)]
        XCTAssertEqual(
            GymMath.doubleProgression(targetSets: 3, repRange: GymMath.RepRange("8-12")!,
                                      incrementKg: 2.5, lastSets: last),
            .repeatSame
        )
    }

    func testDoubleProgression_fewerSetsThanTarget_repeats() {
        let last: [(weightKg: Double, reps: Int)] = [(60, 12), (60, 12)]
        XCTAssertEqual(
            GymMath.doubleProgression(targetSets: 3, repRange: GymMath.RepRange("8-12")!,
                                      incrementKg: 2.5, lastSets: last),
            .repeatSame
        )
    }

    func testDoubleProgression_ignoresWarmupSets() {
        // 2 riscaldamenti + 3 serie di lavoro a 60kg tutte a 12 → +peso
        let last: [(weightKg: Double, reps: Int)] = [(20, 10), (40, 8), (60, 12), (60, 12), (60, 12)]
        XCTAssertEqual(
            GymMath.doubleProgression(targetSets: 3, repRange: GymMath.RepRange("8-12")!,
                                      incrementKg: 2.5, lastSets: last),
            .addWeight(toKg: 62.5)
        )
    }

    func testDoubleProgression_noData_isNil() {
        XCTAssertNil(GymMath.doubleProgression(targetSets: 3, repRange: GymMath.RepRange("8-12")!,
                                               incrementKg: 2.5, lastSets: []))
    }

    func testWeightTrend_orderIndependentAndGuards() {
        let day = 86_400.0
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        let pts: [(date: Date, kg: Double)] = [
            (t0.addingTimeInterval(7 * day), 79), (t0, 80),
        ]
        XCTAssertEqual(GymMath.weightTrend(pts)?.perWeekKg ?? .nan, -1, accuracy: 0.0001)
        XCTAssertNil(GymMath.weightTrend([(t0, 80)]))            // 1 punto
        XCTAssertNil(GymMath.weightTrend([(t0, 80), (t0, 79)]))  // stessa data
    }
}
