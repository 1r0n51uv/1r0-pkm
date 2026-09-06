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

        let reset = ProcessInfo.processInfo.arguments.contains("-uitest-reset")
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: reset)
            container = try ModelContainer(
                for: Exercise.self, Routine.self, RoutineDay.self, RoutineExercise.self,
                WorkoutSession.self, SetLogEntry.self,
                PlateConfig.self, BodyMeasurement.self, OutboxEntry.self,
                configurations: config
            )
        } catch {
            fatalError("ModelContainer non creato: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // instrada le mutazioni di sessione dal Watch a SwiftData + outbox
                    if watchBridge == nil {
                        watchBridge = WatchSyncBridge(context: container.mainContext)
                    }
                }
        }
        .modelContainer(container)
    }
}
