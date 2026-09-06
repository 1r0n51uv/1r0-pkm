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
        .navigationBarTitleDisplayMode(.inline)
        .task { await GymSync.flushOutbox(context) }
    }

    private var startCTA: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sessione")
                .font(Glass.display(34, .bold))
            Text("Nessun allenamento in corso.")
                .font(Glass.body(15))
                .foregroundStyle(Glass.textSecondary)

            if !done.isEmpty {
                GlassPanel {
                    HStack(spacing: 14) {
                        stat("\(streak)", streak == 1 ? "giorno di fila" : "giorni di fila", Glass.accent2)
                        Divider().frame(height: 30).overlay(Glass.hairline)
                        stat("\(thisWeek)", "questa settimana", Glass.accent)
                    }
                }
            }

            Button(action: start) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Inizia sessione")
                }
                .font(Glass.body(17, .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [Glass.accent, Glass.accent2],
                                   startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .foregroundStyle(.white)
            }
            .accessibilityIdentifier("startSession")
            .padding(.top, 8)

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(Glass.display(24, .bold)).foregroundStyle(color)
            Text(label).font(Glass.body(11)).foregroundStyle(Glass.textSecondary)
        }
    }

    @MainActor
    private func start() {
        GymActions.startWorkout(in: context)
    }
}
