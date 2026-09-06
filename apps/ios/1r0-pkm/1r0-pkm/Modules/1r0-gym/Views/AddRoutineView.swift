//
//  AddRoutineView.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Crea una scheda (nome + fase). Offline-first: insert locale + OutboxEntry.
//

import SwiftUI
import SwiftData

struct AddRoutineView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var phase: RoutinePhase? = nil

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Nuova scheda")
                    .font(Glass.display(24, .bold))
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 6) {
                    Text("NOME")
                        .font(Glass.body(11, .semibold)).tracking(0.6)
                        .foregroundStyle(Glass.textSecondary)
                    TextField("", text: $name,
                              prompt: Text("Push Pull Legs").foregroundColor(Glass.textSecondary))
                        .font(Glass.body(16))
                        .padding(14)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.12)))
                        .accessibilityIdentifier("routineName")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("FASE")
                        .font(Glass.body(11, .semibold)).tracking(0.6)
                        .foregroundStyle(Glass.textSecondary)
                    HStack(spacing: 8) {
                        chip(nil, "—")
                        ForEach(RoutinePhase.allCases) { p in chip(p, p.label) }
                    }
                }

                GlassPrimaryButton(title: "Salva", action: save)
                    .opacity(canSave ? 1 : 0.4)
                    .disabled(!canSave)
                    .accessibilityIdentifier("saveRoutine")
                    .padding(.top, 4)
            }
            .padding(20)
        }
        .glassScreen()
    }

    private func chip(_ p: RoutinePhase?, _ label: String) -> some View {
        let selected = phase == p
        let hue = Glass.phaseColor(p?.rawValue)
        return Button { phase = p } label: {
            Text(label)
                .font(Glass.body(13, selected ? .bold : .semibold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(selected ? hue.opacity(0.16) : Color.white.opacity(0.06)))
                .overlay(Capsule().strokeBorder(selected ? hue.opacity(0.4) : .clear, lineWidth: 1))
                .foregroundStyle(selected ? hue : Glass.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let r = Routine(name: trimmed, phase: phase)
        context.insert(r)

        var payload: [String: Any] = ["id": r.id.uuidString, "name": trimmed]
        if let phase { payload["phase"] = phase.rawValue }
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            context.insert(OutboxEntry(kind: "routine.create", payload: data))
        }
        try? context.save()

        let ctx = context
        Task { await GymSync.flushOutbox(ctx) }
        dismiss()
    }
}
