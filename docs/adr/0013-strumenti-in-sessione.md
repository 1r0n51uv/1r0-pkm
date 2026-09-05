# ADR-0013: Strumenti in-sessione (piastre, warm-up, video, Live Activities)

## Status
Accettata — timer auto-start e haptics dettagliati e resi configurabili in [ADR-0016](0016-watch-app-scope.md) (scope app Watch).

## Contesto
Durante l'allenamento servono strumenti pratici oltre al semplice log: sapere quali piastre caricare, come scaldarsi, vedere come si esegue un esercizio, e monitorare il timer di riposo senza dover riaprire l'app.

## Decisione
- **Calcolatore piastre**: configurabile per utente (`plate_set_configs`, vedi migration 0002) — bilanciere e dischi realmente disponibili in palestra, non un set standard fisso. Calcolo puramente client-side (nessun bisogno di rete/DB per il calcolo in sé, solo per leggere la config).
- **Warm-up automatico**: formula fissa standard (40% / 60% / 80% del peso di lavoro, vedi `WARMUP_RAMP_PERCENTAGES` in `packages/shared/src/types/1r0-gym.ts` come riferimento — il calcolo vero vive in Swift), uguale per tutti gli esercizi, nessuna configurazione per esercizio nell'MVP.
- **Video/demo esercizio**: riusa `Exercise.videoUrl`/`imageUrl` già previsto in ADR-0005 (valorizzato da wger o dall'import AI) — nessun nuovo campo, solo da mostrare in UI durante la serie.
- **Live Activities / complication**: `ActivityKit` (iOS 16+) per il timer di riposo su Dynamic Island/lock screen, e una Watch complication per lo stesso timer sul quadrante — entrambe funzionalità native, nessuna dipendenza da rete/backend.

## Conseguenze
- Tutti e quattro gli strumenti sono principalmente client-side (Swift nativo, ADR-0010): solo il calcolatore piastre richiede una riga di config sincronizzata via Supabase.
- `ActivityKit`/complication aggiungono superficie nativa da mantenere (extension target separati in Xcode) — coerente con la complessità già accettata in ADR-0010.
