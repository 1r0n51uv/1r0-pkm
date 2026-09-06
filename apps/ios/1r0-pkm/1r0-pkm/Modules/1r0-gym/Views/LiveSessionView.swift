//
//  LiveSessionView.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Sessione live: cronometro, volume, 1RM stimato, serie loggate per
//  esercizio, timer di riposo (visivo). Stile Glass Dark (ADR-0023).
//

import SwiftUI
import SwiftData

struct LiveSessionView: View {
    @Environment(\.modelContext) private var context
    @Bindable var session: WorkoutSession

    // @Query sulla tabella SetLogEntry: si aggiorna sicuro a ogni insert,
    // a differenza della traversata della relazione session.sets.
    @Query(sort: \SetLogEntry.completedAt) private var allSets: [SetLogEntry]
    private var sessionSets: [SetLogEntry] {
        allSets.filter { $0.session?.id == session.id }
    }

    @State private var showLog = false
    @State private var restEndsAt: Date?
    @State private var plateSeed: PlateSeed?

    private struct PlateSeed: Identifiable { let id = UUID(); let weight: Double }
    private var lastLoggedWeight: Double { sessionSets.last?.weightKg ?? 60 }

    private var byExercise: [(name: String, sets: [SetLogEntry])] {
        Dictionary(grouping: sessionSets, by: { $0.exerciseId })
            .map { (name: $0.value.first?.exerciseName ?? "—",
                    sets: $0.value.sorted { $0.setIndex < $1.setIndex }) }
            .sorted { ($0.sets.first?.completedAt ?? .distantPast) < ($1.sets.first?.completedAt ?? .distantPast) }
    }

    private var totalVolume: Double {
        GymMath.volume(sessionSets.map { (weightKg: $0.weightKg, reps: $0.reps) })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                clock
                if let restEndsAt { restChip(until: restEndsAt) }

                if sessionSets.isEmpty {
                    GlassPanel(padding: 26) {
                        Text("Nessuna serie ancora. Tocca \(Image(systemName: "plus")) per loggarne una.")
                            .font(Glass.body(14))
                            .foregroundStyle(Glass.textSecondary)
                    }
                } else {
                    ForEach(byExercise, id: \.name) { group in
                        exerciseBlock(group.name, group.sets)
                    }
                }

                Button(action: { showLog = true }) {
                    HStack { Image(systemName: "plus"); Text("Aggiungi serie") }
                        .font(Glass.body(16, .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Glass.hairline))
                }
                .accessibilityIdentifier("addSet")
                .padding(.top, 4)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    plateSeed = PlateSeed(weight: lastLoggedWeight)
                } label: {
                    Image(systemName: "circle.hexagongrid.fill")
                }
                .accessibilityIdentifier("openPlateCalc")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Termina", action: end)
                    .font(Glass.body(15, .semibold))
                    .accessibilityIdentifier("endSession")
            }
        }
        .sheet(isPresented: $showLog) {
            LogSetSheet(session: session) { restEndsAt = Date().addingTimeInterval(90) }
                .presentationDetents([.medium])
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(item: $plateSeed) { seed in
            PlateCalculatorView(initialWeightKg: seed.weight)
                .presentationDetents([.large])
                .presentationBackground(.ultraThinMaterial)
        }
    }

    private var clock: some View {
        GlassPanel {
            HStack(alignment: .firstTextBaseline) {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text(elapsed(ctx.date))
                        .font(Glass.display(40, .bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(totalVolume)) kg")
                        .font(Glass.display(20, .semibold))
                    Text("volume")
                        .font(Glass.body(12))
                        .foregroundStyle(Glass.textSecondary)
                }
            }
        }
    }

    private func exerciseBlock(_ name: String, _ sets: [SetLogEntry]) -> some View {
        let best = GymMath.bestEstimated1RM(sets.map { (weightKg: $0.weightKg, reps: $0.reps) })
        return GlassPanel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(name).font(Glass.body(17, .semibold))
                    Spacer()
                    Text("1RM ~\(Int(best.rounded())) kg")
                        .font(Glass.body(12, .medium))
                        .foregroundStyle(Glass.accent)
                    Button {
                        plateSeed = PlateSeed(weight: sets.last?.weightKg ?? lastLoggedWeight)
                    } label: {
                        Image(systemName: "circle.hexagongrid")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Glass.textSecondary)
                    }
                }
                ForEach(sets) { s in
                    HStack(spacing: 10) {
                        Text("\(s.setIndex)")
                            .font(Glass.body(12, .bold))
                            .foregroundStyle(Glass.textSecondary)
                            .frame(width: 18)
                        Text("\(fmt(s.weightKg)) kg × \(s.reps)")
                            .font(Glass.body(15))
                        if let rpe = s.rpe {
                            Text("RPE \(fmt(rpe))")
                                .font(Glass.body(11, .medium))
                                .foregroundStyle(Glass.textSecondary)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Glass.hairline, in: Capsule())
                        }
                        Spacer()
                        if s.syncedAt == nil {
                            Circle().fill(Glass.accent2).frame(width: 6, height: 6)
                        }
                    }
                }
            }
        }
    }

    private func restChip(until: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let remaining = Int(until.timeIntervalSince(ctx.date).rounded(.up))
            if remaining > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                    Text("riposo \(remaining)s")
                        .monospacedDigit()
                    Spacer()
                    Button("stop") { restEndsAt = nil }
                        .font(Glass.body(13, .semibold))
                }
                .font(Glass.body(14, .medium))
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Glass.accent.opacity(0.16), in: Capsule())
                .overlay(Capsule().strokeBorder(Glass.accent.opacity(0.4)))
            } else {
                Color.clear.frame(height: 0).onAppear { restEndsAt = nil }
            }
        }
    }

    private func elapsed(_ now: Date) -> String {
        let s = max(0, Int(now.timeIntervalSince(session.startedAt)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func fmt(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%.1f", d)
    }

    private func end() {
        let start = session.startedAt
        let finish = Date()
        session.status = .completed
        session.endedAt = finish
        session.syncedAt = nil
        if let data = try? JSONSerialization.data(withJSONObject: [
            "id": session.id.uuidString, "status": "completed",
        ]) {
            context.insert(OutboxEntry(kind: "session.update", payload: data))
        }
        try? context.save()
        let ctx = context
        Task { await GymSync.flushOutbox(ctx) }
        // salva l'allenamento in Apple Salute (ADR-0004); no-op se non
        // autorizzato o non disponibile
        Task { await HealthKitService.shared.saveCompletedWorkout(start: start, end: finish, activeEnergyKcal: nil) }
    }
}
