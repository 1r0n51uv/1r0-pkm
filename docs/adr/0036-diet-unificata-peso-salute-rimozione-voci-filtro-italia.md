# ADR-0036: Dieta unificata (oggi+pianificazione), peso da Salute, rimozione voci, filtro Italia

## Status
Accettata

## Contesto
Richiesta unica dell'utente, sei parti da fare "in un colpo solo":

1. Su sideload (SideStore/AltStore) HealthKit non risultava connesso, a
   differenza del simulatore.
2. La dashboard Dieta doveva mostrare il peso più recente da Salute.
3. Il modulo Dieta aveva "troppe pagine": `DietTabView` ("Oggi") e
   `MealPlanView` ("Pianificazione") erano due schermate quasi identiche
   (striscia giorni + slot pasto), navigabili solo passando per un'icona.
4. Il banner di sync fallita non era chiudibile.
5. Un pasto mangiato, un'acqua o una caffeina loggati per errore non si
   potevano rimuovere.
6. La ricerca alimenti (ADR-0018) restituiva perlopiù prodotti francesi/
   tedeschi/spagnoli per query italiane come "pane" — OpenFoodFacts usa un
   indice mondiale non filtrato per lingua/paese.

## Decisione

### 1. Entitlements — possibile causa dello stop di HealthKit su sideload
`_r0_pkm.entitlements` conteneva due chiavi App Sandbox **di macOS**
(`com.apple.security.app-sandbox`,
`com.apple.security.files.user-selected.read-only`), non valide su iOS.
Restano solo `com.apple.developer.healthkit` e
`com.apple.developer.healthkit.access`. Ipotesi: la ri-firma ad-hoc di
SideStore/AltStore tratta un entitlement macOS-only come rumore/conflitto
nel plist risultante, impedendo il grant HealthKit — sul simulatore (firma
Xcode nativa) l'anomalia non si manifesta. Non riproducibile in CI (nessun
sideload automatizzato); verificabile solo installando la prossima build e
controllando che il prompt Salute compaia.

### 2. Peso da Salute sulla dashboard
`DietTabView.task` chiama `HealthKitService.shared.latestBodyWeightKg()`
(dietro `HealthKitPreference.isEnabled()`) e mostra il risultato
nell'header (`healthWeightLabel`). Solo etichetta informativa — non entra
nei calcoli calorici di questa vista; la registrazione vera di una
rilevazione peso resta in Palestra → "Peso e misure".

### 3. Fusione `MealPlanView` → `DietTabView`
`MealPlanView` (schermata separata con striscia giorni + `slotCard` con
switch mangiato/saltato) viene assorbita in `DietTabView`: la striscia
giorni e i 5 `mealRow` con lo switch inline vivono ora nella stessa
schermata dell'anello calorie. L'anello/le macro restano **sempre quelli di
oggi** (`todayMeals`), indipendentemente dal giorno selezionato nella
striscia — la selezione serve solo a pianificare/correggere altri giorni,
non a "guardare indietro" le calorie.

`MealPlanView.swift` ora contiene solo `PlanMealSheet` (il foglio di
pianificazione/modifica, invariato). Le icone header di `MealPlanView`
(spesa, ricette, template) si spostano sull'header di `DietTabView`;
l'icona `openPlan` (che apriva la schermata separata) sparisce.

`mealRow` per ogni slot: se c'è un `MealEntry` → mostra gli alimenti
mangiati + kcal; altrimenti se c'è un `PlannedMeal` (qualunque stato, non
solo `.planned`) → mostra gli alimenti pianificati + una pillola di stato
(PIANIFICATO/MANGIATO/SALTATO); altrimenti → un pulsante "+"
(`plan_<slot>`) che apre `PlanMealSheet`. Lo switch mangiato/saltato
(`mealEatenToggle_<slot>`) appare ogni volta che c'è contenuto (piano o
pasto loggato): accendendolo si logga il pasto pianificato
(`DietSync.completePlannedMeal`); spegnendolo si cancellano le voci
loggate (`DietSync.deleteMealEntry`, che riporta il piano collegato a
`.skipped`). Resta anche il pulsante "Aggiungi alimento" in fondo
(`addFood`, sempre per **oggi**, slot scelto per orario —
`defaultSlot()`) per loggare qualcosa subito senza passare da un piano.

### 4. Banner di sync dismissabile
`SyncFailureBanner` (in `ContentView`) ha ora uno stato `dismissed` e un
pulsante di chiusura (`dismissSyncBanner`). Un nuovo fallimento (il
conteggio delle voci fallite cresce) lo fa ricomparire anche se era stato
chiuso — altrimenti un banner chiuso una volta nasconderebbe per sempre
fallimenti futuri diversi.

### 5. Rimozione voci: pasti, acqua, caffeina
`DietSync.deleteMealEntry(_:in:)` (nuova, generale — `setPlannedMealEaten`
ora vi delega per il caso "spegni lo switch"): cancella il `MealEntry`
locale + `DELETE /v1/meal-entries/:id`, e se era collegato a un
`PlannedMeal` lo riporta a `.skipped` (mai orfano). `DietSync.deleteWaterLog`
/`deleteCaffeineLog`: stesso pattern (locale + `DELETE` backend). Nuove
route `DELETE /v1/water-logs/:id` e `DELETE /v1/caffeine-logs/:id` in
`apps/api/src/routes/trackers.js`. `TrackersCard` ora elenca le voci di
oggi (non solo il totale) con un pulsante di rimozione per riga
(`removeWater_<id>`, `removeCaffeine_<id>`).

### 6. Filtro Italia nella ricerca alimenti
`FoodSearchPreference` (nuovo, stesso pattern di `HealthKitPreference`):
`diet.foodSearch.italianOnly`, **default `true`** (richiesto
esplicitamente). Un chip "🇮🇹 Solo Italia" (`italianOnlyFilter`) in
`FoodBasketEditor` e `LogFoodView` lo mostra/inverte. Quando attivo,
`DietSync.searchRemote` aggiunge `&country=it` alla query; il backend
(`apps/api/src/routes/foodsearch.js`) instrada verso
`it.openfoodfacts.org` invece del dominio mondiale quando riceve
`country=it` — risultati filtrati per il mercato italiano.

## Conseguenze
- Meno schermate: chi pianifica e chi corregge un giorno passato usa la
  stessa vista, con lo switch come unico meccanismo "mangiato/saltato".
- I test UI che passavano per `openPlan`/"Pianificazione" prima di aprire
  ricette/template/spesa sono stati semplificati (l'icona è ora diretta
  sull'header di `DietTabView`); gli identificatori `editPlanned` e
  `plannedEatenToggle` sono ora suffissati per slot
  (`editPlanned_<slot>`, `mealEatenToggle_<slot>`) perché più slot possono
  avere contenuto contemporaneamente sulla stessa schermata (prima erano
  su schermate/righe diverse, un solo elemento visibile per volta non era
  garantito comunque ma la fusione lo rende esplicito).
- Nuove route backend (`DELETE` voci tracker, `country` in
  `/v1/foods/search`) da distribuire su EC2 — nessuna migrazione di schema.
- L'ipotesi sull'entitlements va confermata empiricamente sulla prossima
  build sideload; se HealthKit resta non connesso, il prossimo passo è
  ispezionare l'entitlements *effettivamente* applicato dopo la ri-firma di
  SideStore (non solo il file sorgente in repo).
