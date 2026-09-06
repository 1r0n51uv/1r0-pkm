//
//  _r0_pkmUITests.swift
//  1r0-pkmUITests
//

import XCTest

final class _r0_pkmUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 1r0-gym · catalogo esercizi: crea un esercizio offline-first e verifica
    /// che compaia in lista. Store in-memory (-uitest-reset).
    func testAddExerciseAppearsInList() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-reset"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Catalogo"].waitForExistence(timeout: 10))

        let unique = "Panca \(Int(Date().timeIntervalSince1970))"

        app.buttons["addExercise"].tap()
        let nameField = app.textFields["exerciseName"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(unique)
        app.buttons["saveExercise"].tap()

        XCTAssertTrue(
            app.staticTexts[unique].waitForExistence(timeout: 5),
            "L'esercizio creato non compare in lista"
        )
    }
}
