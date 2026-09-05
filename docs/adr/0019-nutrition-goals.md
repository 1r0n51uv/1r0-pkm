# ADR-0019: Obiettivo calorico/macro e collegamento con 1r0-gym

## Status
Accettata

## Contesto
L'obiettivo calorico/macro deve poter essere impostato a mano, calcolato da TDEE, o legato alla fase della routine attiva (`Routine.phase`, ADR-0015) — con la possibilità di cambiare modalità nel tempo. Serve anche decidere se/come `1r0-diet` condivide dati già esistenti del modulo `1r0-gym` (peso, misure).

## Decisione
- **Una modalità attiva alla volta** (`NutritionGoal.mode`: `manual | phase_linked | tdee`), cambiabile dall'utente quando vuole dalle impostazioni — non una combinazione automatica delle tre.
- **Target in grammi assoluti** (proteine/carbo/grassi), non percentuali — coerente con come si ragiona normalmente in un piano nutrizionale.
- **`nutrition_goals` è append-only**: ogni cambio di obiettivo (anche solo di modalità) inserisce una nuova riga con `effective_from`; l'obiettivo "corrente" è la riga più recente con `effective_from <= oggi`. Questo mantiene automaticamente lo storico di come è cambiato l'obiettivo nel tempo, utile per i report (ADR-0020).
- **`mode = 'phase_linked'`**: quando la fase della routine attiva (`1r0-gym`) cambia, l'app propone (non applica automaticamente) un nuovo target coerente (es. surplus in bulk, deficit in cut) — l'utente conferma prima che venga inserita la nuova riga in `nutrition_goals`.
- **`mode = 'tdee'`**: stima da peso corrente (`body_measurements`, già esistente) e livello di attività dichiarato; ricalcolabile su richiesta, non automaticamente ad ogni variazione di peso.
- **`body_measurements` è condiviso** tra `1r0-gym` e `1r0-diet` (nessuna duplicazione): entrambi i moduli leggono/scrivono la stessa tabella, già creata in ADR-0012.
- **Nessun collegamento con le calorie bruciate in allenamento**: scartato esplicitamente — il bilancio calorico di `1r0-diet` non sottrae/aggiunge le calorie da attività fisica.

## Conseguenze
- `body_measurements` (ADR-0012) passa da "tabella del modulo `1r0-gym`" a tabella trasversale — nessuna migrazione di dati necessaria, era già strutturata per `user_id`, solo la proprietà concettuale cambia (documentata qui, non nello schema).
- Il calcolo TDEE richiede una stima del livello di attività: da modellare come parte del profilo utente quando si implementa (non ancora in schema — rimandato ai dettagli implementativi).
