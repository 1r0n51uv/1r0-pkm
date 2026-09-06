//
//  _r0_pkm_w_Watch_AppUITests.swift
//  1r0-pkm-w Watch AppUITests
//

import XCTest

final class _r0_pkm_w_Watch_AppUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["wStart"].waitForExistence(timeout: 10))
    }

    /// ADR-0016: sul Watch — inizia sessione, logga una serie, termina.
    func testWatchSessionFlow() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["wStart"].waitForExistence(timeout: 10))
        app.buttons["wStart"].tap()

        XCTAssertTrue(app.buttons["wAddSet"].waitForExistence(timeout: 5))
        app.buttons["wAddSet"].tap()

        XCTAssertTrue(app.buttons["wLogConfirm"].waitForExistence(timeout: 5))
        app.buttons["wLogConfirm"].tap()

        XCTAssertTrue(app.staticTexts["1 serie"].waitForExistence(timeout: 5),
                      "La serie loggata non compare")

        // le azioni sono in fondo alla List (watchOS renderizza pigramente)
        app.swipeUp(); app.swipeUp()
        let end = app.buttons["wEnd"]
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        end.tap()
        XCTAssertTrue(app.buttons["wStart"].waitForExistence(timeout: 5),
                      "La sessione non è tornata allo stato iniziale")
    }
}
