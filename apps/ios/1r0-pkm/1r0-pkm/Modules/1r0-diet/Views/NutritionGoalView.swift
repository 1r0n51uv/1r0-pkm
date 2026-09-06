//
//  NutritionGoalView.swift
//  1r0-pkm · Modules/1r0-diet
//
//  Impostazione dell'obiettivo calorico/macro (ADR-0019). Tre modalità, una
//  attiva alla volta: Manuale, Legato alla scheda (fase), TDEE. "Salva"
//  inserisce una NUOVA riga append-only. Layout dal mockup
//  "GlassNutritionGoals" — accento ambra.
//

import SwiftUI
import SwiftData

struct NutritionGoalView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \NutritionGoal.effectiveFrom, order: .reverse) private var goals: [NutritionGoal]
    @Query(sort: \BodyMeasurement.recordedAt, order: .reverse) private var measurements: [BodyMeasurement]
    @Query(sort: \Routine.createdAt, order: .reverse) private var routines: [Routine]

    @State private var mode: GoalMode = .manual
    @State private var activity: ActivityLevel = .moderate
    @State private var kcal = "2200"
    @State private var protein = "170"
    @State private var carbs = "220"
    @State private var fat = "70"
    @State private var seeded = false

    private var latestWeight: Double? {
        measurements.first(where: { $0.weightKg != nil })?.weightKg
    }
    private var activePhase: RoutinePhase? {
        routines.first(where: { $0.phase != nil })?.phase
    }
    /// kcal di mantenimento per la modalità "fase": TDEE se c'è il peso,
    /// altrimenti la kcal dell'obiettivo corrente, altrimenti il default.
    private var maintenance: Double {
        if let w = latestWeight { return w * ActivityLevel.moderate.factor }
        return DietSync.current(goals)?.caloriesTarget ?? DietGoal.kcal
    }

    /// Macro effettivi in base alla modalità.
    private var computed: Macros {
        switch mode {
        case .manual:
            return Macros(kcal: num(kcal), proteinG: num(protein),
                          carbsG: num(carbs), fatG: num(fat))
        case .tdee:
            guard let w = latestWeight else { return .zero }
            return NutritionMath.tdee(weightKg: w, activity: activity)
        case .phase_linked:
            return NutritionMath.phaseAdjusted(maintenanceKcal: maintenance,
                                               weightKg: latestWeight ?? 75,
                                               phase: activePhase)
        }
    }

    private var canSave: Bool { computed.kcal > 0 }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    modePicker
                    Text(mode.blurb)
                        .font(Glass.body(13)).foregroundStyle(Glass.ink.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)

                    contextLine

                    let m = computed
                    targetRow("Calorie", value: $kcal, unit: "kcal", dot: nil, computed: m.kcal)
                    targetRow("Proteine", value: $protein, unit: "g", dot: Glass.coral, computed: m.proteinG)
                    targetRow("Carboidrati", value: $carbs, unit: "g", dot: Glass.blue, computed: m.carbsG)
                    targetRow("Grassi", value: $fat, unit: "g", dot: Glass.amber, computed: m.fatG)

                    Text(breakdown(m))
                        .font(Glass.body(12)).foregroundStyle(Glass.ink.opacity(0.4))
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.04)))
                }
                .padding(.horizontal, 22).padding(.top, 4).padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .glassScreen(.progress)
        .onAppear(perform: seed)
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Glass.ink.opacity(0.75))
                    .frame(width: 44, height: 44, alignment: .leading)
            }
            Spacer()
            Text("Obiettivo nutrizionale").font(Glass.display(16, .semibold))
            Spacer()
            Button("Salva", action: save)
                .font(Glass.body(14, .bold)).foregroundStyle(Glass.greenText)
                .frame(width: 60, alignment: .trailing)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.4)
                .accessibilityIdentifier("saveGoal")
        }
        .padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 4)
    }

    private var modePicker: some View {
        HStack(spacing: 8) {
            ForEach(GoalMode.allCases) { m in
                Button { mode = m } label: {
                    Text(m.label)
                        .font(Glass.body(13, mode == m ? .bold : .semibold))
                        .foregroundStyle(mode == m ? Glass.ink : Glass.ink.opacity(0.5))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background { if mode == m { RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.10)) } }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
    }

    @ViewBuilder
    private var contextLine: some View {
        switch mode {
        case .phase_linked:
            if let p = activePhase {
                pill("Fase attiva: «\(p.label)» · base \(Int(maintenance.rounded())) kcal",
                     color: Glass.phaseColor(p.rawValue))
            } else {
                pill("Nessuna scheda con una fase. Impostane una in Schede.", color: Glass.amber)
            }
        case .tdee:
            HStack(spacing: 8) {
                ForEach(ActivityLevel.allCases) { a in
                    Button { activity = a } label: {
                        Text(a.label)
                            .font(Glass.body(12, activity == a ? .bold : .semibold))
                            .foregroundStyle(activity == a ? Glass.onCoral : Glass.ink.opacity(0.55))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(activity == a ? Glass.green : Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            if latestWeight == nil {
                pill("Registra il peso nei Progressi per usare questa modalità.", color: Glass.amber)
            }
        case .manual:
            EmptyView()
        }
    }

    private func targetRow(_ label: String, value: Binding<String>, unit: String,
                           dot: Color?, computed: Double) -> some View {
        HStack {
            HStack(spacing: 10) {
                if let dot { Circle().fill(dot).frame(width: 9, height: 9) }
                Text(label).font(Glass.body(14, .semibold))
            }
            Spacer()
            if mode == .manual {
                HStack(spacing: 6) {
                    if !value.wrappedValue.isEmpty {
                        Button { value.wrappedValue = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15)).foregroundStyle(Glass.ink.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("clear_\(label)")
                    }
                    TextField("", text: value)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(Glass.display(19, .bold)).monospacedDigit()
                        .frame(width: 78)
                        .accessibilityIdentifier("goal_\(label)")
                }
            } else {
                Text("\(Int(computed.rounded()))")
                    .font(Glass.display(19, .bold)).monospacedDigit()
            }
            Text(unit).font(Glass.body(12)).foregroundStyle(Glass.ink.opacity(0.45))
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder((dot ?? .clear).opacity(dot == nil ? 0 : 0.35), lineWidth: 1))
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(Glass.body(12, .semibold)).foregroundStyle(color)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Capsule().fill(color.opacity(0.14)))
            .overlay(Capsule().strokeBorder(color.opacity(0.35)))
    }

    private func breakdown(_ m: Macros) -> String {
        "\(Int((m.proteinG * 4).rounded())) kcal da proteine, "
        + "\(Int((m.carbsG * 4).rounded())) da carboidrati, "
        + "\(Int((m.fatG * 9).rounded())) da grassi"
    }

    private func seed() {
        guard !seeded else { return }
        seeded = true
        guard let g = DietSync.current(goals) else { return }
        mode = g.mode
        activity = g.activityLevel ?? .moderate
        kcal = fmt(g.caloriesTarget); protein = fmt(g.proteinGTarget)
        carbs = fmt(g.carbsGTarget); fat = fmt(g.fatGTarget)
    }

    @MainActor
    private func save() {
        let m = computed
        guard m.kcal > 0 else { return }
        let note: String
        switch mode {
        case .manual: note = "manuale"
        case .phase_linked: note = "fase: \(activePhase?.rawValue ?? "nessuna")"
        case .tdee: note = "tdee \(activity.label.lowercased()) @ \(fmt(latestWeight ?? 0)) kg"
        }
        DietSync.setGoal(mode: mode, macros: m,
                         activity: mode == .tdee ? activity : nil,
                         note: note, in: context)
        dismiss()
    }

    private func num(_ s: String) -> Double { Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private func fmt(_ d: Double) -> String { d == d.rounded() ? String(Int(d)) : String(format: "%.1f", d) }
}
