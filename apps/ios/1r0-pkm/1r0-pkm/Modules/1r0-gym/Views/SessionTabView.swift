//
//  SessionTabView.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Tab "Sessione": mostra la sessione attiva (LiveSessionView) o la CTA per
//  iniziarne una. Stile Glass Dark (ADR-0023).
//

import SwiftUI
import SwiftData

struct SessionTabView: View {
    @Environment(\.modelContext) private var context
    @Query(
        filter: #Predicate<WorkoutSession> { $0.statusRaw == "active" || $0.statusRaw == "paused" },
        sort: \WorkoutSession.startedAt, order: .reverse
    ) private var open: [WorkoutSession]
    @Query(
        filter: #Predicate<WorkoutSession> { $0.statusRaw == "completed" },
        sort: \WorkoutSession.startedAt, order: .reverse
    ) private var done: [WorkoutSession]

    private var streak: Int {
        GymMath.currentStreakDays(completedDates: done.map(\.startedAt))
    }
    private var thisWeek: Int {
        GymMath.workoutsThisWeek(completedDates: done.map(\.startedAt))
    }

    var body: some View {
        Group {
            if let session = open.first {
                LiveSessionView(session: session)
            } else {
                startCTA
            }
        }
        .glassScreen()
        .toolbar(.hidden, for: .navigationBar)
        .task { await GymSync.flushOutbox(context) }
    }

    private var startCTA: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Sessione")
                    .font(Glass.display(28, .bold)).tracking(-0.5)
                Text(done.isEmpty ? "Nessun allenamento ancora" : "Nessun allenamento in corso")
                    .font(Glass.body(14)).foregroundStyle(Glass.textSecondary)
            }

            if !done.isEmpty {
                HStack(spacing: 0) {
                    stat("\(streak)", streak == 1 ? "giorno di fila" : "giorni di fila", Glass.coralLight)
                    Rectangle().fill(Glass.hairlineSoft).frame(width: 1, height: 34)
                    stat("\(thisWeek)", "questa settimana", Glass.blueLight)
                }
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
                .glassCard()
            }

            GlassPrimaryButton(title: "Inizia sessione", systemImage: "play.fill", height: 56) {
                start()
            }
            .accessibilityIdentifier("startSession")
            .padding(.top, 2)

            Spacer()
        }
        .padding(.horizontal, 22).padding(.top, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(Glass.display(26, .bold)).foregroundStyle(color).monospacedDigit()
            Text(label).font(Glass.body(11)).foregroundStyle(Glass.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    @MainActor
    private func start() {
        GymActions.startWorkout(in: context)
    }
}
