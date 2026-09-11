//
//  GymHistoryView.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Tab "Palestra" (ADR-0027 step 3, redesign ADR-0030): storico allenamenti
//  importati da Liftin' + dashboard grafici multi-esercizio (1RM stimato) in
//  cima alla vista — nessuna sezione/tab dedicata ai grafici, sono la parte
//  centrale di questa stessa vista. Sostituisce Sessione/Schede/Catalogo.
//  Stile Glass Dark (ADR-0023).
//

import SwiftUI
import SwiftData

/// Quanti esercizi mostrare nella dashboard (i più allenati, per n° serie —
/// `GymStats.exercises` è già ordinato così). Oltre questo, solo link "storico".
private let dashboardExerciseLimit = 6

struct GymHistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @State private var showImport = false

    private var exercises: [String] { GymStats.exercises(in: sessions) }
    private var dashboardExercises: [String] { Array(exercises.prefix(dashboardExerciseLimit)) }
    private var streakDays: Int {
        GymMath.currentStreakDays(completedDates: sessions.map(\.startedAt))
    }
    private var weekCount: Int {
        GymMath.workoutsThisWeek(completedDates: sessions.map(\.startedAt))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if sessions.isEmpty {
                    emptyState.padding(.top, 56)
                } else {
                    statChips
                    dashboardSection
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

    private var statChips: some View {
        HStack(spacing: 10) {
            statChip(value: "\(streakDays)", label: streakDays == 1 ? "giorno di fila" : "giorni di fila",
                     icon: "flame.fill", color: Glass.coral)
            statChip(value: "\(weekCount)", label: weekCount == 1 ? "allenamento sett." : "allenamenti sett.",
                     icon: "calendar", color: Glass.green)
        }
    }

    private func statChip(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(Glass.display(16, .bold)).monospacedDigit()
                Text(label).font(Glass.body(11)).foregroundStyle(Glass.textSecondary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.06)))
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

    // MARK: - dashboard grafici (multi-esercizio)

    private var dashboardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "Grafici")
                Spacer()
                if exercises.count > dashboardExerciseLimit {
                    Text("top \(dashboardExerciseLimit) di \(exercises.count)")
                        .font(Glass.body(11)).foregroundStyle(Glass.textFaint)
                }
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                      spacing: 10) {
                ForEach(dashboardExercises, id: \.self) { name in
                    NavigationLink {
                        ExerciseChartsView(exercise: name, sessions: sessions)
                    } label: {
                        exerciseCard(name)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("gymExerciseCard_\(name)")
                }
            }
        }
    }

    private func exerciseCard(_ name: String) -> some View {
        let points = GymStats.oneRMSeries(sessions, exercise: name)
        return VStack(alignment: .leading, spacing: 8) {
            Text(name).font(Glass.body(12, .semibold)).foregroundStyle(Glass.textSecondary)
                .lineLimit(1)
            if let last = points.last {
                Text("\(fmt(last.value)) kg").font(Glass.display(18, .bold)).monospacedDigit()
            } else {
                Text("—").font(Glass.display(18, .bold)).foregroundStyle(Glass.textFaint)
            }
            if points.count >= 2 {
                MiniLineChart(values: points.map(\.value), drawn: points.map { _ in true },
                              color: Glass.green, target: nil)
                    .frame(height: 34)
            } else {
                Rectangle().fill(Glass.hairlineSoft).frame(height: 1)
                    .frame(height: 34, alignment: .center)
            }
        }
        .padding(12)
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

/// Drill-down da una card della dashboard: 1RM stimato + volume per un
/// singolo esercizio, a tutta larghezza (era `chartsSection` prima del
/// redesign a dashboard multi-esercizio).
struct ExerciseChartsView: View {
    let exercise: String
    let sessions: [WorkoutSession]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                chartCard("1RM stimato", unit: "kg",
                          points: GymStats.oneRMSeries(sessions, exercise: exercise), color: Glass.green)
                chartCard("Volume", unit: "kg",
                          points: GymStats.volumeSeries(sessions, exercise: exercise), color: Glass.accent)
            }
            .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .glassScreen(.progress)
        .navigationTitle(exercise)
        .navigationBarTitleDisplayMode(.inline)
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
                    .frame(height: 100)
            } else {
                Text("Servono almeno 2 allenamenti con questo esercizio.")
                    .font(Glass.body(11)).foregroundStyle(Glass.textFaint)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func fmt(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%.1f", d)
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
