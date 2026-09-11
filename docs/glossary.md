# Glossario — 1r0-pkm

Termini di dominio usati nel codice, nello schema DB e nella UI. Fonte di verità per naming coerente tra moduli.

## Generali

- **1r0** — l'ombrello: la famiglia di app personali. Ogni app è un `1r0-<scope>`; questo repo è `1r0-pkm`. `1r0` da solo non è un'app, è la famiglia.
- **1r0-pkm** — questa app. Scope *personal knowledge management* inteso in senso ampio (gestione della vita personale): un'unica app nativa iOS che fa da bundle a più **moduli**.
- **Modulo** — una sezione dell'app `1r0-pkm` (tab), con dati e funzioni propri; i moduli condividono infrastruttura (motore Promemoria, gateway HealthKit, sync/outbox, design system) sotto `Modules/Shared/`. Moduli v1: `1r0-gym`, `1r0-diet`, `1r0-documenti` (ADR-0027).
- **Utente / Profile** — singolo utente. L'app è single-user; il backend (`apps/api`, ADR-0022) autentica con una **chiave statica** (nessun login utente). La riga `profiles` è il singleton lato server.

## Modulo 1r0-gym (ADR-0027: import + storico + grafici; ADR-0030/0031: dashboard multi-esercizio + progressi corporei nella stessa tab)

