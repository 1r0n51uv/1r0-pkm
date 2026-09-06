//
//  LogFoodView.swift
//  1r0-pkm · Modules/1r0-diet
//
//  Sheet "Aggiungi alimento": scegli lo slot, cerca un alimento (cache
//  locale + OpenFoodFacts/USDA via backend, ADR-0018), o scansiona il
//  barcode, o creane uno custom; imposta i grammi con anteprima macro live,
//  logga (ADR-0017). Layout dai mockup "GlassFoodSearch" + "GlassMealLog" —
//  accento ambra.
//

import SwiftUI
import SwiftData

struct LogFoodView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Food.name) private var foods: [Food]

    @State var slot: MealSlot
    @State private var search = ""
    @State private var picked: Food?
    @State private var grams: Double = 100

    @State private var remote: [FoodCandidate] = []
    @State private var searching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var showScanner = false
    @State private var note: String?

    private var query: String { search.lowercased().trimmingCharacters(in: .whitespaces) }

    /// Cache locale filtrata (istantanea).
    private var localHits: [Food] {
        guard !query.isEmpty else { return foods }
        return foods.filter { $0.name.lowercased().contains(query) }
    }

    /// Candidati remoti che non duplicano un risultato locale (per nome).
    private var remoteHits: [FoodCandidate] {
        let localNames = Set(localHits.map { $0.name.lowercased() })
        return remote.filter { !localNames.contains($0.name.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let f = picked { composeCard(f) }

                        slotPicker
                        GlassField(placeholder: "Cerca un alimento…", text: $search,
                                   identifier: "foodSearch")
                        scanButton

                        if let note {
                            Text(note).font(Glass.body(12)).foregroundStyle(Glass.amberText)
                        }

                        results

                        NavigationLink {
                            AddFoodView { newFood in
                                picked = newFood
                                grams = newFood.servingSizeG ?? 100
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                Text("Crea alimento personalizzato")
                            }
                            .font(Glass.body(14, .semibold)).foregroundStyle(Glass.ink.opacity(0.65))
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.04)))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("createFood")
                        .padding(.bottom, 12)
                    }
                    .padding(.horizontal, 22).padding(.top, 4)
                }
                .scrollIndicators(.hidden)
            }
            .glassScreen(.warm)
            .toolbar(.hidden, for: .navigationBar)
        }
        .onChange(of: search) { _, _ in scheduleSearch() }
        .sheet(isPresented: $showScanner) {
            BarcodeScannerView { code in
                Task { await handleBarcode(code) }
            }
            .presentationDetents([.large])
        }
    }

    // MARK: header / controls

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Glass.ink.opacity(0.75))
                    .frame(width: 44, height: 44, alignment: .leading)
            }
            Spacer()
            Text("Aggiungi alimento").font(Glass.display(16, .semibold))
            Spacer()
            Text(slot.label).font(Glass.body(13, .semibold)).foregroundStyle(Glass.ink.opacity(0.5))
                .frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 4)
    }

    private var scanButton: some View {
        Button { showScanner = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "barcode.viewfinder")
                Text("Scansiona codice a barre")
            }
            .font(Glass.body(15, .bold)).foregroundStyle(Glass.amberText)
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Glass.amber.opacity(0.4)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("scanBarcode")
    }

    private var slotPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MealSlot.allCases) { s in
                    GlassChip(label: s.label, selected: slot == s, tint: Glass.amber) { slot = s }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: results

    @ViewBuilder
    private var results: some View {
        if localHits.isEmpty && remoteHits.isEmpty && !searching {
            Text(query.isEmpty
                 ? (foods.isEmpty ? "Nessun alimento salvato. Cerca o scansiona." : "")
                 : "Nessun risultato per “\(search)”.")
                .font(Glass.body(13)).foregroundStyle(Glass.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        } else {
            VStack(spacing: 10) {
                ForEach(localHits) { foodRow($0) }
                if !remoteHits.isEmpty {
                    Text("DA OPENFOODFACTS / USDA")
                        .font(Glass.body(10, .bold)).tracking(0.6)
                        .foregroundStyle(Glass.ink.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                    ForEach(remoteHits) { candidateRow($0) }
                }
                if searching {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Cerco online…").font(Glass.body(12)).foregroundStyle(Glass.ink.opacity(0.5))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func foodRow(_ f: Food) -> some View {
        row(name: f.name, sub: "\(kcal(f.caloriesPer100g)) kcal / 100 g · \(sourceLabel(f.source))",
            selected: picked?.id == f.id) {
            picked = f
            grams = f.servingSizeG ?? 100
        }
    }

    private func candidateRow(_ c: FoodCandidate) -> some View {
        row(name: c.name, sub: "\(kcal(c.caloriesPer100g)) kcal / 100 g · \(sourceLabel(c.source))",
            selected: false) {
            let f = DietSync.materialize(c, in: context)
            picked = f
            grams = c.servingSizeG ?? 100
            note = nil
        }
    }

    private func row(name: String, sub: String, selected: Bool,
                     _ action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                foodTile(40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(Glass.body(14, .semibold)).lineLimit(1)
                    Text(sub).font(Glass.body(12)).foregroundStyle(Glass.ink.opacity(0.45)).lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: selected ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(selected ? Glass.amber : Glass.ink.opacity(0.35))
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(selected ? Glass.amber.opacity(0.5) : Color.white.opacity(0.12),
                              lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: compose

    private func composeCard(_ f: Food) -> some View {
        let mac = f.macros(forGrams: grams)
        return VStack(spacing: 16) {
            HStack {
                foodTile(40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(f.name).font(Glass.display(16, .semibold)).lineLimit(1)
                    Text("\(kcal(f.caloriesPer100g)) kcal / 100 g")
                        .font(Glass.body(12)).foregroundStyle(Glass.ink.opacity(0.45))
                }
                Spacer()
                Button("Cambia") { picked = nil }
                    .font(Glass.body(12, .semibold)).foregroundStyle(Glass.ink.opacity(0.5))
            }
            HStack(spacing: 10) {
                stepBtn("minus") { grams = max(5, grams - 10) }
                Text("\(Int(grams)) g")
                    .font(Glass.display(22, .bold)).monospacedDigit()
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("grams")
                stepBtn("plus") { grams += 10 }
            }
            .padding(6)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            HStack {
                macroStat("\(Int(mac.kcal.rounded()))", "kcal")
                macroStat("\(Int(mac.proteinG.rounded()))g", "proteine")
                macroStat("\(Int(mac.carbsG.rounded()))g", "carbo")
                macroStat("\(Int(mac.fatG.rounded()))g", "grassi")
            }
            GlassPrimaryButton(title: "Aggiungi al pasto", systemImage: "checkmark",
                               fill: Glass.amber, onInk: Color(red: 0.12, green: 0.06, blue: 0)) {
                DietSync.logMeal(slot: slot, items: [(f, grams)], in: context)
                dismiss()
            }
            .accessibilityIdentifier("addToMeal")
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Glass.amber.opacity(0.35)))
    }

    private func foodTile(_ size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
            .fill(LinearGradient(colors: [Glass.amber.opacity(0.85), Glass.amber.opacity(0.4)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay(Image(systemName: "fork.knife")
                .font(.system(size: size * 0.4, weight: .bold)).foregroundStyle(.white))
    }

    private func stepBtn(_ name: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 13, weight: .bold)).foregroundStyle(Glass.ink)
                .frame(width: 44, height: 40)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func macroStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Glass.display(16, .bold)).monospacedDigit()
            Text(label).font(Glass.body(11)).foregroundStyle(Glass.ink.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: actions

    private func scheduleSearch() {
        searchTask?.cancel()
        let q = query
        guard q.count >= 2 else { remote = []; searching = false; return }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            if Task.isCancelled { return }
            await MainActor.run { searching = true }
            let hits = await DietSync.searchRemote(q)
            if Task.isCancelled { return }
            await MainActor.run { remote = hits; searching = false }
        }
    }

    @MainActor
    private func handleBarcode(_ code: String) async {
        note = "Cerco il codice…"
        if let cand = await DietSync.lookupBarcode(code) {
            let f = DietSync.materialize(cand, in: context)
            picked = f
            grams = cand.servingSizeG ?? 100
            note = nil
        } else {
            note = "Nessun alimento per questo codice. Prova la ricerca o crealo a mano."
        }
    }

    private func kcal(_ v: Double) -> String { "\(Int(v.rounded()))" }

    private func sourceLabel(_ s: String) -> String {
        switch s {
        case "openfoodfacts": return "OpenFoodFacts"
        case "usda": return "USDA"
        default: return "Creato da te"
        }
    }
}
