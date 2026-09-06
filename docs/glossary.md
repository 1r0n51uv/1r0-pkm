# Glossario — 1r0-pkm

Termini di dominio usati nel codice, nello schema DB e nella UI. Fonte di verità per naming coerente tra moduli.

## Generali

- **1r0** — l'ombrello: la famiglia di app personali. Ogni app è un `1r0-<scope>`; questo repo è `1r0-pkm`. `1r0` da solo non è un'app, è la famiglia.
- **1r0-pkm** — questa app. Scope *personal knowledge management* inteso in senso ampio (gestione della vita personale): fa da bundle ai moduli `1r0-gym`, `1r0-note`, `1r0-diet` e ad altri moduli configurabili.
- **Modulo** — un `1r0-<scope>` (es. `1r0-gym`, `1r0-note`, `1r0-diet`, ...) incluso nell'app `1r0-pkm` e vissuto come tab dentro un'unica app. Unità di prima classe, potenzialmente attivabile/configurabile, non un'app separata da installare.
- **Utente / Profile** — singolo utente autenticato (`auth.users` di Supabase + riga `profiles`). L'app è single-user ma richiede login minimo per sincronizzare iOS ↔ Watch ↔ web.

## Modulo 1r0-gym

- **Exercise** — un esercizio del catalogo (es. "Panca piana"). Può avere `source`: `wger` (importato dall'API wger), `ai` (importato/strutturato via Claude), `custom` (inserito manualmente).
- **Routine** — una scheda di allenamento, composta da uno o più **Routine Day** (giorni: es. Push/Pull/Legs).
- **Routine Day** — un giorno della scheda, contiene una lista ordinata di **Routine Exercise**.
- **Routine Exercise** — un esercizio pianificato dentro un Routine Day, con target (serie, reps, riposo). Può appartenere a un **Superset Group**.
- **Superset Group** — raggruppamento di 2+ Routine Exercise eseguiti in sequenza senza riposo tra loro (es. A1/A2).
- **Workout Session** — un allenamento eseguito realmente, con `started_at`/`ended_at`. Può nascere dall'app o dal Watch (`source`).
- **Set Log** — una singola serie eseguita e loggata (peso in kg, reps, RPE opzionale), sempre modificabile/cancellabile anche a posteriori.
- **PR (Personal Record) / 1RM stimato** — massimale stimato per esercizio, calcolato dai Set Log (formula Epley), aggiornato ad ogni sessione.
- **Volume** — somma di (peso × reps) per esercizio/sessione/settimana, usato per i grafici di progresso.
- **Rest Timer** — cronometro di riposo tra serie, con notifica locale a fine countdown.

## Integrazioni

- **HealthKit sync** — scrittura di Workout Session verso Apple Health e lettura di peso corporeo/passi/calorie attive da Health verso i moduli `1r0-diet`/`1r0-gym`.
- **Watch companion** — target nativo watchOS (non Expo) che avvia/logga una Workout Session e sincronizza con l'app iOS via WatchConnectivity.
- **AI import** — ricerca di un esercizio via Claude API che propone dati strutturati (nome, gruppo muscolare, istruzioni) da confermare manualmente prima del salvataggio come `Exercise` con `source = 'ai'`.

## Progressione e coaching

- **Double progression** — regola algoritmica (no AI): aumenta peso quando l'utente completa tutte le serie al massimo reps del range target, altrimenti aumenta reps. Calcolo locale, offline.
- **Coaching Suggestion** — proposta di modifica a una `Routine` generata periodicamente da Claude (analisi dello storico), con stato `pending`/`accepted`/`rejected`. Mai applicata automaticamente.
- **Fase (Routine Phase)** — etichetta informativa su una `Routine`: `bulk`, `cut`, `deload`, `maintenance`. Non altera automaticamente i target.

## App Watch

- **Sessione pausata/annullata** — `WorkoutSession.status`: `paused` è ripresa più tardi, `cancelled` esclude la sessione da statistiche/streak/HealthKit ma non cancella i `SetLog` già inseriti.
- **Modifica "solo per oggi" vs template** — quando aggiungi una serie extra o cambi un peso dal Watch, l'app chiede sempre se applicarlo anche a `RoutineExercise` (le prossime volte) o solo alla sessione corrente.
- **Watch Settings** — preferenze haptics globali (`profiles.watch_settings`), sovrascrivibili per singolo esercizio (`RoutineExercise.hapticsOverride`).

## Corpo e strumenti

- **Body Measurement** — rilevazione periodica di peso, misure a nastro (chiavi libere) e foto, correlabile con volume/PR per vedere l'effetto degli allenamenti.
- **Plate Set Config** — bilanciere e dischi realmente disponibili all'utente, usati dal calcolatore piastre in-sessione.
- **Warm-up ramp** — serie di riscaldamento suggerite a percentuali fisse (40/60/80%) del peso di lavoro.

## Modulo 1r0-diet

- **Food** — un alimento del catalogo, con macro per 100g. `source`: `openfoodfacts`, `usda`, `custom`.
- **Recipe** — pasto riutilizzabile (template), composto da uno o più **Recipe Item** (food + quantità).
- **Meal Entry** — un pasto effettivamente consumato e loggato, con `meal_slot` (breakfast/lunch/dinner/snack). Composto da **Meal Entry Item**, che *snapshotta* calorie/macro al momento del log (non ricalcola da `Food` in seguito).
- **Planned Meal** — un pasto pianificato per una data futura; confermato diventa un Meal Entry collegato (`status: completed`), altrimenti resta `planned` o passa a `skipped`.
- **Shopping List Item** — voce di una lista della spesa persistente e spuntabile, generabile dai Planned Meal ma modificabile liberamente dopo.
- **Water Log / Supplement (Log) / Caffeine Log** — tre tracker semplici e separati dal log pasti: acqua in ml, integratori come checklist giornaliera, caffeina come voce rapida dedicata.
- **Nutrition Goal** — obiettivo calorico/macro in grammi assoluti, con una `mode` attiva alla volta (`manual`, `phase_linked`, `tdee`). Tabella *append-only*: cambiare obiettivo inserisce una nuova riga (`effective_from`), non sovrascrive la precedente — necessario per calcolare correttamente l'aderenza storica.
- **Fase collegata (phase_linked)** — l'obiettivo nutrizionale segue la fase della Routine attiva (bulk/cut/deload/maintenance, ADR-0015), ma solo su conferma esplicita dell'utente ad ogni cambio fase.
- **Andamento (report dieta)** — viste di sintesi calcolate lato client (ADR-0020, nessuna tabella nuova): serie giornaliera calorie/macro su 30/90 giorni, **aderenza al piano** (% giorni entro ±150 kcal dall'obiettivo *storicamente attivo* quel giorno), correlazione peso/calorie sullo stesso asse temporale.

## Infrastruttura

- **Self-hosted** — l'istanza Supabase (Postgres+Auth+Storage+Realtime+Functions) gira su un'istanza AWS EC2 di proprietà, non su Supabase Cloud (vedi ADR-0009).
- **Route server-side** — logica che non deve girare sul client (es. proxy Claude API per l'AI import esercizi, sync catalogo wger) esposta dal backend Fastify come route `/v1/...` (ADR-0022; era una Edge Function Deno prima di ADR-0022).
- **Outbox** — coda locale (SwiftData) di mutazioni non ancora sincronizzate col backend, riprocessata quando torna la rete (vedi ADR-0006).

## Moduli futuri (non ancora modellati)

- **1r0-note** — appunti collegabili (backlink), tag.
