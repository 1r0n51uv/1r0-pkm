# ADR-0017: Modulo 1r0-diet — scope

## Status
Accettata

## Contesto
Secondo modulo di 1r0-pkm dopo `1r0-gym` (vedi ADR-0008 sull'architettura a moduli). Deve coprire contacalorie/macro, pianificazione pasti e alcuni tracker semplici (acqua, integratori, caffeina), riusando dove sensato le decisioni già prese per `1r0-gym` (Swift nativo, Supabase self-hosted, offline-first).

## Decisione
Il modulo copre, in ordine di priorità:

1. **Contacalorie/macro**: log pasti (`meal_entries`/`meal_entry_items`) con calorie e macro in grammi assoluti (non percentuali, vedi ADR-0019).
2. **Pianificazione pasti**: pasti pianificati per i prossimi giorni (`planned_meals`), confermabili come "mangiati" (genera un `meal_entry` collegato) o "saltati". Ricette/pasti riutilizzabili (`recipes`/`recipe_items`) per non ricomporre ogni volta lo stesso pasto.
3. **Lista della spesa**: persistente e spuntabile (`shopping_list_items`), generabile dai pasti pianificati della settimana ma modificabile liberamente dopo la generazione (non si rigenera/sovrascrive automaticamente).
4. **Tracker semplici**: acqua (`water_logs`), integratori con checklist giornaliera (`supplements`/`supplement_logs`), caffeina come voce dedicata rapida separata dal log pasti (`caffeine_logs`).

Fuori scope in questo giro: foto piatto + riconoscimento AI (si userà ricerca database + barcode, vedi ADR-0018), presenza del modulo sull'app Watch (resta solo-iPhone/web per ora).

## Struttura
Segue ADR-0008: cartella `apps/ios/1r0-pkm/Modules/1r0-diet/` (Swift) e `apps/web/app/1r0-diet/` (Next.js, dashboard sola lettura come per `1r0-gym`). Offline-first con lo stesso pattern SwiftData+outbox di ADR-0006 (i pasti già cercati restano in cache locale; cercare un alimento nuovo richiede rete).

## Conseguenze
- Schema più esteso di `1r0-gym` (13 tabelle, vedi `supabase/migrations/0004_1r0-diet_schema.sql`) per coprire pasti pianificati + effettivi + ricette + lista spesa + tre tracker separati.
- `meal_entry_items` snapshotta calorie/macro al momento del log (non solo un riferimento a `foods`) per restare storicamente accurato anche se il dato del catalogo alimenti viene corretto in seguito.
