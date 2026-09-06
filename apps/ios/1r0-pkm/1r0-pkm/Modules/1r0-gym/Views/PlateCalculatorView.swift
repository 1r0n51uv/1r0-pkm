//
//  PlateCalculatorView.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Calcolatore piastre + rampa di warm-up (ADR-0013). Calcolo puramente
//  client-side (GymMath); la config bilanciere/dischi arriva da PlateConfig.
//

import SwiftUI
import SwiftData

struct PlateCalculatorView: View {
    @Environment(\.modelContext) private var context
    @Query private var configs: [PlateConfig]
    @State private var target: Double
    @State private var showConfig = false

    init(initialWeightKg: Double) {
        _target = State(initialValue: max(0, initialWeightKg.rounded()))
    }

    private var cfg: PlateConfig { configs.first ?? PlateConfig() }
    private var load: GymMath.PlateLoad {
        GymMath.platesPerSide(targetKg: target, barKg: cfg.barWeightKg, availablePlatesKg: cfg.availablePlatesKg)
    }
    private var warmup: [GymMath.WarmupStep] {
        GymMath.warmupRamp(workingWeightKg: target, barKg: cfg.barWeightKg, availablePlatesKg: cfg.availablePlatesKg)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Piastre")
                    .font(Glass.display(24, .bold))
                    .padding(.top, 8)

                GlassPanel {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Peso di lavoro").font(Glass.body(12)).foregroundStyle(Glass.textSecondary)
                            Text("\(fmt(target)) kg").font(Glass.display(28, .semibold)).monospacedDigit()
                        }
                        Spacer()
                        Stepper("", value: $target, in: 0...500, step: 2.5).labelsHidden()
                    }
                }

                GlassPanel {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("PER LATO").font(Glass.body(11, .semibold)).tracking(0.6).foregroundStyle(Glass.textSecondary)
                        if load.perSide.isEmpty {
                            Text("solo bilanciere (\(fmt(cfg.barWeightKg)) kg)")
                                .font(Glass.body(14)).foregroundStyle(Glass.textSecondary)
                        } else {
                            HStack(spacing: 6) {
                                ForEach(Array(load.perSide.enumerated()), id: \.offset) { _, p in
                                    plateChip(p)
                                }
                            }
                        }
                        HStack(spacing: 6) {
                            Text("caricabile \(fmt(load.achievable)) kg")
                                .font(Glass.body(13, .medium))
                            if load.leftover > 0.001 {
                                Text("· −\(fmt(load.leftover)) kg")
                                    .font(Glass.body(13, .medium))
                                    .foregroundStyle(Glass.accent2)
                            }
                        }
                    }
                }

                GlassPanel {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("WARM-UP").font(Glass.body(11, .semibold)).tracking(0.6).foregroundStyle(Glass.textSecondary)
                        ForEach(Array(warmup.enumerated()), id: \.offset) { _, step in
                            HStack {
                                Text("\(Int(step.percent * 100))%")
                                    .font(Glass.body(13, .bold)).foregroundStyle(Glass.accent)
                                    .frame(width: 44, alignment: .leading)
                                Text("\(fmt(step.load.achievable)) kg")
                                    .font(Glass.body(15)).monospacedDigit()
                                Spacer()
                                HStack(spacing: 4) {
                                    ForEach(Array(step.load.perSide.enumerated()), id: \.offset) { _, p in
                                        Text(fmt(p)).font(Glass.body(10, .bold))
                                            .padding(.horizontal, 5).padding(.vertical, 2)
                                            .background(plateColor(p), in: Capsule())
                                            .foregroundStyle(.black)
                                    }
                                }
                            }
                        }
                    }
                }

                Button {
                    showConfig = true
                } label: {
                    HStack { Image(systemName: "slider.horizontal.3"); Text("Dischi disponibili") }
                        .font(Glass.body(14, .semibold))
                        .foregroundStyle(Glass.textSecondary)
                }
                .accessibilityIdentifier("editPlateConfig")
            }
            .padding(20)
        }
        .glassScreen()
        .sheet(isPresented: $showConfig) {
            PlateConfigView()
                .presentationDetents([.medium])
                .presentationBackground(.ultraThinMaterial)
        }
        .task { await GymSync.pullPlateConfig(into: context) }
    }

    private func plateChip(_ p: Double) -> some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 4)
                .fill(plateColor(p))
                .frame(width: 22, height: plateHeight(p))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.black.opacity(0.3)))
            Text(fmt(p)).font(Glass.body(10, .bold)).foregroundStyle(Glass.textSecondary)
        }
    }

    private func plateHeight(_ p: Double) -> CGFloat {
        switch p {
        case 25: return 62; case 20: return 56; case 15: return 48
        case 10: return 40; case 5: return 32; case 2.5: return 26
        default: return 22
        }
    }
    private func plateColor(_ p: Double) -> Color {
        switch p {
        case 25: return Color(red: 0.82, green: 0.28, blue: 0.30)     // rosso gara
        case 20: return Glass.coral                                   // canvas: 20 = 25°
        case 15: return Color(red: 0.95, green: 0.79, blue: 0.24)     // oro
        case 10: return Glass.blue                                    // canvas: 10 = 250°
        case 5:  return Glass.green
        case 2.5: return Glass.amber                                  // canvas: 2.5 = 55°
        default: return Color(white: 0.75)
        }
    }
    private func fmt(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%.2f", d).replacingOccurrences(of: ".00", with: "")
    }
}
