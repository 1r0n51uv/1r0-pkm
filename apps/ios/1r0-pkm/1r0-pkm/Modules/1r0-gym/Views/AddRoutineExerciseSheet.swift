//
//  AddRoutineExerciseSheet.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Aggiunge un esercizio (dal catalogo) a un giorno di scheda, con target
//  serie/reps/riposo. Offline-first: insert locale + OutboxEntry.
//

import SwiftUI
import SwiftData

struct AddRoutineExerciseSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let day: RoutineDay

    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var picked: Exercise?
    @State private var showPicker = false
    @State private var sets = 3
    @State private var repMin = 8
    @State private var repMax = 12
    @State private var rest = 90

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Esercizio in \(day.name)")
                    .font(Glass.display(22, .bold)).padding(.top, 8)

                labelled("ESERCIZIO") {
                    VStack(spacing: 0) {
                        Button {
                            withAnimation(.snappy(duration: 0.18)) { showPicker.toggle() }
                        } label: {
                            HStack {
                                Text(picked?.name ?? "Scegli…")
                                    .foregroundStyle(picked == nil ? Glass.textSecondary : Glass.textPrimary)
                                Spacer()
                                Image(systemName: showPicker ? "chevron.up" : "chevron.down").font(.caption)
                            }
                            .font(Glass.body(16)).padding(14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("pickRoutineExercise")

                        if showPicker {
                            Divider().overlay(Glass.hairline)
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(exercises) { e in
                                        Button {
                                            picked = e
                                            withAnimation(.snappy(duration: 0.18)) { showPicker = false }
                                        } label: {
                                            HStack {
                                                Text(e.name).font(Glass.body(15))
                                                    .foregroundStyle(Glass.textPrimary)
                                                Spacer()
                                                if picked?.id == e.id {
                                                    Image(systemName: "checkmark").font(.caption).foregroundStyle(Glass.accent)
                                                }
                                            }
                                            .padding(.horizontal, 14).padding(.vertical, 11)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .frame(maxHeight: 220)
                        }
                    }
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Glass.hairline))
                }

                HStack(spacing: 12) {
                    stepBox("SERIE", "\(sets)") { Stepper("", value: $sets, in: 1...10).labelsHidden() }
                    stepBox("RIPOSO", "\(rest)s") { Stepper("", value: $rest, in: 0...600, step: 15).labelsHidden() }
                }
                HStack(spacing: 12) {
                    stepBox("REPS MIN", "\(repMin)") {
                        Stepper("", value: $repMin, in: 1...30).labelsHidden()
                            .onChange(of: repMin) { _, v in if v > repMax { repMax = v } }
                    }
                    stepBox("REPS MAX", "\(repMax)") {
                        Stepper("", value: $repMax, in: 1...30).labelsHidden()
                            .onChange(of: repMax) { _, v in if v < repMin { repMin = v } }
                    }
                }

                Button(action: save) {
                    Text("Aggiungi").font(Glass.body(16, .semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(LinearGradient(colors: [Glass.accent, Glass.accent2],
                                                  startPoint: .leading, endPoint: .trailing),
                                   in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white).opacity(picked == nil ? 0.4 : 1)
                }
                .disabled(picked == nil)
                .accessibilityIdentifier("saveRoutineExercise")
            }
            .padding(20)
        }
        .glassScreen()
        .onAppear { if picked == nil { picked = exercises.first } }
    }

    private func labelled<C: View>(_ t: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t).font(Glass.body(11, .semibold)).tracking(0.6).foregroundStyle(Glass.textSecondary)
            c()
        }
    }
    private func stepBox<C: View>(_ t: String, _ v: String, @ViewBuilder _ s: () -> C) -> some View {
        labelled(t) {
            HStack {
                Text(v).font(Glass.display(18, .semibold)).monospacedDigit()
                Spacer(); s()
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Glass.hairline))
        }
    }

    private func save() {
        guard let ex = picked else { return }
        let reps = repMin == repMax ? "\(repMin)" : "\(repMin)-\(repMax)"
        let order = day.exercises.count
        let re = RoutineExercise(
            day: day, exerciseId: ex.id, exerciseName: ex.name, orderIndex: order,
            targetSets: sets, targetReps: reps, targetRestSeconds: rest
        )
        context.insert(re)
        let payload: [String: Any] = [
            "id": re.id.uuidString, "routineDayId": day.id.uuidString,
            "exerciseId": ex.id.uuidString, "orderIndex": order,
            "targetSets": sets, "targetReps": reps, "targetRestSeconds": rest,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            context.insert(OutboxEntry(kind: "routineexercise.create", payload: data))
        }
        try? context.save()
        let ctx = context
        Task { await GymSync.flushOutbox(ctx) }
        dismiss()
    }
}
