# ADR-0035: Fix — query string persa da `appendingPathComponent`

## Status
Accettata

## Contesto
Segnalato: la ricerca alimenti (OpenFoodFacts/USDA, ADR-0018) non dava mai
risultati, es. cercando "pane" o "bread". Il backend, testato via `curl`
direttamente, rispondeva correttamente con risultati veri per entrambe le
query — il problema non era nel backend.

Root cause in `ApiClient.request(_:_:body:)`:
```swift
var req = URLRequest(url: Secrets.apiBaseURL.appendingPathComponent(path))
```
`path` per la ricerca è `"v1/foods/search?q=pane"` — una stringa
path **+ query string**. `URL.appendingPathComponent(_:)` non lo sa: tratta
l'intera stringa come un singolo segmento di percorso e fa percent-escape
del `?`, producendo `http://…/v1/foods/search%3Fq=pane` — 404 lato server
(`Route GET:/v1/foods/search%3Fq=pane not found`), silenziosamente
inghiottito dal `catch { return [] }` di `searchRemote`.

Trovato isolando la chiamata da un hook di debug in `_r0_pkmApp` (bypassa
la UI), che ha esposto l'errore altrimenti insabbiato dal `catch` — stesso
approccio già usato per [[swiftdata-new-model-schema-1r0-pkm]].

**Perché non l'ha mai preso nessun XCUITest**: ogni UI test gira con
`-uitest-reset`, che rende `ApiClient` `offline` (ADR-0027) — `request(...)`
lancia subito, non arriva mai a costruire l'URL sbagliato. Il bug era
raggiungibile solo con una vera chiamata di rete, mai esercitata da CI.

## Decisione
`URL(string: path, relativeTo: Secrets.apiBaseURL)` al posto di
`appendingPathComponent` — l'inizializzazione relativa di `URL` interpreta
correttamente path *e* query string secondo RFC 3986. Fix centralizzato in
un solo punto (`ApiClient.request`): tutti i chiamanti (`get`/`post`/`put`/
`patch`/`delete`) ne beneficiano, non solo la ricerca.

## Conseguenze
- **Bug più esteso della sola ricerca**: `DietSync.pullPlannedMeals`
  costruisce anch'essa un path con query string
  (`"v1/planned-meals?from=…&to=…"`) — stesso bug, mai notato perché anche
  quella chiamata è silenziosa (`catch {}`) e mai esercitata online dai
  test. Con questo fix è risolta insieme alla ricerca (stesso code path).
  Ogni chiamata futura con query string erediterà il fix automaticamente.
- Nessuna migrazione, nessun cambio di schema. Verificato in produzione via
  hook di debug temporaneo (`-uitest-verify-search`, rimosso dopo la
  verifica dal codice permanente ma il pattern resta disponibile come
  riferimento): `pane` → 19 risultati, `bread` → 20, entrambi con lo stesso
  contenuto restituito da `curl` diretto al backend.
- **Lezione**: qualunque `catch {}` silenzioso su una chiamata di rete
  nasconde bug di questo tipo finché qualcuno non li osserva a occhio in
  produzione — gli XCUITest offline non li avrebbero mai presi. Non c'è
  azione immediata da questo ADR oltre al fix (i `catch {}` restano
  deliberati per il comportamento offline-first, ADR-0006), ma vale la pena
  ricordarlo se altri "nessun risultato"/"non si sincronizza" vengono
  segnalati in futuro: isolare la chiamata da un hook di debug prima di
  sospettare il backend.
