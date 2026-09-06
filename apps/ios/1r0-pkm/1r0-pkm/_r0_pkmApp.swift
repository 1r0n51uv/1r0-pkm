//
//  _r0_pkmApp.swift
//  1r0-pkm
//

import SwiftUI
import SwiftData

@main
struct _r0_pkmApp: App {
    let container: ModelContainer
    @State private var watchBridge: WatchSyncBridge?

    init() {
        _ = PhoneConnector.shared // attiva il trasporto WatchConnectivity

        if ProcessInfo.processInfo.arguments.contains("-uitest-reset") {
            GymData.container = try! ModelContainer(
                for: GymData.schema,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
        // container unico condiviso con gli App Intents (ADR-0014)
        container = GymData.container
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
    }
}
