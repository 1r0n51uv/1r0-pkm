//
//  TrackersView.swift
//  1r0-pkm · Modules/1r0-diet
//
//  Tracker semplici sul cruscotto Dieta (ADR-0017 slice 4): acqua,
//  caffeina, checklist integratori. Card compatta con quick-add; la
//  gestione degli integratori sta in un foglio a parte. Accento ambra.
//

import SwiftUI
import SwiftData

struct TrackersCard: View {
    @Environment(\.modelContext) private var context
    @Query private var water: [WaterLog]
    @Query private var caffeine: [CaffeineLog]
    @Query(sort: \Supplement.createdAt) private var supplements: [Supplement]
    @Query private var suppLogs: [SupplementLog]

    /// obiettivo acqua (ml) dall'obiettivo nutrizionale corrente, se impostato.
    var waterTargetMl: Double?

    @State private var showManage = false

    private let cal = Calendar.current
    /// Voci di oggi, più recente prima — per poterle rimuovere una per una
    /// (ADR-0036), non solo vedere il totale cumulativo.
    private var waterEntriesToday: [WaterLog] {
        water.filter { cal.isDateInToday($0.loggedAt) }.sorted { $0.loggedAt > $1.loggedAt }
    }
    private var caffeineEntriesToday: [CaffeineLog] {
        caffeine.filter { cal.isDateInToday($0.loggedAt) }.sorted { $0.loggedAt > $1.loggedAt }
    }
    private var waterToday: Double { waterEntriesToday.reduce(0) { $0 + $1.amountMl } }
    private var caffeineToday: Double { caffeineEntriesToday.reduce(0) { $0 + $1.caffeineMg } }
    private var activeSupps: [Supplement] { supplements.filter(\.active) }
    private func takenToday(_ s: Supplement) -> Bool {
        suppLogs.contains { $0.supplementId == s.id && $0.taken && cal.isDateInToday($0.loggedAt) }
    }
    private var takenCount: Int { activeSupps.filter { takenToday($0) }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: "Tracker")

