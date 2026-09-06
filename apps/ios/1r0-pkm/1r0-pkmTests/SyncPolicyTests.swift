//
//  SyncPolicyTests.swift
//  1r0-pkmTests
//
//  Regole pure di retry/backoff dell'outbox (ADR-0006).
//

import XCTest
@testable import _r0_pkm

final class SyncPolicyTests: XCTestCase {

    func testBackoff_zeroAttemptsIsImmediate() {
        XCTAssertEqual(SyncPolicy.backoffDelay(attempts: 0), 0)
    }

    func testBackoff_exponentialFromFiveSeconds() {
        XCTAssertEqual(SyncPolicy.backoffDelay(attempts: 1), 5)
        XCTAssertEqual(SyncPolicy.backoffDelay(attempts: 2), 10)
        XCTAssertEqual(SyncPolicy.backoffDelay(attempts: 3), 20)
        XCTAssertEqual(SyncPolicy.backoffDelay(attempts: 4), 40)
    }

    func testBackoff_isCappedAtMax() {
        XCTAssertEqual(SyncPolicy.backoffDelay(attempts: 50), SyncPolicy.maxBackoff)
        XCTAssertLessThanOrEqual(SyncPolicy.backoffDelay(attempts: 9), SyncPolicy.maxBackoff)
    }

    func testBackoff_monotonicNonDecreasing() {
        var last = -1.0
        for a in 0...30 {
            let d = SyncPolicy.backoffDelay(attempts: a)
            XCTAssertGreaterThanOrEqual(d, last)
            last = d
        }
    }

    func testNextAttempt_addsDelayToDate() {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let next = SyncPolicy.nextAttempt(after: base, attempts: 2)
        XCTAssertEqual(next.timeIntervalSince(base), 10, accuracy: 0.001)
    }

    func testClassify_transientCodes() {
        for s in [-1, 0, 408, 425, 429, 500, 502, 503, 504, 599, 409] {
            XCTAssertEqual(SyncPolicy.classify(status: s), .transient, "status \(s)")
        }
    }

    func testClassify_permanentClientErrors() {
        for s in [400, 401, 403, 404, 422] {
            XCTAssertEqual(SyncPolicy.classify(status: s), .permanent, "status \(s)")
        }
    }

    func testClassify_2xxAnd3xxDefaultTransient() {
        // non dovrebbero mai arrivare qui (sono successi), ma se capita
        // meglio riprovare che parcheggiare.
        XCTAssertEqual(SyncPolicy.classify(status: 200), .transient)
        XCTAssertEqual(SyncPolicy.classify(status: 302), .transient)
    }
}
