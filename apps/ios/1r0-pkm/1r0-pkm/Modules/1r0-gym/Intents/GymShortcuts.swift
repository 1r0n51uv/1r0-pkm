//
//  GymShortcuts.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Frasi Siri / Shortcut per gli App Intent di 1r0-gym (ADR-0014).
//

import AppIntents

struct GymShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "Inizia allenamento in \(.applicationName)",
                "Inizia allenamento \(\.$day) in \(.applicationName)",
                "\(.applicationName) inizia allenamento",
            ],
            shortTitle: "Inizia allenamento",
            systemImageName: "figure.strengthtraining.traditional"
        )
    }
}