- **Import CSV (Liftin')** — il modulo non logga allenamenti in-app: importa un CSV esportato dall'app **Liftin'** (`Date;Duration;Routine;Exercise;Set;Warmup;Weight;Reps/Time;Goal;Perception`, delimitatore `;`). Le righe si persistono in SwiftData + backend ("la nostra copia"). Re-import = **merge deduplicato** su `(Date + Exercise + Set)`.
- **Exercise** — solo un **nome** (stringa libera dal CSV, catalogo Liftin', misto IT/EN). Niente più catalogo in-app, niente `source` (wger/ai/custom), niente import wger/AI (ADR-0005 superseded).
- **Routine** — etichetta della scheda del giorno così com'è nel CSV (colonna `Routine`). **Non** è più un'entità editabile con giorni/esercizi: `RoutineDay`/`RoutineExercise`/`Superset Group` sono rimossi.
- **Workout Session** — un allenamento **importato** (read-only), identificato da `(Date, Routine)`. Non ha più lifecycle `active/paused/completed`: è sempre un record storico.
- **Set Log** — una singola serie importata: `weightKg`, `reps` (opzionale) **oppure** `durationSeconds` (esercizi a tempo, `Reps/Time` in `mm:ss`), `isWarmup`. Read-only.
- **PR (Personal Record) / 1RM stimato** — massimale stimato per esercizio, calcolato dai Set Log importati (formula Epley, `GymMath`).
- **Volume** — somma di (peso × reps) per esercizio/sessione/settimana per i grafici di progresso; ignora le serie `isWarmup` e quelle a 0 kg / a tempo.
- **Body Measurement** — rilevazione periodica di peso e misure a nastro (chiavi libere). Il peso corporeo per i grafici `gym` si legge da **HealthKit** (il CSV Liftin' non lo contiene). Sezione "Peso e misure" della tab Palestra (ex tab "Progressi", ADR-0031).
- **Dashboard grafici (Palestra)** — griglia con una mini-card (1RM stimato + sparkline) per ciascuno dei fino a 6 esercizi più allenati, in testa alla tab Palestra; toccarne una apre il drill-down con i grafici a tutta larghezza (1RM + volume). Non una sezione/tab separata (ADR-0030).

## Modulo 1r0-diet

- **Food** — un alimento del catalogo, con macro per 100g. `source`: `openfoodfacts`, `usda`, `custom`.
- **Recipe** — pasto riutilizzabile (template), composto da uno o più **Recipe Item** (food + quantità).
- **Meal Entry** — un pasto effettivamente consumato e loggato, con `meal_slot` a 5 valori (`breakfast` / `morning_snack` / `lunch` / `afternoon_snack` / `dinner`; `snack` generico rimosso, ADR-0024). Composto da **Meal Entry Item**, che *snapshotta* calorie/macro al momento del log (non ricalcola da `Food` in seguito).
- **Meal Slot Ack** — flag "slot ok oggi" (`{ data, slot }`): registrato quando l'utente risponde **Sì** al Promemoria pasto mancante. Silenzia il promemoria di quello slot per la giornata **senza** creare un Meal Entry (ADR-0027).
- **Planned Meal** — un pasto pianificato per una data (passata o futura, ADR-0032); confermato via lo switch mangiato/saltato diventa un Meal Entry collegato (`status: completed`), altrimenti resta `planned` o passa a `skipped`. Modificabile (ricetta/alimenti) finché non è `completed`; spegnere lo switch da `completed` cancella il Meal Entry collegato per poterlo correggere.
- **Diet Template** — dieta settimanale riutilizzabile (solo locale, non sincronizzata): assegna una Recipe **o un alimento semplice** (es. "noci", ADR-0032) per ciascuno dei 5 Meal Slot × 7 giorni (**Diet Template Item**, i due mutuamente esclusivi). "Applicare" un template a una settimana specifica genera i Planned Meal corrispondenti (ADR-0029).
- **Shopping List Item** — voce di una lista della spesa persistente e spuntabile, generabile dai Planned Meal ma modificabile liberamente dopo.
- **Water Log / Supplement (Log) / Caffeine Log** — tre tracker semplici e separati dal log pasti: acqua in ml, integratori come checklist giornaliera, caffeina come voce rapida dedicata.
- **Nutrition Goal** — obiettivo calorico/macro in grammi assoluti, con una `mode` attiva alla volta (`manual`, `phase_linked`, `tdee`). Tabella *append-only*: cambiare obiettivo inserisce una nuova riga (`effective_from`).
- **Quota giornaliera** — l'obiettivo calorico del **giorno corrente**, pari al Nutrition Goal di base aggiustato per l'**energia attiva** letta da HealthKit (ADR-0019 amendata). Non modifica la riga `nutrition_goals`.
- **Andamento (report dieta)** — viste di sintesi calcolate lato client (ADR-0020): serie giornaliera calorie/macro su 30/90 giorni, **aderenza al piano**, correlazione peso/calorie.

## Modulo 1r0-documenti (ADR-0027 / ADR-0028)

- **Documento** — un documento d'identità archiviato: `tipo` (**TipoDocumento**), campi testuali **fissi per tipo**, una o più **immagini** (fronte/retro), `dataScadenza` opzionale, `preavvisi` (giorni prima della scadenza, default 90/30).
- **TipoDocumento** — enum: `cartaIdentita`, `patente`, `passaporto`, `tesseraSanitaria`, … Determina i campi del form.
- **Acquisizione** — scanner documenti nativo (`VNDocumentCameraViewController`, ritaglio automatico) o libreria foto. Si salvano i **byte compressi originali** (HEIC/JPEG) con **Data Protection**, non bitmap decodificate.
- **Export PDF** — un PDF generato da immagini + campi del Documento, condivisibile.
- **Storage** — **solo su device, cifrato**, finché il backend non è su HTTPS (ADR-0028); poi sync cifrato via `apps/api` (`documento.*`). Non rispecchiato su `apps/web`.
- **Preavviso scadenza** — Promemoria (vedi sotto) generato dai `preavvisi` di un Documento con `dataScadenza`. Nessuna scrittura nel Calendario iOS.

## Promemoria e notifiche

- **Promemoria** — regola di dominio che rileva quando l'utente doveva fare qualcosa e non l'ha fatto, valutata sui dati già presenti (Water Log / HealthKit acqua, Meal Entry, Meal Slot Ack, `Documento.dataScadenza`, …). Concetto cross-modulo; il motore vive in `Modules/Shared/Reminders/`.
- **Notifica** — il messaggio di sistema (locale, sul device) con cui un Promemoria viene comunicato. Un Promemoria può essere valutato senza produrre una Notifica (condizione già soddisfatta).
- **Notifica azionabile** — Notifica con azioni (`UNNotificationAction`). Es. "Hai mangiato a &lt;slot&gt;?" con **Sì** (registra un Meal Slot Ack, gestito in background senza aprire l'app) e **Rimanda** (ri-schedula a +30 min).
- **Promemoria acqua** — valutato a cadenza fissa nella fascia diurna; notifica se il totale acqua di oggi (Water Log + HealthKit) è sotto la quota proporzionata all'ora. Se `waterMlTarget` non è impostato usa un default.
- **Promemoria pasto mancante** — uno per ciascuno dei 5 Meal Slot, vicino al suo orario atteso (default sovrascrivibile dall'utente). Notifica se a quell'ora non esiste un Meal Entry **né** un Meal Slot Ack per quello slot in giornata.
- **Preavviso documento** — vedi modulo `1r0-documenti`.
- **Impostazioni** — tab dell'app (`DietSettingsView`, ex `NotificationSettingsView`, poi ex sheet dall'header Dieta) con 4 sezioni: Salute (toggle HealthKit, ADR-0029), Notifiche (un interruttore per categoria di Promemoria, es. "Acqua"/"Pasto mancante", non per singola istanza), Report (link all'Andamento), Database (toggle dev/prod, ADR-0034). Al posto della vecchia tab "Progressi" (ADR-0031).

## Integrazioni

- **HealthKit** — gateway condiviso (`Modules/Shared/HealthKit/`). `diet` **scrive** energia alimentare + macro (`dietary*`) per ogni pasto e **legge** peso corporeo, acqua ed energia attiva. `gym` **legge** solo il peso corporeo. Nessuna scrittura di workout (il `gym` non crea più sessioni). Vedi ADR-0004 amendata.
- **Collegamento Salute (toggle)** — interruttore esplicito lato app (`HealthKitPreference`, `UserDefaults`) che abilita/disabilita letture e scritture HealthKit del modulo `diet`, in aggiunta (non in sostituzione) al permesso di sistema. Prima voce di **Impostazioni Dieta**. ADR-0029.
- **Watch companion** — *congelato* (ADR-0016 superseded): il target `1r0-pkm-w Watch App` esiste nel repo ma è fuori dalla build (non distribuibile via sideload sul piano gratuito).

## Infrastruttura

- **Backend** — `apps/api` (Node/Fastify + Postgres, ADR-0022) su un'istanza AWS EC2 di proprietà (ADR-0009). Auth a chiave statica. Da portare su **HTTPS + backup** prima del sync `documenti` (ADR-0028). Database di produzione separato da quello di sviluppo/test — stesso Postgres, database diverso (`PROD_DB_NAME`, ADR-0033), scelto per-richiesta dall'header `X-Db-Target` (interruttore "Usa database di sviluppo" in Impostazioni, ADR-0034).
- **Route server-side** — logica esposta dal backend Fastify come route `/v1/...` (ADR-0022).
- **Outbox** — coda locale (SwiftData) di mutazioni non ancora sincronizzate col backend, riprocessata quando torna la rete (ADR-0006 amendata). Condivisa da tutti i moduli (`Modules/Shared/Sync/`).

## Moduli futuri / rimandati

- **1r0-clipboard** — lista di "ritagli" (testi/immagini salvati a mano via Share Extension). Rimandato: iOS non consente la cattura automatica della clipboard (ADR-0027).
- **1r0-note** — appunti collegabili (backlink), tag.
