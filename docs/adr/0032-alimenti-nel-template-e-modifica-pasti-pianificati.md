# ADR-0032: Alimenti semplici nel template + modifica/retroattività pasti pianificati

## Status
Accettata

## Contesto
Feedback beta, tre problemi collegati nel flusso di pianificazione pasti:

1. Un template settimanale (ADR-0029) può assegnare **solo una ricetta** per
   slot. Un alimento singolo (es. "noci" a merenda) va incapsulato in una
   ricetta apposta anche se non è davvero una ricetta — attrito inutile.
2. Un pasto già pianificato (`MealPlanView`) non si può correggere: se si
   aggiunge un alimento sbagliato bisogna cancellare e ripianificare da capo.
   "Salta"/"Mangiato" sono due pulsanti indipendenti invece di un unico
   stato con cui è naturale "tornare indietro".
3. La striscia giorni di `MealPlanView` mostra solo i 7 giorni **futuri**:
   non si può correggere retroattivamente un giorno passato.

## Decisione
1. **`DietTemplateItem` assegna una ricetta O un alimento semplice**, mai
   entrambi (`recipeId`/`recipeName` vs `foodId`/`foodName`/`foodGrams`,
   mutuamente esclusivi). Il picker (`TemplateItemPickerSheet`, ex
   `RecipePickerSheet`) aggiunge una sezione "Alimenti" che riusa
   `FoodBasketEditor` (stessa ricerca cache/OpenFoodFacts/USDA + stepper
   grammi del resto dell'app) limitata a una selezione; confermare con "Usa
   ‹alimento›" applica quell'alimento+grammi allo slot.
   `DietSync.applyTemplate` risolve un `DietTemplateItem` con `foodId` come
   un `PlannedMeal` a un solo alimento, senza passare da `Recipe`.
2. **Un pasto pianificato si modifica** toccando la sua riga (icona matita) —
   riapre `PlanMealSheet` con paniere e ricetta pre-riempiti
   (`DietSync.updatePlannedMeal`); rimuovere un alimento aggiunto per errore
   è il pulsante "✕" già esistente in `FoodBasketEditor`, riusato qui senza
   codice nuovo. Modificabile solo mentre non è "mangiato" (vedi punto 3 per
   come riaprirlo).
3. **"Salta"/"Mangiato" diventano un unico switch** (`plannedEatenToggle`):
   acceso = mangiato, spento = saltato. Spegnerlo da uno stato "mangiato"
   **cancella** il `MealEntry` collegato (locale + nuovo `DELETE
   /v1/meal-entries/:id`) invece di lasciarlo orfano — altrimenti
   riaccenderlo duplicherebbe le calorie e il prossimo pull lo
   rimaterializzerebbe. Questo è anche il modo per **correggere
   retroattivamente** un pasto già segnato: spegni → modifica → riaccendi.
4. **La striscia giorni copre anche il passato** (10 giorni indietro, 13 in
   avanti — prima solo 0-6 in avanti), con scroll automatico su "oggi"
   all'apertura (`ScrollViewReader`). La finestra di pull backend si allarga
   di conseguenza.

## Conseguenze
- **Bug SwiftData trovato e corretto durante l'implementazione** (non
  correlato al punto 1-4 di per sé, ma scoperto scrivendone i test): il
  picker del template creava il nuovo `DietTemplateItem` con
  `DietTemplateItem(template: template, ...)` + `context.insert(it)`, ma
  `template.items` letto subito dopo nella stessa vista (`@Bindable`, non
  un `@Query` fresco) restava stantio — l'alimento/ricetta assegnati non
  comparivano mai nello slot pur salvando correttamente. Serve anche
  `template.items.append(it)` esplicito. Vedi memoria
  `swiftdata-relationship-1r0-pkm` per il dettaglio e quando serve/non
  serve. Stesso fix applicato a `updatePlannedMeal` per lo stesso motivo.
- Editare un pasto già `.completed` non è permesso direttamente — va
  riaperto con lo switch prima. Scelta deliberata (vedi Alternative) per non
  duplicare la logica di sincronizzazione fra `PlannedMeal` e `MealEntry`.
- Nuova route backend `DELETE /v1/meal-entries/:id` (`apps/api/src/routes/meals.js`),
  simmetrica a quella già esistente per `planned-meals`/`recipes`/
  `shopping-list`/`supplements`. `meal_entry_items` ha `on delete cascade`,
  `planned_meals.meal_entry_id` ha `on delete set null` (già nello schema
  0004) — nessuna migrazione nuova.
- Nuovo hook seed `-uitest-seed-diet` ora inserisce **due** alimenti (non
  uno) per poter testare la rimozione di un alimento dal paniere.

## Alternative scartate
- **Editare direttamente un `PlannedMeal` `.completed`, sincronizzando anche
  il `MealEntry` collegato in place**: scartato — richiede duplicare la
  logica di calcolo macro/outbox già in `logMeal`/`completePlannedMeal` per
  un secondo percorso "aggiorna invece di crea", a fronte di un guadagno UX
  minimo rispetto a "spegni interruttore, modifica, riaccendi" che riusa
  interamente il codice esistente.
- **Terzo stato del toggle per "ancora non deciso"**: scartato, l'utente ha
  chiesto esplicitamente uno switch a due stati; lo stato "ancora
  pianificato, non deciso" resta implicito (nessuna interazione = resta
  `.planned`, lo switch parte "spento" per quello stato senza inviare
  nessuna azione finché non viene toccato).
