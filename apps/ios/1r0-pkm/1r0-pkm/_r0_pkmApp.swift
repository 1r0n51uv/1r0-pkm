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
    @State private var watchBridge: WatchSyncBridge?
    private let isUITest = ProcessInfo.processInfo.arguments.contains("-uitest-reset")

    init() {
        _ = PhoneConnector.shared // attiva il trasporto WatchConnectivity

        // container unico condiviso con gli App Intents (ADR-0014).
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

        // motore di sync (ADR-0006): reachability + BackgroundTasks.
        // Saltato nei test UI per non dipendere dalla rete reale.
        if !isUITest {
            SyncEngine.shared.start(container: container)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    if watchBridge == nil {
                        watchBridge = WatchSyncBridge(context: container.mainContext)
                    }
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            guard !isUITest else { return }
            switch phase {
            case .active:
                SyncEngine.shared.flushNow()
            case .background:
                SyncEngine.shared.scheduleBackgroundRefresh()
            default:
                break
            }
        }
    }
}
