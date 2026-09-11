# ADR-0034: Switch database dev/prod in Impostazioni

## Status
Accettata

## Contesto
ADR-0033 ha separato i dati reali (`onepkm_prod`) da quelli di sviluppo/test
(`onepkm`) sul backend, ma l'unico modo per il client di raggiungere il
database di test era prima (temporaneamente, durante quell'ADR) ripuntare
l'intero `docker-compose.yml` — un cambio manuale sul server, non qualcosa
che l'utente può fare dal telefono. Serve un modo per testare manualmente
sul device/simulatore senza scrivere nel database reale, senza dover
toccare l'infrastruttura ogni volta.

## Decisione
**Un interruttore in Impostazioni** ("Usa database di sviluppo",
`DBTargetPreference`, `UserDefaults` locale) fa sì che `ApiClient` mandi
l'header `X-Db-Target: dev` su ogni richiesta quando è acceso. Il backend
(`apps/api/src/db.js`) mantiene **due pool** (`DATABASE_URL` = prod,
`DATABASE_URL_DEV` = dev) dietro un `Proxy` che espone la stessa interfaccia
di prima (`pool.query(...)`, `pool.connect()`): quale pool viene usato per
una richiesta si decide in un hook `onRequest` (`server.js`) che legge
l'header e lo salva in un `AsyncLocalStorage` — **non** una variabile
globale mutabile, quindi niente race fra richieste concorrenti con target
diversi (verificato con richieste parallele interlacciate dev/prod).
Nessuna delle ~12 route esistenti è stata toccata: continuano a fare
`pool.query(...)` come sempre, ignare del cambio.

## Conseguenze
- Il toggle **non svuota la cache locale SwiftData**: cambiare target a
  metà sessione mescola nel cache locale dati provenienti da entrambi i
  database finché l'app non riparte da uno store pulito. Comportamento
  noto e documentato in `DBTargetPreference.swift`, nessun meccanismo di
  pulizia automatica aggiunto (fuori scope, stesso limite di qualunque
  cambio di store locale in questa app).
- `DATABASE_URL_DEV` non impostata (es. sviluppo locale/CI con un solo
  database) → il target "dev" ricade silenziosamente su prod invece di
  rompere l'avvio del processo.
- L'header è di fiducia: chiunque sia già autenticato (stesso bearer
  statico, ADR-0022) può scegliere il database con cui parla. Accettabile
  per un'app single-user — l'header sceglie solo *quale* copia dello stesso
  schema si usa, non aggira l'autenticazione né espone più dati.
- Toggle verificato manualmente in produzione con richieste concorrenti
  interlacciate (dev/prod) prima del merge — nessun mix di righe fra i due
  database.

## Alternative scartate
- **Due container `api` su porte diverse** (uno per dev, uno per prod):
  scartata a favore di un solo processo con routing per-richiesta — stesso
  compromesso già scartato in ADR-0033 (più isolamento, più complessità da
  mantenere) per un problema che l'`AsyncLocalStorage` risolve senza
  duplicare l'intero servizio.
- **Variabile globale mutabile per il pool corrente** (settata nell'hook,
  letta da ogni route): scartata — race condition reale fra richieste
  concorrenti con target diversi (A setta dev, B setta prod prima che la
  query di A parta, A finisce per interrogare il database di B). L'uso di
  `AsyncLocalStorage` con propagazione per-richiesta evita esattamente
  questo, senza sacrificare la trasparenza per le route esistenti.
