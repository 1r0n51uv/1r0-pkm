//
//  LogSetSheet.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Logga una serie dentro la sessione attiva: esercizio + peso + reps + RPE.
//  Offline-first: insert locale + OutboxEntry "setlog.create".
//

import SwiftUI
import SwiftData

struct LogSetSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let session: WorkoutSession
    var onLogged: () -> Void = {}

    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var picked: Exercise?
    @State private var weight = 60.0
    @State private var reps = 8
    @State private var rpe: Double? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Nuova serie")
                    .font(Glass.display(24, .bold))
                    .padding(.top, 8)

                labelled("ESERCIZIO") {
                    Menu {
                        ForEach(exercises) { e in
                            Button(e.name) { picked = e }
                        }
                    } label: {
                        HStack {
                            Text(picked?.name ?? "Scegli…")
                                .foregroundStyle(picked == nil ? Glass.textSecondary : Glass.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down").font(.caption)
                        }
                        .font(Glass.body(16))
                        .padding(14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Glass.hairline))
                    }
                    .accessibilityIdentifier("pickExercise")
                }

                HStack(spacing: 12) {
                    stepperBox("PESO", value: fmt(weight) + " kg") {
                        Stepper("", value: $weight, in: 0...500, step: 2.5).labelsHidden()
                    }
                    stepperBox("REPS", value: "\(reps)") {
                        Stepper("", value: $reps, in: 1...100).labelsHidden()
                    }
                }

                labelled("RPE (opz.)") {
                    Picker("", selection: $rpe) {
                        Text("—").tag(Double?.none)
                        ForEach([6.0, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10], id: \.self) { v in
                            Text(fmt(v)).tag(Double?.some(v))
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Button(action: log) {
                    Text("Registra")
                        .font(Glass.body(16, .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [Glass.accent, Glass.accent2],
                                           startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .foregroundStyle(.white)
                        .opacity(picked == nil ? 0.4 : 1)
                }
                .disabled(picked == nil)
                .accessibilityIdentifier("logSet")
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

    private func stepperBox<C: View>(_ t: String, value: String, @ViewBuilder _ stepper: () -> C) -> some View {
        labelled(t) {
            HStack {
                Text(value).font(Glass.display(20, .semibold)).monospacedDigit()
                Spacer()
                stepper()
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Glass.hairline))
        }
    }

    private func fmt(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%.1f", d)
    }

    private func log() {
        guard let ex = picked else { return }
        let idx = session.sets.filter { $0.exerciseId == ex.id }.count + 1
        let entry = SetLogEntry(
            session: session, exerciseId: ex.id, exerciseName: ex.name,
            setIndex: idx, weightKg: weight, reps: reps, rpe: rpe
        )
        context.insert(entry)

        var payload: [String: Any] = [
            "id": entry.id.uuidString,
            "sessionId": session.id.uuidString,
            "exerciseId": ex.id.uuidString,
            "setIndex": idx, "weightKg": weight, "reps": reps,
        ]
        if let rpe { payload["rpe"] = rpe }
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            context.insert(OutboxEntry(kind: "setlog.create", payload: data))
        }
        try? context.save()

        let ctx = context
        Task { await GymSync.flushOutbox(ctx) }
        onLogged()
        dismiss()
    }
}
