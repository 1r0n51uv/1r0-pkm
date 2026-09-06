//
//  LiveSessionView.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Sessione live: cronometro, volume, 1RM stimato, serie loggate per
//  esercizio, timer di riposo (visivo). Stile Glass Dark (ADR-0023), layout
//  dal mockup "GlassSession": chip riposo sticky in alto, card cronometro,
//  blocchi esercizio, barra sticky in basso (cronometro totale + Termina).
//

import SwiftUI
import SwiftData

struct LiveSessionView: View {
    @Environment(\.modelContext) private var context
    @Bindable var session: WorkoutSession

    @Query(sort: \SetLogEntry.completedAt) private var allSets: [SetLogEntry]
    @Query private var catalog: [Exercise]
    private var sessionSets: [SetLogEntry] {
        allSets.filter { $0.session?.id == session.id }
    }

    @State private var showLog = false
    @State private var restEndsAt: Date?
    @State private var plateSeed: PlateSeed?
    @State private var demoExercise: Exercise?

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
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if let restEndsAt { restChip(until: restEndsAt) }
                    clock

                    if sessionSets.isEmpty {
                        Text("Nessuna serie ancora. Tocca “Aggiungi serie” per loggarne una.")
                            .font(Glass.body(13)).foregroundStyle(Glass.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16).padding(.vertical, 22)
                            .glassRow()
                    } else {
                        ForEach(byExercise, id: \.name) { group in
                            exerciseBlock(group.name, group.sets)
                        }
                    }

                    GlassPrimaryButton(title: "Aggiungi serie", systemImage: "plus") { showLog = true }
                        .accessibilityIdentifier("addSet")
                        .padding(.top, 2)
                }
                .padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            bottomBar
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
        .sheet(item: $demoExercise) { ex in
            ExerciseDetailView(exercise: ex)
                .presentationDetents([.large])
                .presentationBackground(.ultraThinMaterial)
        }
    }

    /// L'`Exercise` a catalogo che corrisponde alle serie loggate (per id,
    /// poi per nome) — per mostrare la dimostrazione (ADR-0005/0013).
    private func catalogMatch(_ sets: [SetLogEntry]) -> Exercise? {
        guard let s = sets.first else { return nil }
        if let byId = catalog.first(where: { $0.id == s.exerciseId }) { return byId }
        let n = s.exerciseName.lowercased()
        return catalog.first { $0.name.lowercased() == n }
    }

    private var header: some View {
        HStack {
            Text("Allenamento").font(Glass.display(20, .bold))
            Spacer()
            Text("\(sessionSets.count) seri\(sessionSets.count == 1 ? "e" : "e")")
                .font(Glass.body(12, .medium)).foregroundStyle(Glass.textSecondary)
        }
    }

    private var clock: some View {
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
                    .font(Glass.body(12)).foregroundStyle(Glass.textSecondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    private func exerciseBlock(_ name: String, _ sets: [SetLogEntry]) -> some View {
        let best = GymMath.bestEstimated1RM(sets.map { (weightKg: $0.weightKg, reps: $0.reps) })
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                MuscleTile(groups: [], size: 36)
                Text(name).font(Glass.body(16, .semibold))
                Spacer()
                Text("1RM ~\(Int(best.rounded())) kg")
                    .font(Glass.body(12, .semibold))
                    .foregroundStyle(Glass.coralLight)
                if let match = catalogMatch(sets),
                   match.videoURL?.isEmpty == false || match.imageURL?.isEmpty == false {
                    Button { demoExercise = match } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Glass.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("demo")
                }
                Button {
                    plateSeed = PlateSeed(weight: sets.last?.weightKg ?? lastLoggedWeight)
                } label: {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Glass.textSecondary)
                }
                .buttonStyle(.plain)
            }
            ForEach(sets) { s in
                HStack(spacing: 10) {
                    Text("\(s.setIndex)")
                        .font(Glass.body(12, .bold)).foregroundStyle(Glass.textTertiary)
                        .frame(width: 18)
                    Text("\(fmt(s.weightKg)) kg × \(s.reps)")
                        .font(Glass.body(15))
                    if let rpe = s.rpe {
                        Text("RPE \(fmt(rpe))")
                            .font(Glass.body(11, .medium)).foregroundStyle(Glass.textSecondary)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }
                    Spacer()
                    if s.syncedAt == nil {
                        Circle().fill(Glass.amber).frame(width: 6, height: 6)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func restChip(until: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let remaining = Int(until.timeIntervalSince(ctx.date).rounded(.up))
            if remaining > 0 {
                HStack(spacing: 12) {
                    Image(systemName: "timer")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Glass.amber)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("RIPOSO").font(Glass.body(10, .bold)).tracking(0.6)
                            .foregroundStyle(Glass.textSecondary)
                        Text("\(remaining)s").font(Glass.display(20, .bold)).monospacedDigit()
                    }
                    Spacer()
                    Button("Salta") { restEndsAt = nil }
                        .font(Glass.body(13, .bold)).foregroundStyle(Glass.ink)
                        .padding(.horizontal, 16).frame(height: 40)
                        .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Glass.coral.opacity(0.16)))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Glass.coralLight.opacity(0.35)))
            } else {
                Color.clear.frame(height: 0).onAppear { restEndsAt = nil }
            }
        }
    }

    private var bottomBar: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Glass.textSecondary)
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text(elapsed(ctx.date))
                        .font(Glass.display(15, .semibold)).monospacedDigit()
                        .foregroundStyle(Glass.ink.opacity(0.8))
                }
            }
            Spacer()
            Button {
                plateSeed = PlateSeed(weight: lastLoggedWeight)
            } label: {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Glass.ink)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("openPlateCalc")

            Button("Termina", action: end)
                .font(Glass.body(14, .bold)).foregroundStyle(Glass.ink)
                .padding(.horizontal, 22).frame(height: 44)
                .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(Glass.hairline))
                .accessibilityIdentifier("endSession")
        }
        .padding(.horizontal, 22).padding(.vertical, 14)
        .background(
            Rectangle().fill(Glass.bg.opacity(0.5)).background(.ultraThinMaterial)
                .overlay(Rectangle().fill(Glass.hairlineSoft).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
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
        Task { await HealthKitService.shared.saveCompletedWorkout(start: start, end: finish, activeEnergyKcal: nil) }
    }
}
