//
//  _r0_pkmUITests.swift
//  1r0-pkmUITests
//

import XCTest

final class _r0_pkmUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        // il simulatore può restare in landscape da run precedenti: la tab bar
        // finisce compressa sul bordo e `scrollToVisible` fallisce. Forza il
        // portrait per ogni test.
        XCUIDevice.shared.orientation = .portrait
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

        app.tabBars.buttons["Schede"].tap()
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

    /// 1r0-gym · sessione: crea esercizio → inizia sessione → logga una
    /// serie → termina. Verifica che la serie compaia e la sessione chiuda.
    func testLiveSessionFlow() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-reset"]
        app.launch()

        // 1. un esercizio nel catalogo
        app.tabBars.buttons["Catalogo"].tap()
        XCTAssertTrue(app.staticTexts["Catalogo"].waitForExistence(timeout: 10))
        let exName = "Stacco \(Int(Date().timeIntervalSince1970))"
        app.buttons["addExercise"].tap()
        let nf = app.textFields["exerciseName"]
        XCTAssertTrue(nf.waitForExistence(timeout: 5)); nf.tap(); nf.typeText(exName)
        app.buttons["saveExercise"].tap()
        XCTAssertTrue(app.staticTexts[exName].waitForExistence(timeout: 8))

        // 2. inizia sessione
        app.tabBars.buttons["Sessione"].tap()
        app.buttons["startSession"].tap()
        XCTAssertTrue(app.buttons["addSet"].waitForExistence(timeout: 5))

        // 3. logga una serie
        app.buttons["addSet"].tap()
        XCTAssertTrue(app.buttons["logSet"].waitForExistence(timeout: 5))
        app.buttons["logSet"].tap()
        let oneRM = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '1RM'")).firstMatch
        XCTAssertTrue(oneRM.waitForExistence(timeout: 5), "La serie loggata non compare")
        sleep(1); attach(app, "sessione-live")

        // 4. termina
        app.buttons["endSession"].tap()
        XCTAssertTrue(app.buttons["startSession"].waitForExistence(timeout: 5),
                      "La sessione non è tornata allo stato iniziale")
    }

    /// 1r0-gym · ADR-0011: crea scheda → apri dettaglio → aggiungi giorno →
    /// aggiungi esercizio con target → verifica che compaia.
    func testRoutineTreeEditing() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-reset"]
        app.launch()

        // esercizio nel catalogo
        app.tabBars.buttons["Catalogo"].tap()
        XCTAssertTrue(app.staticTexts["Catalogo"].waitForExistence(timeout: 10))
        let exName = "Rematore \(Int(Date().timeIntervalSince1970))"
        app.buttons["addExercise"].tap()
        let nf = app.textFields["exerciseName"]
        XCTAssertTrue(nf.waitForExistence(timeout: 5)); nf.tap(); nf.typeText(exName)
        app.buttons["saveExercise"].tap()
        XCTAssertTrue(app.staticTexts[exName].waitForExistence(timeout: 8))

        // scheda
        app.tabBars.buttons["Schede"].tap()
        let rName = "Split \(Int(Date().timeIntervalSince1970))"
        app.buttons["addRoutine"].tap()
        let rf = app.textFields["routineName"]
        XCTAssertTrue(rf.waitForExistence(timeout: 5)); rf.tap(); rf.typeText(rName)
        app.buttons["saveRoutine"].tap()
        let card = app.staticTexts[rName]
        XCTAssertTrue(card.waitForExistence(timeout: 5))

        // dettaglio → giorno → esercizio
        card.tap()
        app.buttons["addDay"].tap()
        let dayField = app.alerts.textFields.firstMatch
        XCTAssertTrue(dayField.waitForExistence(timeout: 5)); dayField.typeText("Pull")
        app.alerts.buttons["Aggiungi"].tap()
        XCTAssertTrue(app.staticTexts["Pull"].waitForExistence(timeout: 5))

        app.buttons["addExerciseToDay"].tap()
        let picker = app.buttons["pickRoutineExercise"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        // espande la lista inline e sceglie l'esercizio appena creato
        let pickerItem = app.buttons[exName].firstMatch
        var opened = false
        for _ in 0..<3 {
            picker.tap()
            if pickerItem.waitForExistence(timeout: 3) { opened = true; break }
        }
        XCTAssertTrue(opened, "La lista di scelta esercizio non si è aperta")
        pickerItem.tap()

        let save = app.buttons["saveRoutineExercise"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()

        XCTAssertTrue(app.staticTexts[exName].waitForExistence(timeout: 5),
                      "L'esercizio non compare nel giorno")
        sleep(1); attach(app, "dettaglio-scheda")
    }

    /// 1r0-gym · ADR-0013: apre il calcolatore piastre in sessione e verifica
    /// che mostri il carico per lato e la rampa di warm-up.
    func testPlateCalculatorInSession() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-reset"]
        app.launch()

        app.tabBars.buttons["Sessione"].tap()
        app.buttons["startSession"].tap()
        XCTAssertTrue(app.buttons["openPlateCalc"].waitForExistence(timeout: 5))
        app.buttons["openPlateCalc"].tap()

        XCTAssertTrue(app.staticTexts["PER LATO"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["WARM-UP"].exists)
        let loadable = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'caricabile'")
        ).firstMatch
        XCTAssertTrue(loadable.waitForExistence(timeout: 3))
        sleep(1); attach(app, "calcolatore-piastre")
    }

    /// 1r0-gym · ADR-0012: registra una rilevazione (peso + misura) e verifica
    /// che compaia nei Progressi.
    func testAddBodyMeasurement() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-reset"]
        app.launch()

        app.tabBars.buttons["Progressi"].tap()
        XCTAssertTrue(app.staticTexts["Progressi"].waitForExistence(timeout: 10))

        app.buttons["addMeasurement"].tap()
        let w = app.textFields["measWeight"]
        XCTAssertTrue(w.waitForExistence(timeout: 5)); w.tap(); w.typeText("77.5")
        let waist = app.textFields["meas_waistCm"]
        waist.tap(); waist.typeText("81")
        // chiudi la tastiera (scrollDismissesKeyboard .immediately) e porta su "Salva"
        app.swipeUp()
        let save = app.buttons["saveMeasurement"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        save.tap()

        XCTAssertTrue(app.staticTexts["77.5 kg"].waitForExistence(timeout: 5),
                      "La rilevazione non compare nei Progressi")
        sleep(1); attach(app, "progressi")
    }

    /// ADR-0004: tocca "Apple Salute" nei Progressi → compare l'onboarding
    /// coi permessi (senza toccare il dialog di sistema).
    func testHealthKitOnboardingSheet() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-reset"]
        app.launch()

        app.tabBars.buttons["Progressi"].tap()
        XCTAssertTrue(app.buttons["healthImport"].waitForExistence(timeout: 10))
        app.buttons["healthImport"].tap()

        // niente peso / non autorizzato ⇒ onboarding
        XCTAssertTrue(app.buttons["healthAllow"].waitForExistence(timeout: 5),
                      "L'onboarding HealthKit non è comparso")
        XCTAssertTrue(app.staticTexts["Apple Salute"].exists)
        sleep(1); attach(app, "healthkit-onboarding")
    }

    /// 1r0-gym · ADR-0005: apre "Importa esercizio" dal catalogo e verifica
    /// che ci siano sia la ricerca AI sia il pulsante di sync wger. Non tocca
    /// la rete (nessuna chiave AI in CI).
    func testImportExerciseSheet() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-reset"]
        app.launch()

        app.tabBars.buttons["Catalogo"].tap()
        XCTAssertTrue(app.buttons["importExercise"].waitForExistence(timeout: 10))
        app.buttons["importExercise"].tap()

        XCTAssertTrue(app.textFields["aiQuery"].waitForExistence(timeout: 5),
                      "Manca il campo di ricerca AI")
        XCTAssertTrue(app.buttons["wgerSync"].exists, "Manca il sync wger")
        XCTAssertTrue(app.staticTexts["Importa esercizio"].exists)
        sleep(1); attach(app, "import-esercizio")
    }

    /// 1r0-diet · ADR-0017 slice 1: crea un alimento custom, loggalo a un
    /// pasto e verifica che compaia nella dashboard giornaliera.
    /// Offline-first (store in-memory, -uitest-reset).
    func testLogFoodAppearsInDiet() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-reset"]
        app.launch()

        app.tabBars.buttons["Dieta"].tap()
        XCTAssertTrue(app.staticTexts["Oggi"].waitForExistence(timeout: 10))

        app.buttons["addFood"].tap()
        XCTAssertTrue(app.buttons["createFood"].waitForExistence(timeout: 5))
        app.buttons["createFood"].tap()

        let unique = "Pollo \(Int(Date().timeIntervalSince1970))"
        let nf = app.textFields["foodName"]
        XCTAssertTrue(nf.waitForExistence(timeout: 5)); nf.tap(); nf.typeText(unique)
        let kf = app.textFields["foodKcal"]
        kf.tap(); kf.typeText("165")
        // il tastierino decimale copre "Salva": chiuderlo prima di salvare
        if app.buttons["kbDone"].exists { app.buttons["kbDone"].tap() }
        XCTAssertTrue(app.buttons["saveFood"].waitForExistence(timeout: 3))
        app.buttons["saveFood"].tap()

        // tornati al foglio: l'alimento è selezionato → card di composizione
        let addToMeal = app.buttons["addToMeal"]
        if !addToMeal.waitForExistence(timeout: 6) {
            let row = app.staticTexts[unique]
            if row.waitForExistence(timeout: 5) { row.tap() }
        }
        XCTAssertTrue(addToMeal.waitForExistence(timeout: 6),
                      "La card di composizione non è comparsa dopo aver creato l'alimento")
        addToMeal.tap()

        // dashboard giornaliera: l'alimento loggato compare nel pasto
        XCTAssertTrue(app.staticTexts[unique].waitForExistence(timeout: 8),
                      "L'alimento loggato non compare nella dashboard")
        sleep(1); attach(app, "dieta-oggi")
    }

    /// Non è un test: cattura screenshot delle tab per la review.
    func testCaptureScreens() throws {
        let app = XCUIApplication()
        app.launch()
        _ = app.buttons["startSession"].waitForExistence(timeout: 10)
        sleep(1); attach(app, "01-sessione")
        app.tabBars.buttons["Schede"].tap()
        _ = app.staticTexts["Schede"].waitForExistence(timeout: 5)
        sleep(2); attach(app, "02-schede")
        app.tabBars.buttons["Catalogo"].tap()
        _ = app.staticTexts["Catalogo"].waitForExistence(timeout: 5)
        sleep(2); attach(app, "03-catalogo")
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let s = XCTAttachment(screenshot: app.screenshot())
        s.name = name
        s.lifetime = .keepAlways
        add(s)
    }
}
