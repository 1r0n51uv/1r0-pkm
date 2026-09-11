//
//  FoodBasketEditor.swift
//  1r0-pkm · Modules/1r0-diet
//
//  Editor riusabile di un "paniere" di alimenti con quantità: usato per
//  comporre una Ricetta (ADR-0017 slice 2) e per pianificare un pasto.
//  Ricerca cache locale + OpenFoodFacts/USDA (ADR-0018), grammi con stepper.
//

import SwiftUI
import SwiftData

/// Una voce del paniere in composizione (transitoria, non SwiftData).
struct BasketItem: Identifiable {
    let id = UUID()
    var food: Food
    var grams: Double
}

struct FoodBasketEditor: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Food.name) private var foods: [Food]
    @Binding var items: [BasketItem]

    @State private var search = ""
    @State private var remote: [FoodCandidate] = []
    @State private var searching = false
    @State private var searchTask: Task<Void, Never>?

    private var query: String { search.lowercased().trimmingCharacters(in: .whitespaces) }
    private var localHits: [Food] {
        let inBasket = Set(items.map(\.food.id))
        let base = query.isEmpty ? foods : foods.filter { $0.name.lowercased().contains(query) }
        return base.filter { !inBasket.contains($0.id) }.prefix(8).map { $0 }
    }
    private var remoteHits: [FoodCandidate] {
        let names = Set(localHits.map { $0.name.lowercased() })
        return remote.filter { !names.contains($0.name.lowercased()) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !items.isEmpty {
                VStack(spacing: 8) {
                    ForEach($items) { $it in basketRow($it) }
                }
            }

            GlassField(placeholder: "Aggiungi un alimento…", text: $search,
                       identifier: "basketSearch")
                .onChange(of: search) { _, _ in scheduleSearch() }

            if !localHits.isEmpty || !remoteHits.isEmpty || searching {
                VStack(spacing: 8) {
                    ForEach(localHits) { f in
                        addRow(name: f.name,
                               sub: "\(Int(f.caloriesPer100g.rounded())) kcal / 100 g") {
                            append(f, grams: f.servingSizeG ?? 100)
                        }
                    }
                    ForEach(remoteHits) { c in
                        addRow(name: c.name,
                               sub: "\(Int(c.caloriesPer100g.rounded())) kcal / 100 g · online") {
                            let f = DietSync.materialize(c, in: context)
                            append(f, grams: c.servingSizeG ?? 100)
                        }
                    }
                    if searching {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Cerco online…").font(Glass.body(12))
                                .foregroundStyle(Glass.ink.opacity(0.5))
                        }
                    }
                }
            }
        }
    }

    private func basketRow(_ it: Binding<BasketItem>) -> some View {
        HStack(spacing: 12) {
            Text(it.wrappedValue.food.name)
                .font(Glass.body(14, .semibold)).lineLimit(1)
            Spacer(minLength: 4)
            Button {
                it.wrappedValue.grams = max(5, it.wrappedValue.grams - 10)
            } label: { Image(systemName: "minus") }
                .buttonStyle(.plain).foregroundStyle(Glass.ink.opacity(0.6))
            Text("\(Int(it.wrappedValue.grams)) g")
                .font(Glass.body(13, .bold)).monospacedDigit().frame(minWidth: 44)
            Button {
                it.wrappedValue.grams += 10
            } label: { Image(systemName: "plus") }
                .buttonStyle(.plain).foregroundStyle(Glass.ink.opacity(0.6))
            Button {
                items.removeAll { $0.id == it.wrappedValue.id }
            } label: { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.plain).foregroundStyle(Glass.ink.opacity(0.35))
                .accessibilityIdentifier("removeBasketItem_\(it.wrappedValue.food.name)")
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.06)))
    }

    private func addRow(name: String, sub: String, _ action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18)).foregroundStyle(Glass.amber)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(Glass.body(14, .semibold)).lineLimit(1)
                    Text(sub).font(Glass.body(11)).foregroundStyle(Glass.ink.opacity(0.45)).lineLimit(1)
                }
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.03)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.10)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("basketAdd")
    }

    private func append(_ f: Food, grams: Double) {
        items.append(BasketItem(food: f, grams: grams))
        search = ""
        remote = []
    }

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
}
