# ADR-0010: Swift/SwiftUI nativo per iOS + watchOS (supersede Expo)

## Status
Accettata

## Contesto
La prima ipotesi era Expo/React Native con un modulo nativo custom per il target Watch (bridge RN↔WatchConnectivity), da validare con uno spike prima di costruire feature sopra — scartata prima ancora di essere implementata. Diventando disponibile una VM macOS per lo sviluppo locale, si è rivalutata l'opzione "tutto nativo" scartata inizialmente solo per il costo di doppia implementazione con il web.

## Decisione
- App iOS e app Watch scritte **interamente in Swift/SwiftUI**, un solo progetto Xcode (`apps/ios/`) con due target (iOS + watchOS) nello stesso workspace.
- `WatchConnectivity` usato nativamente (framework Apple diretto, nessun bridge/modulo custom da mantenere).
- Il web (`apps/web`, Next.js) resta come dashboard secondaria, **senza condivisione di codice** con l'app nativa: comunicano solo tramite il backend (Supabase self-hosted, vedi ADR-0009).
- `packages/shared` (TypeScript) resta utile solo per codice condiviso lato JS/TS: `apps/web` e le Supabase Edge Functions (`supabase/functions/`), non per il mobile.
- Persistenza locale: **SwiftData** (vedi anche ADR-0006 aggiornata).
- Gestione dipendenze: Swift Package Manager (niente CocoaPods se evitabile).

## Alternative scartate
- **Expo + modulo nativo custom**: scartata per il rischio di integrazione bridge↔Watch, non più necessario ora che la doppia implementazione Swift/React è accettata esplicitamente.
- **Expo ora, Watch dopo**: scartata, il requisito Watch è day-1.

## Conseguenze
- **Costo**: ogni feature del modulo `1r0-gym` (e futuri `1r0-note`/`1r0-diet`) va scritta due volte se serve anche sul web — accettato perché il web è dashboard marginale, non l'esperienza primaria.
- **Learning curve**: Swift/SwiftUI da imparare da zero — rischio noto e accettato, mitigato costruendo il modulo `1r0-gym` come primo terreno di apprendimento pratico.
- **Toolchain**: serve macOS (VM o hardware) per build/dev/test — è vero per il 100% dello sviluppo mobile, non solo per il target Watch.
- Nessuna dipendenza da versioni Expo SDK/RN da tenere allineate al codice nativo: un solo ecosistema (Apple) da seguire.
