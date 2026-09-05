# ADR-0020: Report e correlazioni del modulo 1r0-diet

## Status
Accettata

## Contesto
Oltre al log giornaliero, serve vedere l'andamento nel tempo: se si rientra nel target, come cambiano calorie/macro nelle settimane, e come si correlano con peso/misure.

## Decisione
Tre viste, tutte **calcolate lato client** dai dati già esistenti (nessuna nuova tabella):

1. **Calorie/macro nel tempo**: aggregazione giornaliera di `meal_entry_items` (somma calorie/proteine/carbo/grassi per giorno), su un range settimana/mese.
2. **Aderenza al target**: confronto giorno per giorno tra il totale loggato e l'obiettivo attivo in quel giorno (`nutrition_goals`, preso per `effective_from` più recente ≤ quel giorno — importante usare l'obiettivo storicamente corretto, non quello attuale, per non falsare l'aderenza passata). Espressa come % giorni entro una tolleranza dal target, o streak.
3. **Correlazione con peso/misure**: incrocia l'aggregazione calorica con `body_measurements.recorded_at` (stessa tabella condivisa, ADR-0019) sullo stesso asse temporale.

## Conseguenze
- Nessun impatto sullo schema: tutte le viste sono query/aggregazioni, non tabelle materializzate nell'MVP — se le performance diventassero un problema con molto storico, si potrà introdurre una vista materializzata o una tabella di aggregati giornalieri precalcolati (non necessario ora, single-user).
- L'uso di `effective_from` per l'aderenza storica dipende dalla natura append-only di `nutrition_goals` decisa in ADR-0019 — motiva ulteriormente quella scelta.
