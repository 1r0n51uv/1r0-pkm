//
//  _r0_pkmApp.swift
//  1r0-pkm
//

import SwiftUI
import SwiftData

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
        // slice 2): un alimento in cache, così ricette/pianificazione non
        // dipendono dal flusso fragile "crea alimento" né dalla rete.
        if ProcessInfo.processInfo.arguments.contains("-uitest-seed-diet") {
            let ctx = container.mainContext
            if (try? ctx.fetch(FetchDescriptor<Food>()))?.isEmpty ?? true {
                ctx.insert(Food(name: "Avena test", source: "custom",
                                caloriesPer100g: 380, proteinGPer100g: 13,
                                carbsGPer100g: 60, fatGPer100g: 7))
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
