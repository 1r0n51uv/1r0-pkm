//
//  GymHistoryView.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Tab "Palestra" (ADR-0027 step 3): storico degli allenamenti importati da
//  Liftin' + grafici per esercizio (1RM stimato / volume nel tempo). Sostituisce
//  Sessione/Schede/Catalogo. Stile Glass Dark (ADR-0023).
//

import SwiftUI
import SwiftData

struct GymHistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @State private var selectedExercise: String?
    @State private var showImport = false

    private var exercises: [String] { GymStats.exercises(in: sessions) }
    private var exercise: String? { selectedExercise ?? exercises.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if sessions.isEmpty {
                    emptyState.padding(.top, 56)
                } else {
                    if let ex = exercise { chartsSection(ex) }
                    SectionLabel(text: "Storico")
                    VStack(spacing: 10) {
                        ForEach(sessions) { sessionRow($0) }
                    }
                }
            }
            .padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .glassScreen(.progress)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showImport) {
            NavigationStack { ImportWorkoutsView() }
                .presentationDetents([.large])
                .presentationBackground(.ultraThinMaterial)
        }
        .task { await Outbox.flushOutbox(context) }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Palestra").font(Glass.display(28, .bold)).tracking(-0.5)
                Text(sessions.isEmpty ? "Import da Liftin'"
                     : "\(sessions.count) allenamenti · \(exercises.count) esercizi")
                    .font(Glass.body(14)).foregroundStyle(Glass.textSecondary)
            }
            Spacer(minLength: 8)
            GlassIconButton(systemName: "square.and.arrow.down") { showImport = true }
                .accessibilityIdentifier("importWorkouts")
        }
    }

    private var emptyState: some View {
        GlassEmptyState(
            systemImage: "square.and.arrow.down",
            title: "Nessun allenamento",
            message: "Importa l'export CSV dell'app Liftin' per vedere storico e grafici."
        ) {
            GlassPrimaryButton(title: "Importa da Liftin'", systemImage: "square.and.arrow.down",
                               fill: Glass.accent, onInk: .white) { showImport = true }
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    // MARK: - grafici

    @ViewBuilder
    private func chartsSection(_ ex: String) -> some View {
        SectionLabel(text: "Grafici")
        if exercises.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(exercises, id: \.self) { name in
                        let on = name == ex
                        Button { selectedExercise = name } label: {
                            Text(name)
                                .font(Glass.body(12, on ? .bold : .semibold))
                                .foregroundStyle(on ? Glass.onCoral : Glass.ink.opacity(0.55))
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Capsule().fill(on ? Glass.green : Color.white.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        chartCard("1RM stimato", unit: "kg", points: GymStats.oneRMSeries(sessions, exercise: ex), color: Glass.green)
        chartCard("Volume", unit: "kg", points: GymStats.volumeSeries(sessions, exercise: ex), color: Glass.accent)
    }

    private func chartCard(_ title: String, unit: String, points: [GymStats.Point], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(Glass.body(13, .semibold)).foregroundStyle(Glass.textSecondary)
                Spacer()
                if let last = points.last {
                    Text("\(fmt(last.value)) \(unit)")
                        .font(Glass.display(18, .bold)).monospacedDigit()
                }
            }
            if points.count >= 2 {
                MiniLineChart(values: points.map(\.value), drawn: points.map { _ in true },
                              color: color, target: nil)
                    .frame(height: 60)
            } else {
                Text("Servono almeno 2 allenamenti con questo esercizio.")
                    .font(Glass.body(11)).foregroundStyle(Glass.textFaint)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: - storico

    private func sessionRow(_ s: WorkoutSession) -> some View {
        NavigationLink {
            WorkoutSessionDetailView(session: s)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(s.startedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(Glass.body(13, .semibold))
                    HStack(spacing: 6) {
                        if let r = s.routineLabel, !r.isEmpty {
                            Text(r).font(Glass.body(11)).foregroundStyle(Glass.accent)
                        }
                        Text("\(s.sets.count) serie · \(exerciseCount(s)) esercizi")
                            .font(Glass.body(11)).foregroundStyle(Glass.textFaint)
                    }
                }
                Spacer(minLength: 6)
                if let d = s.durationSeconds {
                    Text(hms(d)).font(Glass.body(12)).monospacedDigit().foregroundStyle(Glass.textSecondary)
                }
                if s.syncedAt == nil {
                    Circle().fill(Glass.amber).frame(width: 6, height: 6)
                }
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Glass.textFaint)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .glassRow()
        }
        .buttonStyle(.plain)
    }

    private func exerciseCount(_ s: WorkoutSession) -> Int { Set(s.sets.map(\.exerciseKey)).count }

    private func fmt(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%.1f", d)
    }
    private func hms(_ s: Int) -> String {
        let h = s / 3600, m = (s % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m) min"
    }
}

struct WorkoutSessionDetailView: View {
    let session: WorkoutSession

    private var byExercise: [(name: String, sets: [SetLogEntry])] {
        Dictionary(grouping: session.sets, by: \.exerciseKey)
            .map { (key, sets) in
                (name: sets.first?.exerciseName ?? key,
                 sets: sets.sorted { $0.setIndex < $1.setIndex })
            }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.startedAt.formatted(date: .complete, time: .omitted))
                        .font(Glass.display(20, .bold))
                    if let r = session.routineLabel, !r.isEmpty {
                        Text(r).font(Glass.body(13)).foregroundStyle(Glass.accent)
                    }
                }
                ForEach(byExercise, id: \.name) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.name).font(Glass.body(14, .bold))
                        ForEach(group.sets) { setLine($0) }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
                }
            }
            .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .glassScreen(.progress)
        .navigationTitle("Allenamento")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func setLine(_ s: SetLogEntry) -> some View {
        HStack(spacing: 8) {
            Text("\(s.setIndex)").font(Glass.body(11, .bold)).foregroundStyle(Glass.textFaint)
                .frame(width: 18, alignment: .leading)
            if s.isWarmup {
                Text("warm-up").font(Glass.body(10, .semibold))
                    .foregroundStyle(Glass.amberText)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Glass.amber.opacity(0.15)))
            }
            Spacer(minLength: 4)
            Text(detail(s)).font(Glass.body(13, .semibold)).monospacedDigit()
        }
    }

    private func detail(_ s: SetLogEntry) -> String {
        if let d = s.durationSeconds {
            let mm = d / 60, ss = d % 60
            return String(format: "%d:%02d", mm, ss)
        }
        let w = s.weightKg == s.weightKg.rounded() ? String(Int(s.weightKg)) : String(format: "%.1f", s.weightKg)
        if let r = s.reps { return "\(w) kg × \(r)" }
        return "\(w) kg"
    }
}
