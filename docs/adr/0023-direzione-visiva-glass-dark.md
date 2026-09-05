# ADR-0023: Direzione visiva scelta — Glass Dark

## Status
Accettata

## Contesto
ADR-0021 prevedeva un mockup visivo prima del codice (issue [#3](https://github.com/1r0n51uv/PikM/issues/3)/[#4](https://github.com/1r0n51uv/PikM/issues/4)). Sono state esplorate ~10 direzioni sul canvas pubblicato (dense/glow scuro, glass, editorial bold, grid data, organic soft, ibridi glass+organic su 3 palette, 6 layout senza dark/glass per confronto, 10 varianti di information architecture dentro dark+glass).

## Decisione
Direzione scelta: **Glass Dark** — dark-first, pannelli traslucidi con `backdrop-filter: blur()`, sfondo con blob sfumati colorati, angoli arrotondati uniformi, tipografia Space Grotesk (numeri/titoli) + Manrope (corpo). Corrisponde alla pagina "★ Direzione scelta — Glass Dark" nel canvas dei mockup, che copre:

- **Palestra (iPhone)**: lista routine (con fase bulk/cut/deload/maintenance, ADR-0015), sessione live, impostazioni/aspetto, progressi (peso/misure/foto), catalogo esercizi + import AI, revisione coaching AI, editor scheda (routine builder), dettaglio esercizio, riepilogo fine allenamento, calcolatore piastre, riscaldamento automatico, video/demo esercizio in sessione, Live Activity/Dynamic Island per il timer di riposo (tutti e quattro da ADR-0013)
- **Dieta (iPhone)**: dashboard giornaliera (con quick-log acqua/caffeina/integratori), log pasto, ricerca alimento + barcode scan (ADR-0018), pianificazione pasti, editor ricetta, lista della spesa, obiettivo nutrizionale, report/andamento, checklist integratori, tracker caffeina (tracker semplici da ADR-0017)
- **Onboarding**: accesso via magic link, condiviso tra i moduli
- **Apple Watch**: home/routine, sessione live, rest timer, menu sessione (pausa/annulla, ADR-0016), prompt salva-in-scheda per modifiche ad hoc, riepilogo fine allenamento, complication quadrante (streak) — stesso linguaggio visivo del telefono, adattato alla cornice tonda
- **Impostazioni e stati trasversali**: hub impostazioni generale (account, notifiche, permessi HealthKit, unità di misura, oltre alla sotto-pagina Aspetto già citata sopra), stato offline/sincronizzazione in coda (ADR-0006), sessione in pausa, nuova misurazione corporea, nuova foto progresso, stato vuoto lista routine, stato "nessun risultato" per ricerca esercizi/alimenti

Ogni schermata elencata sopra ha un mockup di riferimento sul canvas, così che l'implementazione Swift/SwiftUI abbia sempre un punto di partenza visivo senza dover reinventare il layout in codice. Restano fuori scope, perché non ancora modellati in nessuna ADR: il modulo PKM/appunti e la dashboard web (rimandata esplicitamente in ADR-0021).

Le altre direzioni esplorate restano sul canvas come riferimento storico, non vengono cancellate.

## Conseguenze
- I prossimi mockup e, quando si arriverà all'implementazione Swift/SwiftUI (ADR-0010), seguono questo linguaggio visivo: pannelli glass, blob di sfondo, palette dinamica per gruppo muscolare (ADR-0016) espressa tramite gradiente sui blob e sui tile icona.
- ADR-0007 (Tailwind per il web) non è vincolata da questa scelta: la dashboard web resta un'esperienza secondaria, può restare più semplice.
- Le issue [#3](https://github.com/1r0n51uv/PikM/issues/3)/[#4](https://github.com/1r0n51uv/PikM/issues/4) del piano d'azione (ADR-0021) si considerano chiuse da questa decisione.
