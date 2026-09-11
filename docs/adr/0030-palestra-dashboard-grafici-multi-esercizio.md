# ADR-0030: Palestra — dashboard grafici multi-esercizio

## Status
Accettata

## Contesto
Feedback beta: la tab Palestra (`GymHistoryView`, ADR-0027 step 3) già mostra
i grafici (1RM stimato, volume) nella stessa vista dello storico — non in una
sezione/tab separata — ma per un solo esercizio alla volta, scelto da un
selettore a chip orizzontali sopra i due grafici. L'utente vuole la vista
"più centrata sui grafici": non un singolo esercizio con selettore, ma più
esercizi visibili insieme, così l'andamento si coglie a colpo d'occhio senza
toccare nulla.

## Decisione
Il selettore-a-chip + i due grafici a tutta larghezza (1RM, volume) per un
solo esercizio diventano una **dashboard**: una griglia 2 colonne con una
card per ciascuno dei fino a 6 esercizi più allenati (per numero di serie,
`GymStats.exercises`, già ordinato così), ciascuna con nome, ultimo 1RM
stimato e una mini-sparkline (`MiniLineChart`, riuso dal modulo dieta).
Toccare una card apre `ExerciseChartsView`, un drill-down a tutta larghezza
con gli stessi due grafici (1RM + volume) di prima — la vista dettagliata non
sparisce, cambia solo il punto d'ingresso.

In testa alla vista, due "stat chip" (giorni di fila, allenamenti questa
settimana) da `GymMath.currentStreakDays`/`workoutsThisWeek` — funzioni pure
già esistenti e testate (ADR-0016) ma non ancora collegate a nessuna UI.

## Conseguenze
- Con più di 6 esercizi distinti, solo i 6 più allenati compaiono in
  dashboard (etichetta "top 6 di N"); gli altri restano raggiungibili solo
  indirettamente via lo storico sessioni (`WorkoutSessionDetailView`). Non
  c'è un browser dedicato a "tutti gli esercizi" — rimandato, non richiesto.
- `chartCard`/`chartsSection` (selettore singolo esercizio) rimossi da
  `GymHistoryView`, il loro contenuto grafici spostato in
  `ExerciseChartsView` (nuova struct nello stesso file).
- Nuovo hook `-uitest-seed-gym` (pattern di `-uitest-seed-diet`, ADR-0017)
  per popolare due sessioni dello stesso esercizio nei test UI — la dashboard
  richiede >= 2 punti per disegnare una sparkline reale.

## Alternative scartate
- **Carosello orizzontale invece di griglia 2 colonne**: scartato, una
  griglia mostra più esercizi senza scroll orizzontale nascosto (peggiore
  scopribilità su una dashboard pensata per la visione d'insieme).
- **Nessun limite al numero di card**: scartato, oltre 6-8 card la vista
  perde la leggibilità "a colpo d'occhio" che è lo scopo della dashboard;
  meglio un tetto fisso con indicazione esplicita di quanti mancano.
