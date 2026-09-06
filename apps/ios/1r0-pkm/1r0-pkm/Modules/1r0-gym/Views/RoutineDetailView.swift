//
//  RoutineDetailView.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Dettaglio scheda: giorni + esercizi con target, e il suggerimento di
//  progressione (double progression, ADR-0011) calcolato dall'ultima
//  sessione completata. Stile Glass Dark (ADR-0023).
//

import SwiftUI
import SwiftData

struct RoutineDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var routine: Routine

    // @Query diretti sui figli: il re-render è affidabile, la traversata di
    // routine.days / day.exercises no.
    @Query(sort: \RoutineDay.orderIndex) private var allDays: [RoutineDay]
    @Query(sort: \RoutineExercise.orderIndex) private var allExercises: [RoutineExercise]
    @Query(
        filter: #Predicate<WorkoutSession> { $0.statusRaw == "completed" },
        sort: \WorkoutSession.startedAt, order: .reverse
    ) private var completed: [WorkoutSession]

    @State private var addExerciseFor: RoutineDay?
    @State private var newDayName = ""
    @State private var showAddDay = false

    private var days: [RoutineDay] {
        allDays.filter { $0.routine?.id == routine.id }
    }
    private func exercises(of day: RoutineDay) -> [RoutineExercise] {
        allExercises.filter { $0.day?.id == day.id }
    }
    private let incrementKg = 2.5

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                ForEach(days) { day in dayPanel(day) }

                Button {
                    newDayName = ""
                    showAddDay = true
                } label: {
                    HStack { Image(systemName: "plus"); Text("Aggiungi giorno") }
                        .font(Glass.body(15, .semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Glass.hairline))
                }
                .accessibilityIdentifier("addDay")
            }
            .padding(.horizontal, 18).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .glassScreen()
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Nuovo giorno", isPresented: $showAddDay) {
            TextField("Push / Pull / Legs", text: $newDayName)
            Button("Annulla", role: .cancel) {}
            Button("Aggiungi") { addDay() }
        }
        .sheet(item: $addExerciseFor) { day in
            AddRoutineExerciseSheet(day: day)
                .presentationDetents([.large])
                .presentationBackground(.ultraThinMaterial)
        }
        .task { await GymSync.pullRoutineTree(routineId: routine.id, into: context) }
    }

    private var header: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3).fill(Glass.phaseColor(routine.phaseRaw)).frame(width: 4, height: 30)
            Text("\(days.count) giorni")
                .font(Glass.body(14)).foregroundStyle(Glass.textSecondary)
            if let p = routine.phase {
                Text(p.label.uppercased())
                    .font(Glass.body(10, .bold)).tracking(0.6).foregroundStyle(Glass.bg)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Glass.phaseColor(routine.phaseRaw), in: Capsule())
            }
            Spacer()
        }
        .padding(.top, 6)
    }

    private func dayPanel(_ day: RoutineDay) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text(day.name).font(Glass.body(17, .bold))

                let exs = exercises(of: day)
                if exs.isEmpty {
                    Text("nessun esercizio").font(Glass.body(13)).foregroundStyle(Glass.textSecondary)
                } else {
                    ForEach(exs) { re in exerciseRow(re) }
                }

                Button { addExerciseFor = day } label: {
                    HStack(spacing: 5) { Image(systemName: "plus.circle"); Text("Esercizio") }
                        .font(Glass.body(13, .semibold)).foregroundStyle(Glass.accent)
                }
                .accessibilityIdentifier("addExerciseToDay")
            }
        }
    }

    private func exerciseRow(_ re: RoutineExercise) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(re.exerciseName).font(Glass.body(15, .semibold))
                Spacer()
                Text("\(re.targetSets)×\(re.targetReps) · rec \(re.targetRestSeconds)s")
                    .font(Glass.body(12)).foregroundStyle(Glass.textSecondary).monospacedDigit()
            }
            if let advice = advice(for: re) {
                Text(adviceText(advice))
                    .font(Glass.body(11, .semibold))
                    .foregroundStyle(Glass.good)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Glass.good.opacity(0.14), in: Capsule())
            }
        }
        .padding(.vertical, 3)
    }

    private func advice(for re: RoutineExercise) -> GymMath.ProgressionAdvice? {
        guard let range = re.repRange else { return nil }
        guard let session = completed.first(where: { s in
            s.sets.contains { $0.exerciseId == re.exerciseId }
        }) else { return nil }
        let last = session.sets
            .filter { $0.exerciseId == re.exerciseId }
            .map { (weightKg: $0.weightKg, reps: $0.reps) }
        return GymMath.doubleProgression(targetSets: re.targetSets, repRange: range,
                                         incrementKg: incrementKg, lastSets: last)
    }

    private func adviceText(_ a: GymMath.ProgressionAdvice) -> String {
        switch a {
        case .addWeight(let kg): return "prossima: \(fmt(kg)) kg"
        case .addReps: return "prossima: +1 rep"
        case .repeatSame: return "prossima: ripeti"
        }
    }
    private func fmt(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%.1f", d)
    }

    private func addDay() {
        let n = newDayName.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        let day = RoutineDay(routine: routine, name: n, orderIndex: days.count)
        context.insert(day)
        enqueue("routineday.create", [
            "id": day.id.uuidString, "routineId": routine.id.uuidString,
            "name": n, "orderIndex": days.count,
        ])
    }

    private func enqueue(_ kind: String, _ payload: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            context.insert(OutboxEntry(kind: kind, payload: data))
        }
        try? context.save()
        let ctx = context
        Task { await GymSync.flushOutbox(ctx) }
    }
}
