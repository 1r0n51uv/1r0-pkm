//
//  _r0_pkmApp.swift
//  1r0-pkm
//

import SwiftUI
import SwiftData
import HealthKit

@main
struct _r0_pkmApp: App {
    let container: ModelContainer
    @Environment(\.scenePhase) private var scenePhase
    private let isUITest = ProcessInfo.processInfo.arguments.contains("-uitest-reset")

    init() {
        _ = PhoneConnector.shared // attiva il trasporto WatchConnectivity (Watch companion congelato, ADR-0027)

        // container unico condiviso fra i moduli (ADR-0008).
        // `GymData.makeContainer()` sceglie in-memory sotto `-uitest-reset`
        // e recupera da uno store locale non migrabile.
        container = GymData.container

        // seed deterministico per i test UI del modulo dieta (ADR-0017
        // slice 2): due alimenti in cache, così ricette/pianificazione non
        // dipendono dal flusso fragile "crea alimento" né dalla rete. Due
        // (non uno) per poter testare la rimozione di un alimento dal
        // paniere durante la modifica di un pasto pianificato (ADR-0032).
        if ProcessInfo.processInfo.arguments.contains("-uitest-seed-diet") {
            let ctx = container.mainContext
            if (try? ctx.fetch(FetchDescriptor<Food>()))?.isEmpty ?? true {
                ctx.insert(Food(name: "Avena test", source: "custom",
                                caloriesPer100g: 380, proteinGPer100g: 13,
                                carbsGPer100g: 60, fatGPer100g: 7))
                ctx.insert(Food(name: "Noci test", source: "custom",
                                caloriesPer100g: 654, proteinGPer100g: 15,
                                carbsGPer100g: 14, fatGPer100g: 65))
                try? ctx.save()
            }
        }

        // seed deterministico per i test UI della dashboard grafici Palestra
        // (redesign ADR-0030): due allenamenti con lo stesso esercizio, così
        // `GymStats.oneRMSeries` ha >= 2 punti e la mini-card mostra un
        // grafico reale, non il trattino segnaposto.
        if ProcessInfo.processInfo.arguments.contains("-uitest-seed-gym") {
            let ctx = container.mainContext
            if (try? ctx.fetch(FetchDescriptor<WorkoutSession>()))?.isEmpty ?? true {
                let cal = Calendar.current
                let d1 = cal.date(byAdding: .day, value: -3, to: .now) ?? .now
                let s1 = WorkoutSession(startedAt: d1, routineLabel: "Push")
                ctx.insert(s1)
                ctx.insert(SetLogEntry(session: s1, exerciseName: "Panca piana", setIndex: 1,
                                       weightKg: 60, reps: 8, completedAt: d1))
                let s2 = WorkoutSession(startedAt: .now, routineLabel: "Push")
                ctx.insert(s2)
                ctx.insert(SetLogEntry(session: s2, exerciseName: "Panca piana", setIndex: 1,
                                       weightKg: 62.5, reps: 8, completedAt: .now))
                try? ctx.save()
            }
        }

        // strumento manuale, non un test: sotto simulatore non ci sono dati
        // Salute reali né un modo da riga di comando per seminarli (`simctl
        // privacy` non copre `health`). `-uitest-seed-health` chiede
        // l'autorizzazione a scrivere peso/acqua/energia attiva (tipi che
        // l'app in produzione legge soltanto — richiesta ad hoc, non tocca
        // `HealthKitService.writeTypes`) e scrive un campione di oggi per
        // ciascuno, cosà da poter verificare subito lettura/scrittura reale
        // senza toccare a mano l'app Salute del simulatore.
        if ProcessInfo.processInfo.arguments.contains("-uitest-seed-health") {
            Task { @MainActor in await Self.seedHealthKitSampleData() }
        }

        // strumento manuale: verifica DietSync.searchRemote (OpenFoodFacts/
        // USDA via backend) senza passare dalla UI, per isolare se un "nessun
        // risultato" segnalato è di rete/backend o di visualizzazione.
        if ProcessInfo.processInfo.arguments.contains("-uitest-verify-search") {
            Task { @MainActor in
                for q in ["pane", "bread"] {
                    let hits = await DietSync.searchRemote(q)
                    print("SEARCH-VERIFY q=\(q) count=\(hits.count) names=\(hits.prefix(3).map(\.name))")
                }
            }
        }

        // motori di sync (ADR-0006) e promemoria (ADR-0027 step 2):
        // reachability / notifiche locali + BackgroundTasks. Saltati nei test
        // UI per non dipendere da rete e permessi di sistema.
        if !isUITest {
            SyncEngine.shared.start(container: container)
            RemindersEngine.shared.start(
                container: container,
                rules: [MissingMealReminder(), WaterReminder()],
                envProvider: {
                    guard HealthKitPreference.isEnabled() else { return ReminderEnv() }
                    let hk = HealthKitService.shared
                    async let water = hk.todayDietaryWaterMl()
                    async let active = hk.todayActiveEnergyKcal()
                    return ReminderEnv(healthKitWaterMl: await water,
                                       activeEnergyKcal: await active)
                }
            )
        }
    }

    /// Vedi nota su `-uitest-seed-health` in `init()`. Richiede il permesso di
    /// scrittura (oltre lettura) per peso/acqua/energia attiva — solo per
    /// questa scrittura di comodo, `HealthKitService` in produzione resta a
    /// sola lettura per quei tipi — e salva un campione di oggi ciascuno.
    @MainActor
    private static func seedHealthKitSampleData() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let store = HKHealthStore()
        let bodyMass = HKQuantityType(.bodyMass)
        let activeEnergy = HKQuantityType(.activeEnergyBurned)
        let dietaryWater = HKQuantityType(.dietaryWater)
        let types: Set<HKSampleType> = [bodyMass, activeEnergy, dietaryWater]
        guard (try? await store.requestAuthorization(toShare: types, read: types)) != nil else { return }

        let now = Date()
        let samples = [
            HKQuantitySample(type: bodyMass,
                             quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: 78.5),
                             start: now, end: now),
            HKQuantitySample(type: activeEnergy,
                             quantity: HKQuantity(unit: .kilocalorie(), doubleValue: 350),
                             start: now, end: now),
            HKQuantitySample(type: dietaryWater,
                             quantity: HKQuantity(unit: .literUnit(with: .milli), doubleValue: 600),
                             start: now, end: now),
        ]
        try? await store.save(samples)

        // rilettura di conferma: stampa su stdout (leggibile da
        // `xcrun simctl launch --console-pty`) cosà da verificare il giro
        // completo scrittura->lettura senza dover leggere l'interfaccia.
        let active = await HealthKitService.shared.todayActiveEnergyKcal()
        let water = await HealthKitService.shared.todayDietaryWaterMl()
        let weight = await HealthKitService.shared.latestBodyWeightKg()
        print("HEALTHKIT-SEED-VERIFY activeEnergyKcal=\(active) waterMl=\(water) weightKg=\(weight?.description ?? "nil")")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            guard !isUITest else { return }
            switch phase {
            case .active:
                SyncEngine.shared.flushNow()
                RemindersEngine.shared.refresh()
            case .background:
                SyncEngine.shared.scheduleBackgroundRefresh()
                RemindersEngine.shared.scheduleBackgroundRefresh()
            default:
                break
            }
        }
    }
}
