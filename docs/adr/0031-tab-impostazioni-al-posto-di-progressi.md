# ADR-0031: Tab Impostazioni al posto di Progressi, progressi corporei in Palestra

## Status
Accettata

## Contesto
Feedback beta: la app ha 3 tab — Palestra (storico + grafici allenamenti,
ADR-0027/0030), Dieta, Progressi (peso/misure corporee, ADR-0012). Le
impostazioni esistevano solo come sheet raggiungibile dall'icona `gearshape`
nell'header Dieta (`DietSettingsView`, ADR-0029) — un solo punto d'accesso,
annidato, per un concetto (le impostazioni dell'app) che concettualmente non
appartiene solo al modulo dieta.

Contemporaneamente, "Progressi" (peso/misure) e "Palestra" (allenamenti)
sono entrambi tracking del corpo/performance fisica — due tab separate per
due facce della stessa cosa, mentre il redesign di Palestra (ADR-0030) è già
andato nella direzione di un'unica vista densa invece di più sezioni sparse.

## Decisione
1. **Tab "Progressi" rimossa.** Il suo contenuto (`ProgressTabView`: trend
   peso con sparkline, elenco rilevazioni, "Registra misura", import da
   Apple Salute) diventa una sezione **"Peso e misure"** dentro
   `GymHistoryView` (Palestra), dopo lo storico allenamenti. Stesso
   `@Query` su `BodyMeasurement`, stessa logica (`GymMath.weightTrend`),
   stesso `GymSync.pullMeasurements`. `ProgressTabView.swift` eliminato;
   `Sparkline` (unico pezzo ancora riusato) spostato in `GymHistoryView.swift`.
2. **Il terzo tab diventa "Impostazioni"**, che monta `DietSettingsView`
   direttamente come radice (non più uno sheet). Il contenuto non cambia
   (Salute → Notifiche → Report), ma essendo ora una radice di tab —non più
   annidata dentro un altro sheet— il link al Report torna a essere un
   semplice `NavigationLink` (il giro sheet-dopo-sheet introdotto in
   ADR-0029 per aggirare il bug del runloop XCUITest non serve più: quel
   bug scattava per il push dentro uno sheet, non per un push da una radice
   di tab). L'icona `gearshape` sparisce dall'header Dieta.
3. L'header Palestra non cambia; "Peso e misure" ha la propria riga di
   sezione con le due icone (`+ registra`, importa da Salute) che prima
   stavano nell'header di Progressi.

## Conseguenze
- Tre tab restano tre, ma il contenuto si riequilibra: Palestra assorbe
  tutto il tracking fisico (allenamenti + corpo), Impostazioni è ora un
  primo cittadino invece di un'icona nascosta.
- `DietSettingsView` non è più diet-specific solo di nome: contiene ancora
  solo impostazioni del modulo dieta (Salute per la dieta, Promemoria pasto/
  acqua) — non è stato aggiunto altro contenuto in questa iterazione.
  Se in futuro serviranno impostazioni di altri moduli, questo è il posto.
- XCUITest: `testAddBodyMeasurement`/`testHealthKitOnboardingSheet` ora
  aprono "Palestra" invece di "Progressi"; `testDietReport`/
  `testDietSettingsSheet` aprono "Impostazioni" invece di "Dieta" →
  `dietSettings`. L'identifier `dietSettings` (icona header Dieta) è
  rimosso, non più referenziato da nessun test.

## Alternative scartate
- **Impostazioni come quarto tab** (tenendo Progressi separata): scartato
  su richiesta esplicita dell'utente — sostituire lo slot di Progressi,
  non aggiungerne uno. Anche a prescindere, 4 tab affollano la tab bar più
  di quanto serva per 3 aree reali (Palestra+corpo, Dieta, Impostazioni).
- **Impostazioni come sheet globale** (icona in ogni header, non un tab):
  scartato, l'utente ha chiesto esplicitamente un tab dedicato.
