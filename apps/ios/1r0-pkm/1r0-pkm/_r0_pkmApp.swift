//
//  _r0_pkmApp.swift
//  1r0-pkm
//

import SwiftUI
import SwiftData

@main
struct _r0_pkmApp: App {
    let container: ModelContainer

    init() {
        _ = PhoneConnector.shared // attiva il trasporto WatchConnectivity per dopo

        let reset = ProcessInfo.processInfo.arguments.contains("-uitest-reset")
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: reset)
            container = try ModelContainer(for: Exercise.self, OutboxEntry.self, configurations: config)
        } catch {
            fatalError("ModelContainer non creato: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
