# ADR-0024: Meal Slot esteso a 5 valori (spuntino mattutino/pomeridiano distinti)

## Status
Accettata

## Contesto
È in valutazione un sistema di **Promemoria** (regole di dominio che notificano l'utente quando doveva fare qualcosa e non l'ha fatto — vedi `docs/glossary.md`), tra cui un promemoria per pasto non registrato vicino al suo orario atteso, invece che un unico controllo aggregato a fine giornata. Questo richiede di conoscere, per ogni pasto atteso, un orario indicativo distinto.

Il `MealSlot` attuale (`breakfast`/`lunch`/`dinner`/`snack`, `packages/shared/src/types/1r0-diet.ts`) ha un solo valore `snack` generico: non distingue uno spuntino mattutino da uno pomeridiano, quindi non basta per assegnare un orario atteso specifico a ciascuno.

## Decisione
`MealSlot` passa da 4 a 5 valori: `breakfast`, `morning_snack`, `lunch`, `afternoon_snack`, `dinner`. Il valore `snack` generico viene rimosso come opzione valida per nuovi Meal Entry/Planned Meal. Gli orari attesi per ciascuno slot restano configurabili per utente (non hardcoded), sia per i Promemoria sia per l'eventuale UI di pianificazione pasti.

## Conseguenze
- **Migrazione dati**: le righe storiche con `meal_slot = 'snack'` (schema Supabase, tabelle `meal_entries`/`planned_meals`) vanno migrate esplicitamente verso `morning_snack` o `afternoon_snack` — non è deducibile con certezza dal solo orario di consumo, va deciso in fase di implementazione (es. euristica su `consumed_at`, o default fisso + correzione manuale).
- Tre punti indipendenti da aggiornare insieme: il tipo condiviso in `packages/shared/src/types/1r0-diet.ts`, il constraint/enum a DB in `supabase/migrations/`, e il modello Swift nativo (`apps/ios/.../Modules/1r0-diet`) che replica lo stesso `MealSlot`.
- La UI esistente che elenca/filtra per `MealSlot` (`MealPlanView`, `LogFoodView`, badge negli slot) va aggiornata per i 2 nuovi valori.
- Decisione sul modello dati condiviso, non solo sul modulo Promemoria: qualunque punto del prodotto che referenzia `MealSlot` è impattato, non solo il nuovo motore di notifiche.

## Alternative scartate
- **Tassonomia separata solo per i Promemoria** (lista di pasti attesi indipendente dal `MealSlot` usato per il log): scartata perché avrebbe creato due tassonomie di pasti parallele e disallineabili — quella "vera" usata per registrare un pasto, e quella "attesa" usata solo per capire quando ricordare.
