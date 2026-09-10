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

        // il foglio si chiude → dashboard: l'alimento loggato compare nel pasto
        XCTAssertTrue(app.tabBars.buttons["Dieta"].waitForExistence(timeout: 10),
                      "Il foglio non si è chiuso dopo 'Aggiungi al pasto'")
        XCTAssertTrue(app.staticTexts[unique].waitForExistence(timeout: 6),
                      "L'alimento loggato non compare nella dashboard")
        sleep(1); attach(app, "dieta-oggi")
    }

    /// 1r0-diet · ADR-0019: imposta un obiettivo manuale e verifica che la
    /// dashboard (anello calorie) rifletta il nuovo target.
    func testSetNutritionGoal() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-reset"]
        app.launch()

        app.tabBars.buttons["Dieta"].tap()
        XCTAssertTrue(app.staticTexts["Oggi"].waitForExistence(timeout: 10))

        app.buttons["editGoal"].tap()
        XCTAssertTrue(app.staticTexts["Obiettivo nutrizionale"].waitForExistence(timeout: 5))

        let kf = app.textFields["goal_Calorie"]
        XCTAssertTrue(kf.waitForExistence(timeout: 5))
        if app.buttons["clear_Calorie"].exists { app.buttons["clear_Calorie"].tap() }
        kf.tap()
        kf.typeText("1950")

        app.buttons["saveGoal"].tap()

        XCTAssertTrue(app.tabBars.buttons["Dieta"].waitForExistence(timeout: 8),
                      "Il foglio obiettivo non si è chiuso")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS '1.950'")).firstMatch
                .waitForExistence(timeout: 6),
            "L'anello calorie non mostra il nuovo obiettivo (1.950 kcal)"
        )
        sleep(1); attach(app, "diet-goal")
    }

    /// 1r0-diet · ADR-0018: il foglio "Aggiungi alimento" ha ricerca +
    /// scansione barcode; il pulsante scan apre lo scanner (sul simulatore
    /// niente fotocamera → inserimento manuale del codice).
    func testFoodSearchAndBarcodeScan() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-reset"]
        app.launch()

        app.tabBars.buttons["Dieta"].tap()
        XCTAssertTrue(app.staticTexts["Oggi"].waitForExistence(timeout: 10))
        app.buttons["addFood"].tap()

        XCTAssertTrue(app.textFields["foodSearch"].waitForExistence(timeout: 5),
                      "Manca il campo di ricerca alimento")
        XCTAssertTrue(app.buttons["scanBarcode"].exists, "Manca il pulsante scansione barcode")
        XCTAssertTrue(app.buttons["createFood"].exists, "Manca 'crea alimento personalizzato'")

        app.buttons["scanBarcode"].tap()
        XCTAssertTrue(app.staticTexts["Scansiona codice"].waitForExistence(timeout: 5))
        // simulatore: nessuna fotocamera → fallback manuale
        XCTAssertTrue(app.textFields["manualBarcode"].waitForExistence(timeout: 5),
                      "Manca l'inserimento manuale del codice quando la fotocamera non c'è")
        sleep(1); attach(app, "barcode-scan")
    }

    /// 1r0-diet · ADR-0020: dalla dashboard dieta si apre il report
    /// "Andamento" con le fasce temporali e le sezioni calorie / aderenza /
    /// peso.
    func testDietReport() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-reset"]
        app.launch()

        app.tabBars.buttons["Dieta"].tap()
        XCTAssertTrue(app.staticTexts["Oggi"].waitForExistence(timeout: 10))

        app.buttons["showReport"].tap()
        XCTAssertTrue(app.staticTexts["Andamento"].waitForExistence(timeout: 5),
                      "Il report dieta non si è aperto")
        XCTAssertTrue(app.staticTexts["Media calorie giornaliere"].exists,
                      "Manca la card calorie")
        XCTAssertTrue(app.staticTexts["Aderenza al piano"].exists,
                      "Manca la sezione aderenza")

        // le fasce temporali cambiano la finestra
        app.buttons["90 giorni"].tap()
        XCTAssertTrue(app.staticTexts["Peso e calorie"].waitForExistence(timeout: 3))

        sleep(1); attach(app, "diet-report")
    }

    /// 1r0-diet · ADR-0017 slice 2: salva una ricetta (nome + un alimento) e
    /// verifica che compaia nell'elenco ricette. Alimento pre-seminato
    /// (`-uitest-seed-diet`) → nessuna rete, nessun flusso "crea alimento".
    func testCreateRecipe() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-reset", "-uitest-seed-diet"]
        app.launch()

        app.tabBars.buttons["Dieta"].tap()
        XCTAssertTrue(app.staticTexts["Oggi"].waitForExistence(timeout: 10))

        app.buttons["openPlan"].tap()
        XCTAssertTrue(app.staticTexts["Pianificazione"].waitForExistence(timeout: 5))
        app.buttons["openRecipes"].tap()
        XCTAssertTrue(app.staticTexts["Ricette"].waitForExistence(timeout: 5))
        app.buttons["addRecipe"].firstMatch.tap()

        let rn = app.textFields["recipeName"]
        XCTAssertTrue(rn.waitForExistence(timeout: 5))
        let recipeName = "Colazione tipo \(Int(Date().timeIntervalSince1970))"
        rn.tap(); rn.typeText(recipeName)

        let bs = app.textFields["basketSearch"]
        XCTAssertTrue(bs.waitForExistence(timeout: 5))
        bs.tap(); bs.typeText("Avena")
        let add = app.buttons["basketAdd"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5), "Nessun risultato nel paniere")
        add.tap()

        app.buttons["saveRecipe"].tap()
        XCTAssertTrue(app.staticTexts[recipeName].waitForExistence(timeout: 6),
                      "La ricetta salvata non compare in elenco")
        sleep(1); attach(app, "recipe-list")
    }

    /// 1r0-diet · ADR-0017 slice 2: pianifica un pasto per oggi e confermalo
    /// ("Mangiato") — lo stato passa a completato.
    func testPlanAndCompleteMeal() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-reset", "-uitest-seed-diet"]
        app.launch()

        app.tabBars.buttons["Dieta"].tap()
        XCTAssertTrue(app.staticTexts["Oggi"].waitForExistence(timeout: 10))

        app.buttons["openPlan"].tap()
        XCTAssertTrue(app.staticTexts["Pianificazione"].waitForExistence(timeout: 5))

        app.buttons["plan_lunch"].tap()
        XCTAssertTrue(app.staticTexts["Pianifica"].waitForExistence(timeout: 5))

        let bs = app.textFields["basketSearch"]
        XCTAssertTrue(bs.waitForExistence(timeout: 5))
        bs.tap(); bs.typeText("Avena")
        let add = app.buttons["basketAdd"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5), "Nessun risultato nel paniere")
        add.tap()

        app.buttons["savePlannedMeal"].tap()

        let complete = app.buttons["completePlanned"]
        XCTAssertTrue(complete.waitForExistence(timeout: 6),
                      "Il pasto pianificato non è comparso")
        complete.tap()

        XCTAssertTrue(app.staticTexts["MANGIATO"].waitForExistence(timeout: 6),
                      "Lo stato del pasto non è passato a 'Mangiato'")
        sleep(1); attach(app, "meal-plan")
    }

    /// 1r0-diet · ADR-0017 slice 3: aggiungi una voce alla lista della spesa
    /// e spuntala (passa nella sezione "nel carrello").
    func testShoppingList() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-reset"]
        app.launch()

        app.tabBars.buttons["Dieta"].tap()
        XCTAssertTrue(app.staticTexts["Oggi"].waitForExistence(timeout: 10))
        app.buttons["openPlan"].tap()
        XCTAssertTrue(app.staticTexts["Pianificazione"].waitForExistence(timeout: 5))
        app.buttons["openShopping"].tap()
        XCTAssertTrue(app.staticTexts["Lista della spesa"].waitForExistence(timeout: 5))

        let f = app.textFields["newShoppingItem"]
        XCTAssertTrue(f.waitForExistence(timeout: 5))
        f.tap(); f.typeText("Pane integrale")
        app.buttons["addShoppingItem"].tap()

        XCTAssertTrue(app.staticTexts["Pane integrale"].waitForExistence(timeout: 5),
                      "La voce aggiunta non compare")
        app.buttons["check_Pane integrale"].tap()
        XCTAssertTrue(app.buttons["clearChecked"].waitForExistence(timeout: 5),
                      "La voce spuntata non è passata in 'Nel carrello'")
        sleep(1); attach(app, "shopping-list")
    }

    /// 1r0-diet · ADR-0017 slice 4: quick-add acqua/caffeina sul cruscotto e
    /// checklist integratori (aggiungi + spunta).
    func testTrackers() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest-reset"]
        app.launch()

        app.tabBars.buttons["Dieta"].tap()
        XCTAssertTrue(app.staticTexts["Oggi"].waitForExistence(timeout: 10))

        app.buttons["water250"].tap()
        XCTAssertTrue(app.staticTexts["250 ml"].waitForExistence(timeout: 5),
                      "Il totale acqua non si è aggiornato")
        app.buttons["caff80"].tap()
        XCTAssertTrue(app.staticTexts["80 mg oggi"].waitForExistence(timeout: 5),
                      "Il totale caffeina non si è aggiornato")

        app.buttons["manageSupplements"].tap()
        let sn = app.textFields["supplementName"]
        XCTAssertTrue(sn.waitForExistence(timeout: 5))
        sn.tap(); sn.typeText("Creatina")
        app.buttons["addSupplement"].tap()
        XCTAssertTrue(app.staticTexts["Creatina"].waitForExistence(timeout: 5))
        app.buttons["Fine"].tap()

        let toggle = app.buttons["supp_Creatina"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        XCTAssertTrue(app.staticTexts["1/1 presi"].waitForExistence(timeout: 5),
                      "La spunta integratore non è stata registrata")
        sleep(1); attach(app, "trackers")
    }

    /// Non è un test: cattura screenshot delle tab per la review.
    func testCaptureScreens() throws {
        let app = XCUIApplication()
        app.launch()
        _ = app.staticTexts["Oggi"].waitForExistence(timeout: 10)
        sleep(1); attach(app, "01-dieta")
        app.tabBars.buttons["Progressi"].tap()
        _ = app.staticTexts["Progressi"].waitForExistence(timeout: 5)
        sleep(2); attach(app, "02-progressi")
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let s = XCTAttachment(screenshot: app.screenshot())
        s.name = name
        s.lifetime = .keepAlways
        add(s)
    }
}
