# ADR-0008: Architettura a moduli dentro un'unica app

## Status
Accettata — struttura cartelle rivista dopo [ADR-0010](0010-swift-native-ios-watch.md) (Swift nativo invece di Expo).

## Contesto
1r0-pkm copre più domini (`1r0-gym`, `1r0-note`, `1r0-diet`, ...). Vanno organizzati senza trasformare ogni dominio in un'app separata da mantenere.

## Decisione
- Una sola app iOS (Swift/SwiftUI, `apps/ios/`) con navigazione a tab, una tab per modulo; stesso target watchOS riusa le stesse feature Swift dove sensato (es. il modulo `1r0-gym`). Stessa cosa lato web (sezioni, non sotto-app separate).
- Ogni modulo vive come cartella isolata:
  - `apps/ios/1r0-pkm/Modules/<Modulo>/` (Swift: Views, ViewModels, SwiftData models del modulo)
  - `apps/web/app/<modulo>/` (routing Next.js)
- I moduli **non condividono codice tra iOS e web** (vedi ADR-0010/0001): l'unico contratto comune è lo schema Supabase (`supabase/migrations/`).
- Il modulo **`1r0-gym`** è il primo implementato (MVP); `1r0-note` e `1r0-diet` seguiranno la stessa struttura di cartelle quando verranno grillati e modellati a loro volta.
- Auth e schema DB (Supabase self-hosted, ADR-0009) sono condivisi trasversalmente a tutti i moduli fin dall'inizio (una tabella `profiles`, RLS per `user_id` su ogni tabella di modulo).

## Conseguenze
- Nessun overhead di deploy/routing tra moduli (un solo build per piattaforma).
- Richiede disciplina nel non far "trapelare" dipendenze dirette tra cartelle di moduli diversi all'interno della stessa app (comunicano solo tramite lo schema Supabase, mai import diretti cross-modulo).
