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

    private func start() {
        let s = WorkoutSession(source: "app")
        context.insert(s)
        if let data = try? JSONSerialization.data(withJSONObject: ["id": s.id.uuidString, "source": "app"]) {
            context.insert(OutboxEntry(kind: "session.create", payload: data))
        }
        try? context.save()
        let ctx = context
        Task { await GymSync.flushOutbox(ctx) }
    }
}
