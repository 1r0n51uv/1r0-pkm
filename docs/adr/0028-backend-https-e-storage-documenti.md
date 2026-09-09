# ADR-0028: Backend su HTTPS + storage cifrato dei documenti + backup

## Status
Accettata — prerequisito del modulo `documenti` di [ADR-0027](0027-stop-expo-hub-modulare-nativo.md).
Chiude i "non fatti" di [ADR-0009](0009-self-hosted-supabase-aws.md) (niente backup) e
l'eccezione ATS temporanea documentata in `apps/ios/README.md`.

## Contesto
Finora il backend (`apps/api`, ADR-0022) gira su un IP EC2 nudo in **HTTP in chiaro**, con
un'eccezione ATS mirata nell'`Info.plist`, autenticazione a **chiave statica singola** e
**nessun backup** (rischio accettato in ADR-0009 finché i dati erano solo allenamenti/dieta,
"la copia vera sta nel backend" e viceversa).

Il modulo `documenti` (ADR-0027) archivia carta d'identità, patente, passaporto: immagini +
dati testuali. Sincronizzare questo su un canale in chiaro, verso una macchina senza backup,
non è accettabile. In fase di planning si è scelto: **sync dei documenti solo dopo aver reso
sicuro il canale**; fino ad allora i documenti restano solo sul device, cifrati.

## Decisione
- **HTTPS sul backend.** Puntare un dominio (sottodominio dedicato) sull'IP EC2 e impostare
  `API_DOMAIN` a quell'hostname: `infra/Caddyfile` fa già `reverse_proxy api:8080`, Caddy
  ottiene e rinnova il certificato via ACME automaticamente. Aggiornare `Secrets.swift`
  (`apiBaseURL`) e **rimuovere l'eccezione ATS** dall'`Info.plist` iOS.
- **Backup.** `pg_dump` giornaliero cifrato verso un bucket S3 (retention breve, es. 14
  giorni). Cron sull'istanza o container dedicato nello stack compose. Documentato in
  `infra/`.
- **Cifratura at-rest dei documenti sul server.** Le immagini dei documenti non stanno in
  Postgres come blob in chiaro: cifrate lato client (chiave sul Keychain del device) prima
  dell'upload, il server ne conserva solo il ciphertext + i metadati non sensibili. Il
  server non può leggere il contenuto di un documento. (Dettaglio dello schema di chiave da
  definire in implementazione: passphrase utente vs chiave random nel Keychain con sync
  disabilitato.)
- **Ordine.** Questo lavoro (HTTPS + backup) è lo **step 5** della sequenza di ADR-0027:
  dopo `gym` e `diet`, prima di `documenti`. Il modulo `documenti` si costruisce comunque
  prima come **local-only cifrato**; il sync si accende quando il canale è pronto.

## Alternative scartate
- **Sync dei documenti sul canale HTTP attuale**: scartata — passaporto e patente in chiaro
  verso un IP nudo senza backup.
- **`documenti` per sempre local-only, nessun sync**: scartata — si perde la copia se si
  perde il telefono (niente iCloud sul piano gratuito) e non si vede nulla da `apps/web`
  (anche se per ora `documenti` non è sul web comunque). Tenuta come fallback se l'HTTPS
  slitta.
- **Passare a un backend gestito con TLS incluso** (di nuovo Supabase Cloud o simili):
  fuori scope, ADR-0022 ha già deciso il contrario per il resto dei motivi.
- **Cifratura solo del trasporto (HTTPS) senza cifratura at-rest**: scartata per i
  documenti d'identità — un accesso al DB/istanza esporrebbe tutto.

## Conseguenze
- Serve registrare/gestire un dominio (costo minimo) e tenere il DNS puntato all'IP EC2
  (IP elastico consigliato per non doverlo ri-puntare ai riavvii).
- Il backup `pg_dump` → S3 aggiunge una credenziale AWS sull'istanza e un piccolo costo
  storage — trascurabile, molto inferiore al rischio che copre.
- La cifratura client-side dei documenti complica il modulo `documenti` (gestione chiave,
  recupero se si cambia device) e rende quei dati **non** rispecchiabili su `apps/web` senza
  portare la chiave nel browser — coerente con la scelta di ADR-0027 di non metterli sul web.
- Una volta su HTTPS, l'eccezione ATS sparisce e l'app è più vicina a poter essere
  distribuita in modo diverso in futuro (TestFlight se ci si iscrive al Developer Program).
