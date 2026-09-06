//
//  AddExerciseView.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Crea un esercizio custom. Scrive in locale + accoda un OutboxEntry
//  (offline-first, ADR-0006); il POST parte subito se c'è rete.
//

import SwiftUI
import SwiftData

struct AddExerciseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var muscles = ""
    @State private var equipment = ""

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Nuovo esercizio")
                    .font(Glass.display(24, .bold))
                    .padding(.top, 8)

                field("Nome", text: $name, placeholder: "Panca piana", id: "exerciseName")
                field("Gruppi muscolari", text: $muscles, placeholder: "chest, triceps")
                field("Attrezzo", text: $equipment, placeholder: "bilanciere")

                GlassPrimaryButton(title: "Salva", action: save)
                    .opacity(canSave ? 1 : 0.4)
                    .disabled(!canSave)
                    .accessibilityIdentifier("saveExercise")
                    .padding(.top, 4)
            }
            .padding(20)
        }
        .glassScreen()
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String, id: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(Glass.body(11, .semibold))
                .foregroundStyle(Glass.textSecondary)
                .tracking(0.6)
            TextField("", text: text, prompt: Text(placeholder).foregroundColor(Glass.textSecondary))
                .font(Glass.body(16))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.12)))
                .accessibilityIdentifier(id ?? label)
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let groups = muscles
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let eq = equipment.trimmingCharacters(in: .whitespaces)
        let ex = Exercise(name: trimmed, muscleGroups: groups, equipment: eq.isEmpty ? nil : eq)
        context.insert(ex)

        var payload: [String: Any] = ["id": ex.id.uuidString, "name": trimmed, "muscleGroups": groups]
        if !eq.isEmpty { payload["equipment"] = eq }
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            context.insert(OutboxEntry(kind: "exercise.create", payload: data))
        }
        try? context.save()

        let ctx = context
        Task { await GymSync.flushOutbox(ctx) }
        dismiss()
    }
}
