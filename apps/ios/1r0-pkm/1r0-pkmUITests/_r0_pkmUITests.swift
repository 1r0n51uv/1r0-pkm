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

        app.tabBars.buttons["Catalogo"].tap()
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

    /// 1r0-gym · schede: crea una scheda con fase e verifica che compaia.
    func testAddRoutineAppearsInList() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-reset"]
        app.launch()

        // parte sulla tab Schede
        XCTAssertTrue(app.staticTexts["Schede"].waitForExistence(timeout: 10))

        let unique = "PPL \(Int(Date().timeIntervalSince1970))"
        app.buttons["addRoutine"].tap()
        let nameField = app.textFields["routineName"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(unique)
        app.buttons["Bulk"].tap()
        app.buttons["saveRoutine"].tap()

        XCTAssertTrue(
            app.staticTexts[unique].waitForExistence(timeout: 5),
            "La scheda creata non compare in lista"
        )
    }

    /// Non è un test: cattura screenshot di entrambe le tab per la review.
    func testCaptureScreens() throws {
        let app = XCUIApplication()
        app.launch()
        _ = app.staticTexts["Schede"].waitForExistence(timeout: 10)
        sleep(2)
        attach(app, "01-schede")
        app.tabBars.buttons["Catalogo"].tap()
        _ = app.staticTexts["Catalogo"].waitForExistence(timeout: 5)
        sleep(2)
        attach(app, "02-catalogo")
        app.buttons["addExercise"].tap()
        _ = app.textFields["exerciseName"].waitForExistence(timeout: 5)
        sleep(1)
        attach(app, "03-nuovo-esercizio")
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let s = XCTAttachment(screenshot: app.screenshot())
        s.name = name
        s.lifetime = .keepAlways
        add(s)
    }
}
