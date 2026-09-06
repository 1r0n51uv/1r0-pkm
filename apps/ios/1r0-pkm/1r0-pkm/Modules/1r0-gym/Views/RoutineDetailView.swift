//
//  RoutineDetailView.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Dettaglio scheda: giorni + esercizi con target, e il suggerimento di
//  progressione (double progression, ADR-0011) calcolato dall'ultima
//  sessione completata. Stile Glass Dark (ADR-0023), layout dal mockup
//  "GlassRoutineBuilder": header modale, righe con rail di fase + tile,
//  bottoni "aggiungi" tratteggiati.
//

import SwiftUI
import SwiftData

struct RoutineDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var routine: Routine

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
    private var phaseHue: Color { Glass.phaseColor(routine.phaseRaw) }

    var body: some View {
        VStack(spacing: 0) {
            modalHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let p = routine.phase {
                        PhasePill(text: p.label, color: phaseHue)
                    }

                    ForEach(days) { day in daySection(day) }

                    dashedButton("Aggiungi giorno") {
                        newDayName = ""
                        showAddDay = true
                    }
                    .accessibilityIdentifier("addDay")
                }
                .padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .glassScreen()
        .toolbar(.hidden, for: .navigationBar)
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

    private var modalHeader: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Glass.ink.opacity(0.75))
                    .frame(width: 44, height: 44, alignment: .leading)
            }
            Spacer()
            Text(routine.name).font(Glass.display(16, .semibold)).lineLimit(1)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 22).padding(.top, 8)
    }

    private func daySection(_ day: RoutineDay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: day.name)

            let exs = exercises(of: day)
            if exs.isEmpty {
                Text("Nessun esercizio")
                    .font(Glass.body(13)).foregroundStyle(Glass.textTertiary)
                    .padding(.leading, 4).padding(.vertical, 4)
            } else {
                ForEach(exs) { re in exerciseRow(re) }
            }

            dashedButton("Aggiungi esercizio", small: true) { addExerciseFor = day }
                .accessibilityIdentifier("addExerciseToDay")
        }
    }

    private func exerciseRow(_ re: RoutineExercise) -> some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 999)
                .fill(phaseHue.opacity(0.5))
                .frame(width: 4)
            HStack(spacing: 12) {
                MuscleTile(groups: [], size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(re.exerciseName).font(Glass.body(14, .semibold)).lineLimit(1)
                    Text("\(re.targetSets) serie · \(re.targetReps) reps · \(re.targetRestSeconds)s riposo")
                        .font(Glass.body(12)).foregroundStyle(Glass.ink.opacity(0.45))
                        .monospacedDigit()
                    if let advice = advice(for: re) {
                        Text(adviceText(advice))
                            .font(Glass.body(11, .semibold))
                            .foregroundStyle(Glass.greenText)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Glass.green.opacity(0.16), in: Capsule())
                            .padding(.top, 1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .glassRow()
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func dashedButton(_ title: String, small: Bool = false,
                              _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text(title)
            }
            .font(Glass.body(small ? 13 : 15, .semibold))
            .foregroundStyle(Glass.ink.opacity(0.7))
            .frame(maxWidth: .infinity)
            .frame(height: small ? 44 : 52)
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Color.white.opacity(0.20), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
        }
        .buttonStyle(.plain)
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
