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
