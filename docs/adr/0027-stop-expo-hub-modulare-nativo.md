# ADR-0027: Stop Expo, ridimensionamento a hub modulare nativo

## Status
Accettata — supersede [ADR-0025](0025-expo-nuovo-filone-implementazione.md) e
[ADR-0026](0026-piano-azione-expo.md). Emenda [ADR-0004](0004-healthkit-integration.md),
[ADR-0006](0006-offline-first-workout-logging.md),
[ADR-0010](0010-swift-native-ios-watch.md), [ADR-0019](0019-nutrition-goals.md). Marca
superseded [ADR-0005](0005-exercise-catalog-wger-ai-import.md),
[ADR-0013](0013-strumenti-in-sessione.md), [ADR-0014](0014-siri-shortcuts.md),
[ADR-0016](0016-watch-app-scope.md).

## Contesto
ADR-0025/0026 avevano avviato un filone Expo/React Native parallelo, con due motivazioni:
(a) le notifiche sarebbero state migliori/necessarie su Expo; (b) restando sul piano
gratuito Apple, HealthKit / Live Activities / Watch non sarebbero stati disponibili al
nativo, quindi tanto valeva riscrivere.

Tre verifiche fatte in fase di planning smontano entrambe:

1. **Notifiche — Expo non dà vantaggi.** Notifiche locali ricorrenti (`UNCalendarNotificationTrigger`),
   categorie con azioni, `BGTaskScheduler` sono alla pari col nativo. Sull'unico punto che
   differisce — gestire il tap su un'azione ad **app terminata** senza aprirla — il
   **nativo è migliore**: iOS rilancia l'app in background per
   `didReceiveNotificationResponse` senza APNs, mentre `expo-notifications` su iOS lo fa
   solo con un push server (APNs = programma a pagamento).
2. **HealthKit è gratuito sul Personal Team.** Il commit `7e10b72` e ADR-0025 sbagliavano.
   Funzionano gratis anche: notifiche locali, background modes, App Intents, WidgetKit,
   Live Activities (update locali), App Groups. Restano paid-only: Push/APNs,
   iCloud/CloudKit, Sign in with Apple, Associated Domains.
3. **Clipboard automatica — impossibile su iOS** (policy dal 2015: niente lettura pasteboard
   in background; banner "incollato da" dal iOS 14, popup di consenso dal 16). Rilevante
   perché uno dei moduli ipotizzati era un gestore clipboard.

In parallelo l'ambito del prodotto è stato ridotto: niente più tracking allenamento "live",
la dieta resta com'è ma si integra con Apple Salute, e nascono due moduli nuovi.

## Decisione

