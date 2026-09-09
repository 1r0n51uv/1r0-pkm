# ADR-0025: Expo come nuovo filone di implementazione, parallelo al nativo

## Status
**Superseded da [ADR-0027](0027-stop-expo-hub-modulare-nativo.md).** Il filone Expo è stato
abbandonato: la ricerca ha tolto l'unico vantaggio concreto (le notifiche locali sono alla
pari, il nativo è anzi migliore sul tap ad app terminata) e ha refutato il vincolo di
partenza (HealthKit, Live Activities, notifiche, WidgetKit funzionano gratis sul Personal
Team). Contenuto lasciato per storico della decisione.

## Contesto
[ADR-0010](0010-swift-native-ios-watch.md) aveva scelto Swift/SwiftUI nativo invece di Expo per iOS+Watch, soprattutto per il rischio del bridge RN↔WatchConnectivity — mai validato con uno spike, solo assunto come troppo rischioso.

Da allora è emerso un vincolo pratico indipendente dal framework: gran parte delle funzionalità premium di Apple (HealthKit, push notification remote, distribuzione TestFlight/App Store, build che non scadono ogni 7 giorni) richiede l'iscrizione all'Apple Developer Program (99$/anno) — nativo o Expo che sia. Si vuole poter sviluppare e usare l'app senza questo costo, riservandosi di pagare più avanti se necessario.

## Decisione
Si avvia un filone di implementazione parallelo in Expo/React Native, `apps/expo` (sorella di `apps/ios`), con l'obiettivo dichiarato di sostituire ed eventualmente deprecare il nativo se il filone Expo raggiunge copertura funzionale sufficiente. Segue la stessa architettura a moduli di [ADR-0008](0008-single-app-module-architecture.md): un'unica app, una tab per modulo — non tante app separate.

A differenza dell'assunzione di ADR-0001/0010 ("niente condivisione di codice web/mobile", valida per il nativo Swift), Expo essendo TypeScript potrà in futuro condividere tipi/logica pura con `apps/web` tramite `packages/shared` — non componenti UI: la direzione visiva di Expo resta propria, valutata separatamente (nessun design system unico con il web, per ora).

Scelte sul costo, valide finché non si paga il Developer Program:
- **Rimandate**: HealthKit (salvataggio su Salute, FC live durante l'allenamento), distribuzione TestFlight/App Store.
- **Mantenute gratis**: Watch (WatchConnectivity via un bridge custom lato iPhone; il target watchOS resta Swift e in gran parte riusabile com'è; limite noto — build su Personal Team scade ogni 7 giorni), notifiche locali (sistema di Promemoria, vedi `docs/glossary.md`), Siri Shortcuts/App Intents, scanner codice a barre (equivalente RN da individuare in fase di spike).

## Conseguenze
- Durante la transizione, `apps/ios` (nativo) resta necessario per `1r0-gym`/Watch/HealthKit finché il filone Expo non copre anche quel modulo — utente con due app installate nel frattempo (vedi piano d'azione, ADR-0026).
- `packages/shared` può estendersi a coprire anche Expo, non più solo `apps/web` + Supabase functions come assumeva ADR-0010.
- Il rischio bridge Watch↔RN, lasciato solo teorico da ADR-0010, viene questa volta effettivamente validato con uno spike prima di costruirci sopra (vedi ADR-0026) — non scartato a priori come la prima volta.
- Restare sul piano gratuito comporta un ciclo manuale ricorrente a tempo indeterminato (rinnovo del provisioning profile via Xcode ogni ~7 giorni, non automatizzabile senza il Developer Program) — accettato consapevolmente.

## Alternative scartate
Nessuna nuova rispetto alla scelta originale nativo-vs-Expo, già discussa in ADR-0010: questa ADR ne aggiorna l'esito alla luce del vincolo di costo emerso dopo, non riapre quella valutazione.
