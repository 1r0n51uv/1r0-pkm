//
//  _r0_pkm_w_Watch_AppUITests.swift
//  1r0-pkm-w Watch AppUITests
//
//  Created by 1r0n51uv on 05/09/26.
//

import XCTest

final class _r0_pkm_w_Watch_AppUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Spike #1 — Watch side: session activates at launch, and the send path runs.
    func testSessionActivatesAndSendRuns() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Sessione attiva"].waitForExistence(timeout: 10),
            "WCSession non è passata ad attiva sul Watch"
        )

        app.buttons["Invia a iPhone"].tap()

        let sent = app.staticTexts["Messaggio inviato"]
        let notReachable = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'raggiungibile'")
        ).firstMatch
        XCTAssertTrue(
            sent.waitForExistence(timeout: 5) || notReachable.waitForExistence(timeout: 1),
            "Nessun aggiornamento di stato dopo il tap di invio sul Watch"
        )
    }

    /// Spike #6 — end-to-end: tap "Logga set" on the Watch. The iPhone forwards
    /// it to the backend; this test only asserts the Watch send path ran.
    func testLogSet() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(
            app.staticTexts["Sessione attiva"].waitForExistence(timeout: 10),
            "WCSession non attiva sul Watch"
        )
        app.buttons["Logga set (100kg × 5)"].tap()
        XCTAssertTrue(
            app.staticTexts["Messaggio inviato"].waitForExistence(timeout: 5),
            "Il set non è stato inviato dal Watch"
        )
    }
}
