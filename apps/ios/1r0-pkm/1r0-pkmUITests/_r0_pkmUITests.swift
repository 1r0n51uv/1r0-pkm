//
//  _r0_pkmUITests.swift
//  1r0-pkmUITests
//
//  Created by 1r0n51uv on 05/09/26.
//

import XCTest

final class _r0_pkmUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Spike #1 — iOS side: session activates at launch, and the send path runs.
    func testSessionActivatesAndSendRuns() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Sessione attiva"].waitForExistence(timeout: 10),
            "WCSession non è passata ad attiva"
        )

        app.buttons["Invia \"Ciao\" al Watch"].tap()

        // The send path ran without crashing if the status label changed away
        // from the activation message to any outcome (sent, or a precise
        // "not installed / not reachable" reason on an unpaired test clone).
        let changed = NSPredicate(format:
            "label == 'Messaggio inviato' OR label CONTAINS 'raggiungibile' OR label CONTAINS 'installata'")
        let outcome = app.staticTexts.containing(changed).firstMatch
        let appeared = outcome.waitForExistence(timeout: 5)
        let observed = app.staticTexts.allElementsBoundByIndex.map { $0.label }
        XCTAssertTrue(appeared, "Nessun aggiornamento di stato dopo il tap. Visti: \(observed)")
    }
}
