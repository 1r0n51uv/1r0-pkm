# ADR-0033: Database di produzione separato da quello di sviluppo/test

## Status
Accettata

## Contesto
C'è una sola istanza EC2 (ADR-0009) con un solo container Postgres e un solo
database (`onepkm`), usato indistintamente per: (a) i test manuali su
simulatore durante lo sviluppo di questa sessione, (b) l'installazione beta
reale sul device dell'utente. Il risultato è dati misti — poche righe reali
insieme a righe di test (es. alcuni `Food` "pollo" da una prova di ricerca
OpenFoodFacts/USDA, `workout_sessions` con `source='app'` da test dev del 6-7
settembre). L'utente vuole un'istanza pulita per l'uso reale, senza questo
rumore, prima di continuare la beta.

Il catalogo `Food` non si popola con un import bulk: si materializza
on-demand quando l'utente cerca un alimento (`DietSync.searchRemote` →
OpenFoodFacts/USDA via backend, ADR-0018) e lo sceglie. Un database di
produzione pulito si popola quindi da solo con dati reali via uso normale
dell'app — non serve un dataset precaricato.

## Decisione
Un **secondo database Postgres sulla stessa istanza/container** (`onepkm_prod`,
nome configurabile via `PROD_DB_NAME`), non una seconda istanza EC2 né un
secondo stack Docker. Il container `api` si connette a `PROD_DB_NAME`
(nuova variabile in `docker-compose.yml`/`.env`) invece di `POSTGRES_DB`,
che resta il database "di bootstrap" inizializzato dal container `db` al
primo avvio (ADR-0022) — ora implicitamente "dati di sviluppo/test",
lasciato intatto come storico ma non più letto dall'api.

Il nuovo database si crea (`createdb`) e si migra applicando in ordine gli
stessi file `supabase/migrations/*.sql` già usati per `onepkm` — non
c'è automazione: quei file si auto-applicano solo al primissimo avvio del
container su un volume vuoto (mount `docker-entrypoint-initdb.d`), un
database creato dopo va migrato a mano, come già succede per ogni nuova
migrazione su un'istanza esistente (runbook consolidato più volte in
questa sessione).

## Conseguenze
- `Secrets.swift` (client iOS) non cambia: punta sempre allo stesso host/
  porta (`100.31.154.129`, ADR-0028 per l'HTTPS futuro) — è l'`api` dietro
  quell'endpoint che ora parla con un database diverso. Nessuna modifica
  lato client necessaria per questo ADR.
- `onepkm` (dev/test) resta sul disco, stesso volume Postgres — non
  cancellato, solo non più usato dall'api live. Recuperabile se serve
  confrontare/debuggare, altrimenti candidato a pulizia futura separata.
- D'ora in avanti, testare manualmente su simulatore/device contro il
  backend reale **scrive nel database di produzione** (l'unico che l'api
  ora vede) — non c'è più un database "di scarico" per i test manuali.
  Le XCUITest restano isolate (`ApiClient.offline` sotto `-uitest-reset`,
  ADR-0027) e non toccano nessuno dei due database.
- `pg_dump`/backup (ADR-0028, non ancora iniziato) andrà puntato su
  `PROD_DB_NAME`, non su `POSTGRES_DB`, quando verrà implementato.

## Alternative scartate
- **Nuova istanza EC2 dedicata**: scartata per costo e tempo di setup
  (nuovo IP, redeploy completo, aggiornare l'IP lato client) sproporzionati
  rispetto al problema — un secondo database nello stesso Postgres risolve
  la separazione dati senza toccare l'infrastruttura.
- **Nuovo stack Docker (secondo container `api`+`db` su porte diverse)**:
  scartato — più isolamento dei processi, ma più complessità da mantenere
  (due container api, due porte, due healthcheck) per lo stesso risultato
  di separazione dati che un secondo database ottiene con un comando `createdb`.
- **Riusare `onepkm` ma svuotarlo (`DELETE`/`TRUNCATE`) invece di crearne
  uno nuovo**: scartato, l'utente ha chiesto esplicitamente "una nuova
  istanza" — svuotare in place perde la possibilità di confrontare/
  recuperare i dati di test se servissero in futuro.
