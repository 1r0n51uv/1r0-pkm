# ADR-0038: Fix — entitlement HealthKit assente a runtime sul sideload

## Status
Accettata

## Contesto
Dopo il fix entitlements di ADR-0036 (rimosse due chiavi App Sandbox
macOS-only, non valide su iOS), l'attivazione di Salute sul device
sideload falliva ancora — build 7 (ADR-0037) ha reso visibile l'errore
esatto via `HealthKitStatus`: **"richiesta permessi Salute fallita:
com.apple.developer.healthkit entitlement"**. Questo è un errore che
HealthKit stesso genera quando il binario firmato non ha l'entitlement a
runtime, anche se `_r0_pkm.entitlements` (sorgente) è corretto — quindi il
problema è nella firma di SideStore, non nel codice.

`docs/adr/0027-stop-expo-hub-modulare-nativo.md` aveva già verificato che
HealthKit **è gratuito anche su Personal Team** (non serve l'Apple
Developer Program a pagamento) — quindi non è un limite di piano.

Diagnosi (con l'utente, che ha verificato sul proprio dispositivo/account):
- SideStore ri-firma l'app automaticamente ogni ~7 giorni, e l'errore
  persiste attraverso questi refresh → non è un profilo/certificato
  scaduto o cache stantia risolvibile da sola col tempo.
- L'utente non ha accesso alla sezione "Certificati, Identificativi e
  Profili" di developer.apple.com — coerente con un Apple ID Personal
  Team: quella UI web è riservata ai membri a pagamento del Developer
  Program. Le App ID di un account gratuito sono gestite solo tramite le
  API private che Xcode (o SideStore, che le replica) usa per la firma
  automatica — nessun controllo manuale disponibile.
- Apple limita un account gratuito a un numero ridotto di **nuove**
  registrazioni di App ID entro una finestra di 7 giorni: è plausibile che
  SideStore, per non consumare quella quota, **riutilizzi la stessa
  registrazione App ID** ad ogni ri-firma invece di ricrearla — quindi se
  la registrazione originale (creata prima che l'entitlements includesse
  HealthKit in modo pulito) non ha mai richiesto la capability, ogni
  refresh successivo la "ri-firma" senza mai correggerla.
- Non risulta un'opzione "revoca certificato"/"refresh completo" distinta
  dal reinstallo nelle impostazioni dell'app SideStore.

## Decisione
Cambiato il bundle identifier dell'app (`PRODUCT_BUNDLE_IDENTIFIER`) da
`dev.1r0.pkm` a `dev.1r0.pkm2` (target principale + target di test; i
target `watchkitapp` orfani, non più nello scheme attivo dalla rimozione
del Watch — commit `7e10b72` — non sono stati toccati). SideStore compone
l'App ID reale come `<bundle id>.<suffisso per team>` (`releases/README.md`):
un bundle id diverso costringe SideStore a registrare un'App ID
**completamente nuova** sul prossimo install, invece di riutilizzare quella
esistente — bypassa lo stato bloccato senza bisogno di accesso al portale.

Verificato prima del cambio che nessun'altra parte del codice dipenda dal
bundle id letterale: i `BGTaskScheduler` identifier (`dev.1r0.pkm.sync`,
`dev.1r0.pkm.reminders`, `SyncEngine.swift`/`RemindersEngine.swift`) sono
stringhe arbitrarie elencate in `Info.plist`
`BGTaskSchedulerPermittedIdentifiers`, non derivate dal bundle id — restano
valide con qualunque bundle id. Nessun App Group in uso. Nessun riferimento
al bundle id fuori da `apps/ios` (solo doc).

## Conseguenze
- **L'app diventa "nuova" agli occhi di SideStore/iOS**: va disinstallata
  la vecchia e installata da zero — SwiftData locale non sincronizzato
  (outbox non ancora inviato) andrebbe perso, ma l'app è offline-first con
  sync verso il backend (ADR-0006): al prossimo avvio i dati già
  sincronizzati vengono ripescati da `pull*`, solo le modifiche fatte
  offline e mai sincronizzate andrebbero rifatte.
- Se il problema persiste anche con un'App ID nuova di zecca, il prossimo
  sospetto è l'Apple ID stesso (non solo l'App ID) — l'utente ha proposto
  di generarne uno nuovo da usare in SideStore, opzione più pesante (login
  SideStore/AltServer da rifare, nuovo team Apple da zero) tenuta in
  riserva se questo fix non basta.
- Non riproducibile in CI/simulatore (il problema esiste solo nella catena
  di firma reale SideStore + account Apple): la sola verifica possibile è
  l'installazione sul device dell'utente.
