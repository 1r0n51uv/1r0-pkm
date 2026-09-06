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
    private var waterToday: Double {
        water.filter { cal.isDateInToday($0.loggedAt) }.reduce(0) { $0 + $1.amountMl }
    }
    private var caffeineToday: Double {
        caffeine.filter { cal.isDateInToday($0.loggedAt) }.reduce(0) { $0 + $1.caffeineMg }
    }
    private var activeSupps: [Supplement] { supplements.filter(\.active) }
    private func takenToday(_ s: Supplement) -> Bool {
        suppLogs.contains { $0.supplementId == s.id && $0.taken && cal.isDateInToday($0.loggedAt) }
    }
    private var takenCount: Int { activeSupps.filter { takenToday($0) }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: "Tracker")

            // acqua
            VStack(spacing: 8) {
                HStack {
                    Label("Acqua", systemImage: "drop.fill")
                        .font(Glass.body(13, .semibold)).foregroundStyle(Glass.ink.opacity(0.75))
                    Spacer()
                    Text(waterTargetMl.map { "\(Int(waterToday)) / \(Int($0)) ml" }
                         ?? "\(Int(waterToday)) ml")
                        .font(Glass.body(13)).monospacedDigit().foregroundStyle(Glass.ink.opacity(0.5))
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
                HStack(spacing: 8) {
                    quickAdd("+250 ml", id: "water250") { DietSync.addWater(ml: 250, in: context) }
                    quickAdd("+500 ml", id: "water500") { DietSync.addWater(ml: 500, in: context) }
                }
            }

            Divider().overlay(Glass.hairlineSoft)

            // caffeina
            VStack(spacing: 8) {
                HStack {
                    Label("Caffeina", systemImage: "cup.and.saucer.fill")
                        .font(Glass.body(13, .semibold)).foregroundStyle(Glass.ink.opacity(0.75))
                    Spacer()
                    Text("\(Int(caffeineToday)) mg oggi")
                        .font(Glass.body(13)).monospacedDigit().foregroundStyle(Glass.ink.opacity(0.5))
                }
                HStack(spacing: 8) {
                    quickAdd("Espresso +80", id: "caff80") {
                        DietSync.addCaffeine(mg: 80, source: "Espresso", in: context)
                    }
                    quickAdd("Filtro +120", id: "caff120") {
                        DietSync.addCaffeine(mg: 120, source: "Caffè filtro", in: context)
                    }
                }
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

    @MainActor
    private func quickAdd(_ title: String, id: String, _ action: @escaping @MainActor () -> Void) -> some View {
        Button { action() } label: {
            Text(title)
                .font(Glass.body(12, .bold)).foregroundStyle(Glass.amberText)
                .frame(maxWidth: .infinity).frame(height: 38)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Glass.amber.opacity(0.35)))
        }
        .buttonStyle(.plain)
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
