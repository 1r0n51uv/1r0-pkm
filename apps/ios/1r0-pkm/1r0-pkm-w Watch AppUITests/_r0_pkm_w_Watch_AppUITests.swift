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
        XCTAssertTrue(app.staticTexts["1r0-gym"].waitForExistence(timeout: 10))
    }
}
