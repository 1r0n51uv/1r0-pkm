# ADR-0026: Piano d'azione Expo — spike → modulo diet → modulo gym

## Status
**Superseded da [ADR-0027](0027-stop-expo-hub-modulare-nativo.md)** insieme ad
[ADR-0025](0025-expo-nuovo-filone-implementazione.md): il filone Expo è stato abbandonato
prima di iniziare lo spike. Contenuto lasciato per storico.

## Contesto
[ADR-0025](0025-expo-nuovo-filone-implementazione.md) avvia un filone di implementazione Expo parallelo al nativo. Come per il nativo ([ADR-0021](0021-piano-azione-workflow.md): spike Watch → AWS → layout → pagine di prova), si valida prima con spike usa-e-getta ciò che è incerto, e solo dopo si costruisce. Questa volta il rischio principale — il bridge Watch↔RN — viene effettivamente testato invece di essere solo assunto (era stato scartato da ADR-0010 senza mai uno spike).

## Decisione

### 1. Spike (branch `spike/*`, throwaway, come da `CONTRIBUTING.md`)
Valida in parallelo:
- **Notifiche locali ricorrenti in background** (`expo-notifications`) — cuore del sistema di Promemoria (`docs/glossary.md`).
- **Connessione end-to-end al backend esistente** — riuso del client REST (pattern `packages/shared/src/api/client.ts`) da React Native verso `apps/api`, stessa API key statica (ADR-0022).
- **Scanner codice a barre** equivalente a `VisionKit`/`DataScannerViewController`, richiesto già dal modulo diet (`LogFoodView`/`BarcodeScannerView`).
- **Bridge Watch↔RN** via `WatchConnectivity` — Hello World bidirezionale, riusando il target watchOS Swift esistente quasi com'è; cambia solo il lato iPhone (oggi Swift, diventa un modulo nativo custom richiamato da JS). Non serve al modulo diet, ma si valida subito per chiudere il rischio lasciato aperto da ADR-0010 prima di investire nel resto.
- **Build e installazione di un development client custom gratuito** (Personal Team) — prerequisito tecnico del bridge Watch e dello scanner, entrambi moduli nativi non disponibili in Expo Go.

### 2. Modulo `1r0-diet` (prima release Expo)
Tutte le 4 slice già esistenti nel nativo (contacalorie, ricette+pianificazione, lista spesa, tracker) più il sistema di Promemoria (acqua nudge fisso, acqua su target, pasto mancante per slot — `docs/glossary.md`) e l'estensione di `MealSlot` a 5 valori ([ADR-0024](0024-meal-slot-cinque-valori.md)). Dentro un'unica app modulare Expo (coerente con ADR-0008), non un'app a sé.

Durante questa fase `apps/ios` (nativo) resta l'unica app per `1r0-gym`/Watch: l'utente ha temporaneamente due app installate per coprire tutte le funzioni.

### 3. Modulo `1r0-gym` (incluso Watch)
Solo dopo il modulo diet, informato dall'esito dello spike bridge Watch.

### 4. Automazione build (solo dopo che il ciclo manuale funziona)
Pipeline GitHub Actions che compila e pubblica un IPA come artifact (runner macOS gratuito, repo pubblico), installato via sideload (Sideloadly/AltStore). Non elimina il rinnovo manuale del provisioning profile ogni ~7 giorni via Xcode (limite Apple sugli account gratuiti, non automatizzabile senza il Developer Program: i profili gratuiti si generano solo dentro Xcode, nessuna API pubblica è disponibile senza iscrizione a pagamento) — automatizza solo il resto della pipeline (build, export IPA, artifact). Trattata come lavoro successivo, non parte dello spike iniziale.

## Conseguenze
- Il rischio Watch↔RN, lasciato solo teorico da ADR-0010, viene questa volta effettivamente testato prima di costruire il modulo gym sopra.
- Due app installate in parallelo durante la fase 2 (tra rilascio diet e rilascio gym) è un compromesso accettato, non un problema da risolvere.
- Il ciclo di refresh manuale del provisioning profile (~7 giorni, per sempre finché si resta gratis) resta anche con la pipeline CI: la CI velocizza tutto il resto, non quel passaggio.
