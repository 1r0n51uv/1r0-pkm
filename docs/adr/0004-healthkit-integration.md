# ADR-0004: Integrazione HealthKit bidirezionale

## Status
Accettata — semplificata dopo [ADR-0010](0010-swift-native-ios-watch.md) (Swift nativo: nessun bridge, HealthKit usato direttamente).

## Contesto
Il prodotto è iOS-first e deve integrarsi con Apple Salute: scrivere gli allenamenti loggati, leggere peso corporeo/passi/calorie attive (utili anche al futuro modulo `1r0-diet`), e permettere di avviare/loggare un allenamento dal Watch.

## Decisione
- Scrittura: ogni `Workout Session` chiusa viene salvata anche come `HKWorkoutSession`/`HKWorkout` su Apple Health (tipo attività: "Functional Strength Training" o mapping da definire per esercizio/routine).
- Lettura: import periodico (o on-demand) di peso corporeo, passi, calorie attive da HealthKit, salvato lato Supabase per essere consultabile anche dal web.
- Il Watch, tramite HealthKit nativo, può avviare la sua sessione di allenamento (`HKWorkoutSession` su watchOS) in parallelo al log applicativo (Set Log), non in sostituzione.
- Permessi HealthKit richiesti in modo granulare (solo i tipi elencati sopra), con schermata di onboarding che spiega perché.

## Conseguenze
- Richiede entitlement HealthKit sull'App ID e capability dedicata in Xcode — nativo per definizione con ADR-0010, nessun modulo bridge da mantenere come nell'opzione Expo scartata.
- La sync Health → Supabase (self-hosted, vedi ADR-0009) introduce un caso di "dato duplicato/da riconciliare" (es. peso inserito manualmente nell'app vs peso letto da Health): la UI deve mostrare la fonte del dato.

## Amendment (ADR-0027)
Con il ridimensionamento a hub nativo:
- **Nutrizione bidirezionale.** L'app **scrive** energia alimentare + macro
  (`HKQuantityType` `dietary*`) per ogni pasto loggato nel modulo `diet`, e **legge** da
  HealthKit peso corporeo, **acqua** ed **energia attiva** (quest'ultima alimenta ADR-0019
  amendata). L'app resta la fonte di verità per la nutrizione; Salute è specchio in uscita.
- **Niente scrittura di workout.** Il modulo `gym` non crea più `WorkoutSession` (import-CSV
  da Liftin', ADR-0027) quindi non scrive `HKWorkout`. Legge solo il peso corporeo per i
  grafici.
- **Niente Watch, niente bridge.** `HKWorkoutSession` su watchOS decade con l'app Watch
  (ADR-0016 superseded).
- **Backend.** La sync Health → server passa da Supabase a `apps/api` (Fastify, ADR-0022);
  la lettura serve principalmente ai grafici in-app, il push al server è secondario.
- **Gateway condiviso.** `HealthKitService` si sposta in `Modules/Shared/HealthKit/`.