            // acqua — contatore centrale con - / + (ADR-0037): "-" annulla
            // l'ultima voce aggiunta oggi (non un decremento arbitrario),
            // "+" ne aggiunge una da 250 ml.
            VStack(spacing: 10) {
                HStack {
                    Label("Acqua", systemImage: "drop.fill")
                        .font(Glass.body(13, .semibold)).foregroundStyle(Glass.ink.opacity(0.75))
                    Spacer()
                    if let t = waterTargetMl, t > 0 {
                        Text(verbatim: "obiettivo \(Int(t)) ml")
                            .font(Glass.body(12)).foregroundStyle(Glass.ink.opacity(0.4))
                    }
                }
                if let t = waterTargetMl, t > 0 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.09))
                            Capsule().fill(Glass.blue)
                                .frame(width: geo.size.width * CGFloat(min(1, waterToday / t)))
                        }
                    }
                    .frame(height: 7)
                }
                counterRow(value: "\(Int(waterToday)) ml", tint: Glass.blue,
                          minusId: "waterMinus", plusId: "water250",
                          canRemove: !waterEntriesToday.isEmpty,
                          onMinus: { if let last = waterEntriesToday.first { DietSync.deleteWaterLog(last, in: context) } },
                          onPlus: { DietSync.addWater(ml: 250, in: context) })
            }

            Divider().overlay(Glass.hairlineSoft)

            // caffeina — stesso contatore centrale, "+" aggiunge un espresso (80 mg).
            VStack(spacing: 10) {
                HStack {
                    Label("Caffeina", systemImage: "cup.and.saucer.fill")
                        .font(Glass.body(13, .semibold)).foregroundStyle(Glass.ink.opacity(0.75))
                    Spacer()
                }
                counterRow(value: "\(Int(caffeineToday)) mg oggi", tint: Glass.amber,
                          minusId: "caffMinus", plusId: "caff80",
                          canRemove: !caffeineEntriesToday.isEmpty,
                          onMinus: { if let last = caffeineEntriesToday.first { DietSync.deleteCaffeineLog(last, in: context) } },
                          onPlus: { DietSync.addCaffeine(mg: 80, source: "Espresso", in: context) })
            }

            Divider().overlay(Glass.hairlineSoft)

            // integratori
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Integratori", systemImage: "pills.fill")
                        .font(Glass.body(13, .semibold)).foregroundStyle(Glass.ink.opacity(0.75))
                    Spacer()
                    Text(activeSupps.isEmpty ? "—" : "\(takenCount)/\(activeSupps.count) presi")
                        .font(Glass.body(13)).foregroundStyle(Glass.ink.opacity(0.5))
                    Button { showManage = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Glass.ink.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("manageSupplements")
                }
                if activeSupps.isEmpty {
                    Text("Nessun integratore. Aggiungline uno per la checklist giornaliera.")
                        .font(Glass.body(12)).foregroundStyle(Glass.ink.opacity(0.4))
                } else {
                    ForEach(activeSupps) { s in
                        let taken = takenToday(s)
                        Button {
                            DietSync.setSupplementTaken(s, taken: !taken, logs: suppLogs, in: context)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: taken ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(taken ? Glass.green : Glass.ink.opacity(0.35))
                                Text(s.name)
                                    .font(Glass.body(13))
                                    .foregroundStyle(Glass.ink.opacity(taken ? 0.5 : 0.85))
                                    .strikethrough(taken)
                                if let d = s.doseText, !d.isEmpty {
                                    Text(d).font(Glass.body(11)).foregroundStyle(Glass.ink.opacity(0.35))
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("supp_\(s.name)")
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(corner: 24)
        .sheet(isPresented: $showManage) {
            ManageSupplementsView()
                .presentationDetents([.medium, .large])
                .presentationBackground(.ultraThinMaterial)
        }
        .task {
            await DietSync.pullWaterLogs(into: context)
            await DietSync.pullCaffeineLogs(into: context)
            await DietSync.pullSupplements(into: context)
            await DietSync.pullSupplementLogs(into: context)
        }
    }

    /// Contatore centrale acqua/caffeina (ADR-0037): "-" a sinistra annulla
    /// l'ultima voce di oggi (non un decremento arbitrario — non sappiamo
    /// "di quanto" senza chiederlo), "+" a destra ne aggiunge una
    /// dell'importo di default. Sostituisce i vecchi pulsanti multipli
    /// (+250/+500 ml, Espresso/Filtro) + l'elenco voci separato.
    @MainActor
    private func counterRow(value: String, tint: Color, minusId: String, plusId: String,
                            canRemove: Bool, onMinus: @escaping @MainActor () -> Void,
                            onPlus: @escaping @MainActor () -> Void) -> some View {
        HStack {
            stepButton("minus", id: minusId, tint: tint, enabled: canRemove, action: onMinus)
            Spacer(minLength: 8)
            Text(verbatim: value)
                .font(Glass.display(20, .bold)).monospacedDigit()
                .foregroundStyle(Glass.textPrimary)
            Spacer(minLength: 8)
            stepButton("plus", id: plusId, tint: tint, enabled: true, action: onPlus)
        }
    }

    @MainActor
    private func stepButton(_ systemImage: String, id: String, tint: Color, enabled: Bool,
                            action: @escaping @MainActor () -> Void) -> some View {
        Button { action() } label: {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(enabled ? tint : Glass.ink.opacity(0.2))
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.white.opacity(0.06)))
                .overlay(Circle().strokeBorder(tint.opacity(enabled ? 0.35 : 0.1)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityIdentifier(id)
    }
}

struct ManageSupplementsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Supplement.createdAt) private var supplements: [Supplement]

    @State private var name = ""
    @State private var dose = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Integratori").font(Glass.display(16, .semibold))
                Spacer()
                Button("Fine") { dismiss() }
                    .font(Glass.body(14, .semibold)).foregroundStyle(Glass.amberText)
            }
            .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        TextField("", text: $name,
                                  prompt: Text("Nome").foregroundColor(Glass.ink.opacity(0.42)))
                            .font(Glass.body(15)).padding(.horizontal, 14).frame(height: 46)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.06)))
                            .accessibilityIdentifier("supplementName")
                        TextField("", text: $dose,
                                  prompt: Text("Dose").foregroundColor(Glass.ink.opacity(0.42)))
                            .font(Glass.body(15)).padding(.horizontal, 14).frame(height: 46)
                            .frame(width: 96)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.06)))
                            .accessibilityIdentifier("supplementDose")
                        Button {
                            let n = name.trimmingCharacters(in: .whitespaces)
                            guard !n.isEmpty else { return }
                            DietSync.addSupplement(name: n,
                                dose: dose.trimmingCharacters(in: .whitespaces).isEmpty ? nil
                                    : dose.trimmingCharacters(in: .whitespaces), in: context)
                            name = ""; dose = ""
                        } label: {
                            Image(systemName: "plus").font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color(red: 0.12, green: 0.06, blue: 0))
                                .frame(width: 46, height: 46)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Glass.amber))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("addSupplement")
                    }

                    ForEach(supplements) { s in
                        HStack(spacing: 10) {
                            Image(systemName: "pills.fill").foregroundStyle(Glass.amber.opacity(0.8))
                            Text(s.name).font(Glass.body(14, .semibold))
                            if let d = s.doseText, !d.isEmpty {
                                Text(d).font(Glass.body(12)).foregroundStyle(Glass.ink.opacity(0.4))
                            }
                            Spacer(minLength: 4)
                            Button {
                                DietSync.deleteSupplement(s, in: context)
                            } label: {
                                Image(systemName: "trash").font(.system(size: 13))
                                    .foregroundStyle(Glass.ink.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .glassRow(corner: 14)
                    }
                }
                .padding(.horizontal, 22).padding(.top, 4).padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .glassScreen(.warm)
        .task { await DietSync.pullSupplements(into: context) }
    }
}
