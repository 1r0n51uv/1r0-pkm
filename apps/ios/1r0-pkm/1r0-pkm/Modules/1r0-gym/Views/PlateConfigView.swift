//
//  PlateConfigView.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Modifica bilanciere + dischi disponibili (glossario: Plate Set Config).
//  Offline-first: aggiorna la riga singleton + accoda "plateconfig.put".
//

import SwiftUI
import SwiftData

struct PlateConfigView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var configs: [PlateConfig]

    private let denominations: [Double] = [1.25, 2.5, 5, 10, 15, 20, 25]

    private var cfg: PlateConfig {
        if let c = configs.first { return c }
        let c = PlateConfig()
        context.insert(c)
        return c
    }

    var body: some View {
        let cfg = self.cfg
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Dischi disponibili")
                    .font(Glass.display(22, .bold))
                    .padding(.top, 8)

                GlassPanel {
                    HStack {
                        Text("Bilanciere").font(Glass.body(15))
                        Spacer()
                        Text("\(fmt(cfg.barWeightKg)) kg").font(Glass.body(15, .semibold)).monospacedDigit()
                        Stepper("", value: bind(\.barWeightKg, on: cfg), in: 5...30, step: 2.5).labelsHidden()
                    }
                }

                GlassPanel {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("DISCHI (kg)").font(Glass.body(11, .semibold)).tracking(0.6).foregroundStyle(Glass.textSecondary)
                        ForEach(denominations, id: \.self) { d in
                            Toggle(isOn: toggleBinding(d, on: cfg)) {
                                Text(fmt(d)).font(Glass.body(15))
                            }
                            .tint(Glass.accent)
                        }
                    }
                }

                GlassPrimaryButton(title: "Fatto") { save(cfg); dismiss() }
                    .accessibilityIdentifier("savePlateConfig")
            }
            .padding(20)
        }
        .glassScreen()
    }

    private func bind(_ kp: ReferenceWritableKeyPath<PlateConfig, Double>, on cfg: PlateConfig) -> Binding<Double> {
        Binding(get: { cfg[keyPath: kp] }, set: { cfg[keyPath: kp] = $0 })
    }
    private func toggleBinding(_ d: Double, on cfg: PlateConfig) -> Binding<Bool> {
        Binding(
            get: { cfg.availablePlatesKg.contains(d) },
            set: { on in
                var s = Set(cfg.availablePlatesKg)
                if on { s.insert(d) } else { s.remove(d) }
                cfg.availablePlatesKg = s.sorted()
            }
        )
    }

    private func save(_ cfg: PlateConfig) {
        cfg.syncedAt = nil
        let payload: [String: Any] = [
            "barWeightKg": cfg.barWeightKg,
            "availablePlatesKg": cfg.availablePlatesKg,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            context.insert(OutboxEntry(kind: "plateconfig.put", payload: data))
        }
        try? context.save()
        let ctx = context
        Task { await GymSync.flushOutbox(ctx) }
    }

    private func fmt(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%.2f", d).replacingOccurrences(of: ".00", with: "")
    }
}
