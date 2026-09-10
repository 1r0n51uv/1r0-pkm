//
//  ImportWorkoutsView.swift
//  1r0-pkm · Modules/1r0-gym/Views
//
//  Import CSV Liftin' (ADR-0027 step 3, slice locale). Scegli il file →
//  `WorkoutImport.merge` (dedup su giorno/routine/esercizio/set) → riepilogo.
//  La vista storico + grafici arriva nello slice successivo.
//

import SwiftUI
import SwiftData

struct ImportWorkoutsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query private var sessions: [WorkoutSession]
    @Query private var sets: [SetLogEntry]

    @State private var picking = false
    @State private var result: Result<WorkoutImport.Summary, Error>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Import allenamenti")
                    .font(Glass.display(24, .bold)).padding(.top, 4)
                Text("Importa l'export CSV dell'app Liftin'. Ri-importare lo "
                     + "stesso file non crea doppioni: le serie già presenti "
                     + "vengono aggiornate (dedup su data · scheda · esercizio · set).")
                    .font(Glass.body(13)).foregroundStyle(Glass.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                GlassPrimaryButton(title: "Scegli file CSV", systemImage: "square.and.arrow.down",
                                   fill: Glass.accent, onInk: .white) {
                    picking = true
                }
                .accessibilityIdentifier("pickCSV")

                if let result {
                    switch result {
                    case .success(let s):
                        summaryCard(s)
                    case .failure(let e):
                        Text(e.localizedDescription)
                            .font(Glass.body(13, .semibold)).foregroundStyle(Glass.coralLight)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Glass.coral.opacity(0.12)))
                    }
                }

                SectionLabel(text: "Nel dispositivo")
                HStack(spacing: 24) {
                    stat("\(sessions.count)", "allenamenti")
                    stat("\(sets.count)", "serie")
                    stat("\(Set(sets.map(\.exerciseKey)).count)", "esercizi")
                }
            }
            .padding(.horizontal, 22).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .glassScreen(.progress)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Fine") { dismiss() }.font(Glass.body(14, .bold))
            }
        }
        .sheet(isPresented: $picking) {
            DocumentPicker { picked in
                picking = false
                switch picked {
                case .success(let text):
                    result = Result { try WorkoutImport.merge(csv: text, into: context) }
                    if case .success(let s)? = result, !s.isEmpty {
                        let ctx = context
                        Task { await Outbox.flushOutbox(ctx) }
                    }
                case .failure(let e):
                    result = .failure(e)
                }
            }
        }
    }

    private func summaryCard(_ s: WorkoutImport.Summary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(s.isEmpty ? "Nessuna novità" : "Import completato")
                .font(Glass.body(14, .bold)).foregroundStyle(Glass.greenText)
            Text("\(s.rowsParsed) righe · \(s.sessionsCreated) allenamenti nuovi, "
                 + "\(s.sessionsUpdated) aggiornati · \(s.setsCreated) serie nuove, "
                 + "\(s.setsUpdated) aggiornate")
                .font(Glass.body(12)).foregroundStyle(Glass.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Glass.green.opacity(0.12)))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(Glass.display(22, .bold)).monospacedDigit()
            Text(label).font(Glass.body(11)).foregroundStyle(Glass.textFaint)
        }
    }
}
