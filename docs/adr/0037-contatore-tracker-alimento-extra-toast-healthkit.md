# ADR-0037: Contatore acqua/caffeina, alimento extra nel pasto, toast HealthKit

## Status
Accettata

## Contesto
Seguito diretto di ADR-0036, richiesto in un solo messaggio:

1. Acqua e caffeina: layout diverso — un contatore centrale con due
   pulsanti ai lati per aggiungere/togliere, non più righe di pulsanti
   multipli (+250/+500 ml, Espresso/Filtro) più un elenco voci a parte.
2. Per ogni pasto, oltre all'alimento pianificato si vuole poter aggiungere
   un altro alimento a parte, e poterlo rimuovere — come già possibile per
   acqua/caffeina (ADR-0036).
3. HealthKit ancora non si collega sul device sideload e non mostra
   nemmeno la richiesta di permesso: nessun segnale visibile all'utente.
   Va aggiunto un toast/banner quando c'è un problema.
4. Segnalato: il grafico (barre) di proteine/carboidrati/grassi non si
   aggiorna.

## Decisione

### 1. Contatore centrale acqua/caffeina
`TrackersCard`: la riga di pulsanti multipli + l'elenco voci rimovibili
(introdotto in ADR-0036) diventano un'unica riga centrata — un numero
grande (`\(Int(totale)) ml` / `\(Int(totale)) mg oggi`, stesso formato di
prima) con un pulsante "-" a sinistra e "+" a destra. "+" aggiunge una voce
dell'importo di default (250 ml acqua, espresso 80 mg caffeina — gli unici
rimasti, gli altri importi come "+500 ml"/"Filtro +120" sono stati tolti
dal quick-add diretto); "-" **annulla l'ultima voce registrata oggi** (non
un decremento arbitrario: non ha senso "togliere X ml" senza chiedere
quanto). Identificatori invariati per "+" (`water250`, `caff80`, minima
rottura dei test); nuovi `waterMinus`/`caffMinus` per "-", disabilitato
quando non c'è nulla da togliere oggi.

### 2. Alimento extra in un pasto già mangiato
`DietSync.deleteMealItem(_:in:)` (nuova): rimuove un singolo
`MealEntryItem` da un `MealEntry`. Se era l'ultimo dell'entry, delega a
`deleteMealEntry` (stessa pulizia del piano collegato, ADR-0036);
altrimenti ri-accoda `mealentry.create` con lo stesso id e gli item
rimasti — il backend fa già upsert su id (`on conflict do update` +
ricrea tutti gli item, `apps/api/routes/meals.js`), quindi non serve una
nuova route DELETE per singolo item. `DietTabView.loggedItemsList` mostra
ora un pulsante di rimozione per riga (`removeMealItem_<nome>`, stesso
schema di `removeBasketItem_<nome>`).

Aggiungere un alimento extra a un pasto già "mangiato" riusa
`DietSync.logMeal` (crea un **secondo** `MealEntry` per lo stesso
slot/giorno — già supportato: `meals(slot, on:)` non ha mai assunto un solo
`MealEntry` per slot, `items` li appiattisce tutti). In `mealRowHeader`,
quando il pasto ha contenuto, un pulsante `+` accanto allo switch
(`addToMeal_<slot>`) apre `LogFoodView(slot:)` — visibile solo per **oggi**
(`isToday`): `LogFoodView`/`DietSync.logMeal` loggano sempre per "adesso",
quindi per un giorno diverso da quello selezionato finirebbe nello slot
sbagliato.

### 3. Toast HealthKit
Nuovo `HealthKitStatus` (`ObservableObject` singleton, non persistito):
`HealthKitService.requestAuthorization()` non scarta più il risultato in
silenzio — dopo la richiesta controlla lo stato dei tipi in scrittura:
- tutti ancora `.notDetermined` → il sistema non ha mostrato il prompt
  (sintomo tipico di un entitlements non applicato da una ri-firma
  sideload): messaggio con l'indicazione di controllare Impostazioni →
  Salute → Accesso app e dati, o reinstallare l'app;
- tutti `.sharingDenied` → permesso negato, stessa indicazione;
- l'`await store.requestAuthorization` lancia → messaggio con
  `error.localizedDescription`;
- `!isAvailable` → "Salute non è disponibile su questo dispositivo."

`ContentView` mostra un `HealthKitFailureBanner` (stesso stile/pattern di
`SyncFailureBanner`, chiudibile, ricompare su un nuovo problema) sotto
quello di sync, ovunque nell'app — non solo nella schermata Impostazioni
dove si preme l'interruttore.

### 4. Grafico macro non aggiornato
Investigato con un test end-to-end (`testPlanAndCompleteMeal`, asserzione
aggiunta): pianificare "Avena test" (100 g, 13 g proteine) a pranzo e
segnarlo mangiato aggiorna correttamente la barra proteine da "0 / 170 g"
a "13 / 170 g" — **verificato che la pipeline dati→UI funziona** per il
percorso principale (piano → switch mangiato). `dayTotals`/`goal` sono
`@Query`-reattivi come l'anello calorie (stesso `Macros`, stesso reduce:
non può strutturalmente aggiornarsi la sola kcal e non le macro). Non
riprodotto un bug distinto in questa sessione; l'ipotesi più concreta è
che il sintomo segnalato coincidesse in realtà con il punto 2 — provare ad
aggiungere un secondo alimento a un pasto già mangiato non aveva alcun
effetto visibile perché l'azione non esisteva, non perché il grafico non
si aggiornasse. Se il problema persiste dopo questa build, va isolato con
uno scenario preciso (quale flusso, quale schermata) per riprodurlo.

## Conseguenze
- Nessuna migrazione né nuova route backend: `deleteMealItem` riusa
  l'upsert già esistente di `POST /v1/meal-entries`.
- `TrackersCard`: rimossi i pulsanti "+500 ml"/"Filtro +120" e l'elenco
  voci per riga — chi vuole un importo diverso da quello di default deve
  usarne più di uno (es. due `water250` per 500 ml) o toglierne uno con
  "-" e riprovare; nessuna richiesta di supportare importi custom.
- Il fix entitlements di ADR-0036 resta da confermare sul device reale; il
  toast rende almeno visibile un secondo tentativo fallito, invece di uno
  zero assoluto di segnale.
- `testAddExtraFoodAndRemoveMealItem` (nuovo) + asserzione macro aggiunta a
  `testPlanAndCompleteMeal`: 25/25 XCUITest verdi in questa sessione
  (nessun flake in questo run, a differenza delle sessioni precedenti).
