# ADR-0029: Dieta settimanale a template + toggle esplicito Apple Salute

## Status
Accettata

## Contesto
Feedback beta (Palestra + Dieta): la Dieta oggi si pianifica un pasto alla
volta (`MealPlanView` → `PlanMealSheet`, ADR-0017 slice 2). L'utente ha
invece una dieta settimanale fissa (ricetta per colazione, i due spuntini,
pranzo e cena, ADR-0024) che vuole impostare una volta e poi *applicare* a
settimane specifiche, senza ripianificare pasto per pasto ogni volta.

Applicata una settimana, la richiesta è che la schermata principale della
Dieta (`DietTabView`, tab "Oggi") mostri già cosa mangiare in ciascuno dei 5
slot **prima** che l'utente lo registri, con una spunta per segnare "fatto"
che logga automaticamente calorie/macro e aggiorna Apple Salute — oggi
quella schermata mostra solo lo stato "loggato"/"non loggato", nulla
d'intermedio.

In più, la sezione "Report" nell'header della Dieta (icona grafico) va
sostituita da una sezione impostazioni la cui prima voce è un interruttore
esplicito per il collegamento con Apple Salute — oggi la scrittura/lettura
HealthKit è condizionata solo dal permesso di sistema (concesso una volta in
onboarding, ADR-0004), senza un modo lato-app di disattivarla di nuovo.

## Decisione
1. **`DietTemplate` / `DietTemplateItem`** (nuovi `@Model` SwiftData, solo
   client — non sincronizzati: sono un editor locale, il risultato
   dell'applicazione sono `PlannedMeal` che già sincronizzano). Un template
   ha un nome e fino a 35 `DietTemplateItem` (7 giorni × 5 slot), ciascuno
   con un riferimento opzionale a una `Recipe` (id + nome snapshottato, come
   già fa `PlannedMealItem` per i `Food`).
2. **Applicazione a settimana** — `DietSync.applyTemplate(_:weekStart:in:)`:
   per ogni `DietTemplateItem` con ricetta assegnata, risolve gli alimenti
   della ricetta e chiama `DietSync.planMeal` sulla data risultante
   (`weekStart` + offset giorno), sostituendo un eventuale `PlannedMeal` già
   `.planned` per lo stesso giorno/slot (i `.completed`/`.skipped` restano,
   non si annulla un pasto già segnato). `DietTemplateEditorView` espone la
   griglia 7×5 (picker ricetta per cella) e l'azione "Applica" con scelta
   rapida settimana corrente/prossima o data libera (snap a lunedì).
3. **`DietTabView` mostra il piano prima del log** — se uno slot non ha
   ancora un `MealEntry` oggi ma esiste un `PlannedMeal` `.planned` per
   quello slot/giorno, la card mostra gli alimenti pianificati (da
   `PlannedMealItem`, senza risolvere `Food`) con un cerchio di spunta;
   toccarlo chiama `DietSync.completePlannedMeal` (già esistente, ADR-0017
   slice 2) che crea il `MealEntry`, aggiorna le calorie del giorno e — se
   abilitato — scrive su Salute. Tre stati visivi per card ora: non
   pianificato/non loggato, pianificato, loggato.
4. **Toggle Salute esplicito** — `HealthKitPreference` (`UserDefaults` bool,
   default `false`), controllato dalla prima voce di `DietSettingsView`
   (rinominata da `NotificationSettingsView`, che ora ha 3 sezioni: Salute,
   Notifiche, Report). Letture (energia attiva in `DietTabView.task`) e
   scritture (`DietSync.logMeal`) sono condizionate da
   `HealthKitPreference.isEnabled()`, non solo dal permesso di sistema:
   l'utente può ridisattivare il collegamento senza revocare il permesso iOS.
   Attivare il toggle richiede comunque `HealthKitService.requestAuthorization()`
   la prima volta. L'header Dieta perde l'icona report (`chart.line...`) e
   l'icona notifiche (`bell`) separate, sostituite da un'unica icona
   impostazioni (`gearshape`) che apre `DietSettingsView`; il Report resta
   raggiungibile da lì come **secondo `.sheet` a pari livello**, presentato
   nell'`onDismiss` del primo — non un `NavigationLink` push dentro il sheet
   impostazioni (impiccava il runloop di XCUITest, "Andamento" mai
   raggiunto) né un secondo `.sheet` presentato subito (stesso `dismiss()`
   rotto già noto per due sheet in successione, nota XCUITest).

## Conseguenze
- `MealSlot` (ADR-0024) passa da tipo "accettato ma non ancora implementato"
  a effettivamente 5 casi in `MealEntry.swift`, `MissingMealReminder`,
  `packages/shared/src/types/1r0-diet.ts`; migrazione Postgres
  `0010_meal_slot_five_values.sql` (`ALTER TYPE meal_slot ADD VALUE`,
  additiva — il vecchio `'snack'` resta nel tipo per le righe storiche, mai
  più scritto dal client).
- `DietTemplate`/`DietTemplateItem` sono locali al device: applicare lo
  stesso template su due device diversi va rifatto manualmente su entrambi
  (non c'è ancora un caso d'uso multi-device per l'editor, solo per il
  risultato applicato). Se servirà sync, si aggiunge come outbox a parte in
  un ADR successivo.
- `HealthKitPreference` è un gate **in aggiunta** al permesso di sistema, non
  in sostituzione: se l'utente nega il permesso a livello OS, il toggle app
  non ha effetto (le chiamate HealthKit falliscono comunque silenziosamente,
  comportamento preesistente).
- Test: `MissingMealReminderTests` aggiornati per 5 slot;
  `_r0_pkmUITests` aggiornati per `dietSettings`/`openReport` al posto di
  `notifSettings`/`showReport`. Nessun nuovo test unit per `applyTemplate`
  in questa iterazione (copertura via XCUITest sul flusso end-to-end).

## Alternative scartate
- **Un solo "piano pasti" ricorrente per-slot** (senza concetto di template
  nominato, tipo "il lunedì mangio sempre X"): scartata perché l'utente ha
  esplicitamente descritto più diete settimanali possibili da poter
  applicare a settimane diverse (es. dieta "massa" vs dieta "definizione"),
  non un'unica ricorrenza fissa.
- **Toggle Salute unico globale** (una sola preferenza per tutto
  HealthKit, gym incluso): scartata per ora — lo scope del feedback beta è
  la Dieta; il gym già scrive/legge HealthKit per il peso senza un toggle
  dedicato (ADR-0004) e non è stato messo in discussione qui.
