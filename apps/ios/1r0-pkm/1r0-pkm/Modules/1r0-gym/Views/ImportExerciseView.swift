//
//  ImportExerciseView.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Import esercizi non a catalogo (ADR-0005):
//   - "Cerca con AI": Claude propone i dati, l'utente conferma/modifica,
//     poi si salva come `source: "ai"` (offline-first: locale + outbox).
//   - "Sincronizza catalogo wger": import una tantum del DB pubblico wger
//     lato backend, poi ripull locale.
//  Stile Glass Dark (ADR-0023).
//

import SwiftUI
import SwiftData

struct ImportExerciseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var existing: [Exercise]

    @State private var query = ""
    @State private var phase: Phase = .idle
    @State private var proposal: Draft?
    @State private var wgerNote: String?

    private enum Phase: Equatable { case idle, searching, syncing }

    /// Bozza editabile dopo la proposta AI.
    private struct Draft {
        var name: String
        var muscles: String
        var equipment: String
        var instructions: String
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Importa esercizio")
                    .font(Glass.display(24, .bold)).padding(.top, 8)

                aiSection
                Divider().overlay(Glass.hairline)
                wgerSection
            }
            .padding(20)
        }
        .glassScreen()
        .scrollDismissesKeyboard(.immediately)
    }

    // MARK: - AI

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CERCA CON AI")
                .font(Glass.body(11, .semibold)).tracking(0.6)
                .foregroundStyle(Glass.textSecondary)

            HStack(spacing: 10) {
                TextField("", text: $query,
                          prompt: Text("es. jefferson curl").foregroundColor(Glass.textSecondary))
                    .font(Glass.body(16))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Glass.hairline))
                    .accessibilityIdentifier("aiQuery")

                Button {
                    Task { await runAISearch() }
                } label: {
                    Group {
                        if phase == .searching { ProgressView() }
                        else { Image(systemName: "sparkle.magnifyingglass") }
                    }
                    .frame(width: 46, height: 46)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Glass.hairline))
                }
                .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || phase != .idle)
                .accessibilityIdentifier("aiSearch")
            }

            if let note = aiNote {
                Text(note).font(Glass.body(12)).foregroundStyle(Glass.accent2)
            }

            if proposal != nil {
                proposalForm
            }
        }
    }

    @State private var aiNote: String?

    @ViewBuilder
    private var proposalForm: some View {
        if let p = Binding($proposal) {
            VStack(alignment: .leading, spacing: 10) {
                field("Nome", text: p.name, id: "aiName")
                field("Gruppi muscolari", text: p.muscles)
                field("Attrezzo", text: p.equipment)
                field("Istruzioni", text: p.instructions, axis: .vertical)

                if let dupe = duplicateName(p.wrappedValue.name) {
                    Text("Esiste già un esercizio “\(dupe)”. Puoi salvarlo comunque.")
                        .font(Glass.body(12)).foregroundStyle(Glass.accent2)
                }

                Button(action: saveProposal) {
                    Text("Salva esercizio").font(Glass.body(16, .semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(LinearGradient(colors: [Glass.accent, Glass.accent2],
                                                  startPoint: .leading, endPoint: .trailing),
                                   in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white)
                        .opacity(p.wrappedValue.name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                }
                .disabled(p.wrappedValue.name.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("aiSave")
            }
            .padding(14)
            .background(Glass.hairline.opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - wger

    private var wgerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CATALOGO WGER")
                .font(Glass.body(11, .semibold)).tracking(0.6)
                .foregroundStyle(Glass.textSecondary)
            Text("Scarica il database esercizi pubblico wger. Una volta sola: rilanciarlo aggiorna soltanto.")
                .font(Glass.body(13)).foregroundStyle(Glass.textSecondary)

            Button {
                Task { await runWgerSync() }
            } label: {
                HStack {
                    if phase == .syncing { ProgressView() }
                    else { Image(systemName: "arrow.down.circle") }
                    Text(phase == .syncing ? "Sincronizzo…" : "Sincronizza catalogo wger")
                }
                .font(Glass.body(15, .semibold))
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Glass.hairline))
            }
            .disabled(phase != .idle)
            .accessibilityIdentifier("wgerSync")

            if let n = wgerNote {
                Text(n).font(Glass.body(12)).foregroundStyle(Glass.textSecondary)
            }
        }
    }

    // MARK: - actions

    @MainActor
    private func runAISearch() async {
        aiNote = nil
        proposal = nil
        phase = .searching
        defer { phase = .idle }
        switch await GymSync.aiImport(query: query.trimmingCharacters(in: .whitespaces)) {
        case .success(let p):
            proposal = Draft(
                name: p.name,
                muscles: p.muscleGroups.joined(separator: ", "),
                equipment: p.equipment ?? "",
                instructions: p.instructions ?? ""
            )
        case .failure(.notConfigured):
            aiNote = "Import AI non configurato sul server (manca ANTHROPIC_API_KEY)."
        case .failure(.failed):
            aiNote = "Ricerca non riuscita. Riprova o crea l'esercizio a mano."
        }
    }

    @MainActor
    private func runWgerSync() async {
        wgerNote = nil
        phase = .syncing
        defer { phase = .idle }
        if let r = await GymSync.wgerSync(into: context) {
            wgerNote = "Fatto: \(r.inserted) nuovi, \(r.updated) aggiornati."
        } else {
            wgerNote = "Sync non riuscita (server irraggiungibile o wger giù)."
        }
    }

    private func saveProposal() {
        guard let d = proposal else { return }
        let name = d.name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let groups = d.muscles.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let eq = d.equipment.trimmingCharacters(in: .whitespaces)
        let instr = d.instructions.trimmingCharacters(in: .whitespaces)

        let ex = Exercise(
            name: name, muscleGroups: groups,
            equipment: eq.isEmpty ? nil : eq, source: "ai",
            instructions: instr.isEmpty ? nil : instr
        )
        context.insert(ex)

        var payload: [String: Any] = [
            "id": ex.id.uuidString, "name": name,
            "muscleGroups": groups, "source": "ai",
        ]
        if !eq.isEmpty { payload["equipment"] = eq }
        if !instr.isEmpty { payload["instructions"] = instr }
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            context.insert(OutboxEntry(kind: "exercise.create", payload: data))
        }
        try? context.save()
        let ctx = context
        Task { await GymSync.flushOutbox(ctx) }
        dismiss()
    }

    // MARK: - helpers

    private func duplicateName(_ name: String) -> String? {
        let n = normalize(name)
        guard !n.isEmpty else { return nil }
        return existing.first { normalize($0.name) == n }?.name
    }
    private func normalize(_ s: String) -> String {
        s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private func field(_ label: String, text: Binding<String>, id: String? = nil,
                       axis: Axis = .horizontal) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(Glass.body(11, .semibold)).tracking(0.6)
                .foregroundStyle(Glass.textSecondary)
            TextField("", text: text, axis: axis)
                .font(Glass.body(15))
                .lineLimit(axis == .vertical ? 5 : 1)
                .textInputAutocapitalization(.sentences)
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Glass.hairline))
                .accessibilityIdentifier(id ?? label)
        }
    }
}
