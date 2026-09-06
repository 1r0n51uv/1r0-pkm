//
//  StartWorkoutIntent.swift
//  1r0-pkm · Modules/1r0-gym
//
//  ADR-0014: "Ehi Siri, inizia allenamento Push". App Intents (iOS 16+),
//  puramente client-side sopra i `RoutineDay` in SwiftData.
//

import AppIntents
import SwiftData

/// Un giorno di scheda selezionabile da Siri / Shortcut.
struct RoutineDayEntity: AppEntity {
    let id: UUID
    let dayName: String
    let routineName: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Giorno di scheda"
    var displayRepresentation: DisplayRepresentation {
        routineName.isEmpty
            ? DisplayRepresentation(title: "\(dayName)")
            : DisplayRepresentation(title: "\(dayName)", subtitle: "\(routineName)")
    }

    static var defaultQuery = RoutineDayQuery()
}

struct RoutineDayQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [RoutineDayEntity] {
        try all().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [RoutineDayEntity] { try all() }

    @MainActor
    private func all() throws -> [RoutineDayEntity] {
        let ctx = GymData.container.mainContext
        let days = try ctx.fetch(
            FetchDescriptor<RoutineDay>(sortBy: [SortDescriptor(\.orderIndex)])
        )
        return days.map {
            RoutineDayEntity(id: $0.id, dayName: $0.name, routineName: $0.routine?.name ?? "")
        }
    }
}

struct StartWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Inizia allenamento"
    static var description = IntentDescription(
        "Avvia una sessione di 1r0-gym, opzionalmente da un giorno di scheda.")
    static var openAppWhenRun = true

    @Parameter(title: "Giorno")
    var day: RoutineDayEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Inizia allenamento \(\.$day)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let session = GymActions.startWorkout(
            routineDayId: day?.id, source: "app", in: GymData.container.mainContext)
        _ = session
        let what = day.map { " \($0.dayName)" } ?? ""
        return .result(dialog: "Allenamento\(what) iniziato.")
    }
}
