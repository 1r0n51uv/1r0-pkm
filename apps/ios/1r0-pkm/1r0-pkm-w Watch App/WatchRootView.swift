//
//  WatchRootView.swift
//  1r0-pkm-w Watch App
//
//  Flusso di sessione sul Watch (ADR-0016): idle → sessione live con log
//  serie, pausa/riprendi, termina/annulla.
//

import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject private var model: WatchSessionModel

    var body: some View {
        NavigationStack {
            if model.isActive {
                WatchLiveView()
            } else {
                idle
            }
        }
    }

    private var idle: some View {
        VStack(spacing: 12) {
            Text("1r0-gym").font(.headline)
            Button {
                model.start()
            } label: {
                Label("Inizia sessione", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("wStart")
        }
        .padding()
    }
}

struct WatchLiveView: View {
    @EnvironmentObject private var model: WatchSessionModel
    @State private var showLog = false
    @State private var confirmCancel = false

    var body: some View {
        List {
            Section {
                if let started = model.startedAt {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        HStack {
                            Text(model.isPaused ? "in pausa" : elapsed(started, ctx.date))
                                .font(.system(.title3, design: .rounded)).monospacedDigit()
                            Spacer()
                            Text("\(model.loggedSets.count) serie")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Serie") {
                if model.loggedSets.isEmpty {
                    Text("nessuna").font(.caption2).foregroundStyle(.secondary)
                } else {
                    ForEach(Array(model.loggedSets.enumerated()), id: \.offset) { i, s in
                        Text("\(i + 1)   \(fmt(s.weightKg)) kg × \(s.reps)")
                            .font(.footnote)
                    }
                }
                Button {
                    showLog = true
                } label: { Label("Serie", systemImage: "plus") }
                    .accessibilityIdentifier("wAddSet")
            }

            Section {
                if model.isPaused {
                    Button("Riprendi") { model.resume() }.accessibilityIdentifier("wResume")
                } else {
                    Button("Pausa") { model.pause() }.accessibilityIdentifier("wPause")
                }
                Button("Termina") { model.end(cancelled: false) }
                    .accessibilityIdentifier("wEnd")
                Button("Annulla sessione", role: .destructive) { confirmCancel = true }
                    .accessibilityIdentifier("wCancel")
            }
        }
        .navigationTitle("Sessione")
        .sheet(isPresented: $showLog) {
            WatchLogSetView { w, r in model.logSet(weightKg: w, reps: r) }
        }
        .confirmationDialog("Annullare la sessione?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Annulla sessione", role: .destructive) { model.end(cancelled: true) }
            Button("No", role: .cancel) {}
        }
    }

    private func elapsed(_ from: Date, _ now: Date) -> String {
        let s = max(0, Int(now.timeIntervalSince(from)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
    private func fmt(_ d: Double) -> String { d == d.rounded() ? String(Int(d)) : String(format: "%.1f", d) }
}

struct WatchLogSetView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (Double, Int) -> Void
    @State private var weight = 60.0
    @State private var reps = 8

    var body: some View {
        VStack(spacing: 10) {
            Stepper(value: $weight, in: 0...400, step: 2.5) {
                Text("\(weight == weight.rounded() ? String(Int(weight)) : String(format: "%.1f", weight)) kg")
                    .monospacedDigit()
            }
            .accessibilityIdentifier("wWeight")
            Stepper(value: $reps, in: 1...50) {
                Text("\(reps) reps").monospacedDigit()
            }
            .accessibilityIdentifier("wReps")
            Button("Registra") { onSave(weight, reps); dismiss() }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("wLogConfirm")
        }
        .padding()
    }
}
