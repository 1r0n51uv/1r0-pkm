# ADR-0022: Backend custom Node.js/Fastify (supersede Supabase)

## Status
Accettata — supersede [ADR-0002](0002-supabase-backend.md) e [ADR-0009](0009-self-hosted-supabase-aws.md) per le parti Auth/RLS/Storage/Edge Functions. La scelta di Postgres come DB e di un'istanza AWS EC2 self-hosted (ADR-0009) restano valide: cambia il software che gira sopra, non dove gira.

## Contesto
Decisione presa durante la revisione dei mockup/ADR ma mai scritta in un'ADR dedicata — le migration SQL erano già state ripulite da `auth.uid()`/RLS/`create policy` (vedi `supabase/migrations/`) in previsione di questo cambio, ma `docs/adr/0002` e `0009`, `infra/README.md`, `apps/ios/README.md` e `packages/shared/src/supabase/client.ts` sono rimasti riferiti a Supabase, creando un disallineamento tra codice/migration e documentazione. Questa ADR chiude quel disallineamento prima che lo spike backend (issue #2) e il TDD sul modulo `1r0-gym` puntino a un bersaglio sbagliato.

App resta single-user: l'unico vero bisogno di "auth" è impedire accesso non autorizzato all'API dal pubblico, non gestire più account.

## Decisione
- **Niente Supabase come software**: si rimuove Auth, RLS, Realtime ed Edge Functions gestite da Supabase. Postgres resta l'unico DB (ADR-0002 restava comunque valida su questo punto), self-hosted su AWS EC2 (ADR-0009 resta valida sull'hosting).
- **Servizio API custom**: Node.js + **Fastify**, unico processo dietro Caddy (stesso reverse proxy/TLS già previsto in ADR-0009), che espone REST verso iOS/Watch/web e parla direttamente a Postgres (`pg`/`postgres.js`, non un ORM pesante — schema già scritto in SQL puro nelle migration).
- **Auth: API key statica**, non magic link/JWT. Un solo header (`Authorization: Bearer <key>`) generato una volta e configurato sui client (iOS/Watch tramite `Config.xcconfig`/`Secrets.swift` non committato, come già previsto in `apps/ios/README.md`; web via variabile d'ambiente). Nessuna sessione, nessun refresh token: coerente con "single-user", elimina la superficie Auth di Supabase senza reintrodurne una equivalente scritta a mano.
- **Autorizzazione nel servizio, non nel DB**: nessuna Row Level Security — con un solo utente reale e una sola API key, RLS filtrata per `auth.uid()` non ha un ruolo da giocare; il servizio Fastify è l'unico client di Postgres e non ha bisogno di isolare righe per utente.
- **Le due Edge Functions** (`supabase/functions/ai-import-exercise`, `coaching-review`) diventano route del servizio Fastify (stessa logica, stesso proxy verso Claude API per l'import AI esercizi/ADR-0005 e la revisione coaching/ADR-0011), non più funzioni serverless separate.
- **Storage: rimandato**. Niente equivalente di Supabase Storage in questo giro — le immagini/video esercizio restano URL esterni (wger o import AI, ADR-0005); upload di media custom da utente non è nello scope attuale, da riaprire con una nuova ADR se serve.
- **Realtime: non serve**. La sync Watch→iPhone passa da `WatchConnectivity` nativo (ADR-0016), non da Postgres Realtime; iPhone→backend passa dall'outbox offline-first (ADR-0006), un semplice POST/PATCH REST, non richiede push lato server.

## Alternative scartate
- **Restare su Supabase self-hosted** (ADR-0009 così com'è): scartata — Auth/RLS/Realtime sono overhead per un'app a singolo utente reale, e l'operatività di uno stack Supabase completo (aggiornamenti, container multipli) è più complessa di un singolo processo Fastify per lo stesso risultato pratico.
- **Nessun backend, solo client locali**: scartata da subito (invariato rispetto ad ADR-0002) — serve comunque sincronizzare iOS↔Watch↔web sugli stessi dati.

## Conseguenze
- **Migration SQL**: già pronte (`supabase/migrations/0001`-`0004`, ripulite da RLS/`auth.users` in una sessione precedente); restano la fonte di verità dello schema, applicate con `psql` diretto invece che via CLI Supabase.
- **Da aggiornare quando si esegue lo spike backend (issue #2, non in questa ADR)**: `infra/README.md` (stack Docker Compose Supabase → Postgres+Fastify), `apps/ios/README.md` (dipendenza `supabase-swift` → client REST semplice/`URLSession`), `packages/shared/src/supabase/client.ts` (rinominare/riscrivere come client generico), cartella `supabase/functions/` (migrare le due funzioni a route Fastify), issue #2 stessa (titolo e contenuto riferiscono ancora Supabase self-hosted).
- **Nessun multi-utente futuro senza ulteriore lavoro**: se in futuro servissero altri utenti reali, l'API key statica e l'assenza di RLS vanno riviste da capo — accettato perché fuori scope per un progetto personale.
- Un solo processo da monitorare/aggiornare invece di uno stack multi-container: operatività più semplice, ma nessuna delle funzionalità pronte all'uso di Supabase (dashboard admin, gestione Auth via UI) — accettabile perché mai state usate nella pratica finora.