### Piattaforma
- **Nativo Swift/SwiftUI**, singola app Xcode `1r0-pkm`. **Migrazione Expo abbandonata.**
- **Piano gratuito Apple / sideload.** Si accettano: ri-firma del profilo ~ogni 7 giorni
  per sempre; max 3 app+estensioni sideloadate insieme; **niente app Watch** (SideStore/
  AltStore installano solo l'`.ipa` iOS); niente iCloud/Push. Il backend custom (ADR-0022)
  copre il sync. L'upgrade ai 99$/anno resta un'opzione futura, non pianificata.
- `apps/api` + EC2 + `apps/web` restano. `apps/web` (sola lettura) rispecchia **gym + diet**
  (non `documenti`).
- Architettura **modulare** invariata (ADR-0008): un modulo = una sezione dell'app; i moduli
  **condividono infrastruttura** (motore Promemoria, gateway HealthKit, sync/outbox, design
  system) sotto `Modules/Shared/`.

### Moduli v1 (3)
- **`gym`** — da tracker live a **storico + grafici**. Si toglie: sessione live e log serie
  in-app, catalogo esercizi + import wger/AI, Live Activity timer riposo, editor schede e
  tracker "scheda attiva" (modelli `Routine`/`RoutineDay`/`RoutineExercise` rimossi),
  dipendenza Watch. Si costruisce: **import CSV da Liftin'** (`Date;Duration;Routine;
  Exercise;Set;Warmup;Weight;Reps/Time;Goal;Perception`, delimitatore `;`, `Reps/Time` duale
  reps/tempo) con persistenza in SwiftData + backend ("la nostra copia"). `WorkoutSession`/
  `SetLogEntry` diventano **record importati read-only**; `SetLogEntry` guadagna
  `durationSeconds` e `isWarmup`, `reps` diventa opzionale. Re-import = **merge deduplicato**
  su `(Date + Exercise + Set)`. Grafici via `GymMath` invariato. Nessuna notifica.
- **`diet`** — **invariato** (tutto l'ambito ADR-0017: contatore, DB alimenti, planning,
  ricette, lista spesa, tracker acqua/integratori/caffeina, obiettivi, report) **+**:
  scrittura energia/macro su HealthKit per ogni pasto; lettura da HealthKit di peso,
  **acqua** ed **energia attiva**; notifiche azionabili "Hai mangiato a &lt;slot&gt;?" (Sì =
  flag `MealSlotAck` che silenzia il promemoria dello slot per la giornata, **non** crea un
  MealEntry; Rimanda = +30 min; risposta gestita in background) e "Hai bevuto?" (scatta solo
  se il totale acqua da HealthKit è sotto quota). L'app resta la fonte di verità, Salute è
  specchio in uscita (+ input per peso/acqua/energia).
- **`documenti`** — **nuovo**: vault documenti d'identità. `Documento` con `tipo`
  (`TipoDocumento`), **campi fissi per tipo**, immagini (fronte/retro) acquisite via
  `VNDocumentCameraViewController` + libreria foto, `dataScadenza` con **preavvisi**
  (default 90/30 giorni) via il motore Promemoria condiviso. Visualizzazione + copia
  per-campo / copia immagine / **export PDF**. **Storage solo su device, cifrato**
  (Data Protection) finché il backend non è su HTTPS; sync attivato dopo l'infra sicura
  (vedi [ADR-0028](0028-backend-https-e-storage-documenti.md)). Non su `apps/web`.

### Fuori dalla v1
- **Clipboard**: la cattura automatica è impossibile su iOS; resterebbe solo "ritagli
  manuali" via Share Extension. Rimandato/da rivalutare.
- **Widget**: nessuno per ora (ogni widget/estensione consuma uno dei 3 slot sideload).

### Ordine di lavoro
1. Cleanup codice tagliato + questo ADR + emendamenti + glossario + spostamento in
   `Modules/Shared/`.
2. Motore Promemoria condiviso (`Modules/Shared/Reminders/`).
3. `gym` reshape (rimozione UI live + `Import/` + grafici).
4. `diet` + HealthKit read/write + notifiche azionabili.
5. Infra HTTPS + backup (ADR-0028).
6. `documenti`.

## Alternative scartate
- **Procedere con Expo comunque** (per TS condiviso col web, per non scrivere Swift):
  scartata — la ricerca notifiche toglie l'unico vantaggio concreto e il costo del rewrite
  di ~11k righe Swift resta.
- **Tenere Expo come piano B** (ADR-0025 "accettata ma sospesa"): scartata — ambiguità su
  quale sia l'app vera, e nessun motivo per riaprirla.
- **Modulo `Scadenze` a sé** (con dati propri, separato da `documenti`): scartato — le
  scadenze che interessano davvero sono quelle dei documenti d'identità, quindi vivono come
  campo di `Documento`. Le scadenze generiche le copre il Calendario iOS.
- **Modulo clipboard con cattura automatica**: tecnicamente impossibile senza framework
  privati + hack (loop audio silenzioso), non distribuibile e dispendioso in batteria.

## Conseguenze
- Si buttano ~2 moduli di codice `gym` già scritti (sessione live, catalogo/import
  esercizi, Live Activity, editor schede) e i relativi XCUITest — vanno **rimossi**, non
  solo disabilitati. `GymMath` e i suoi test restano.
- ADR-0025/0026 restano nel repo come storico della decisione presa e ribaltata (come
  ADR-0002 → ADR-0022).
- Il modulo `documenti` introduce dati molto sensibili: obbliga a mettere il backend su
  HTTPS + backup **prima** di sincronizzarli (ADR-0028), lavoro infra finora rimandato.
- Il ciclo di ri-firma ogni ~7 giorni resta un costo manuale permanente finché non ci si
  iscrive al Developer Program — accettato consapevolmente.
- `apps/ios/README.md` e lo stato moduli vanno riscritti di conseguenza (fuori da questo
  ADR).
