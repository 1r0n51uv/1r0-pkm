//
//  MealPlanView.swift
//  1r0-pkm · Modules/1r0-diet
//
//  `PlanMealSheet` (ADR-0017 slice 2, edit ADR-0032): pianifica o modifica
//  un pasto per un giorno/slot — ricetta rapida o paniere di alimenti. La
//  vista "Pianificazione" che la usava è stata assorbita da `DietTabView`
//  (ADR-0036, redesign: niente più due pagine quasi identiche per "oggi" e
//  "pianifica" — la striscia giorni + i 5 slot vivono lì).
//

import SwiftUI
import SwiftData

/// Foglio "pianifica un pasto": ricetta rapida o paniere di alimenti. Con
/// `existing` passato, modifica quel pasto pianificato (ADR-0032) invece di
/// crearne uno nuovo — paniere pre-riempito, si può rimuovere un alimento
/// aggiunto per errore (già supportato da `FoodBasketEditor`).
struct PlanMealSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Recipe.updatedAt, order: .reverse) private var recipes: [Recipe]
    @Query private var allFoods: [Food]

    let day: Date
    @State var slot: MealSlot
    var existing: PlannedMeal? = nil
    @State private var basket: [BasketItem] = []
    @State private var pickedRecipe: Recipe?

    private var canSave: Bool { !basket.isEmpty }
    private var isEditing: Bool { existing != nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Annulla") { dismiss() }
                    .font(Glass.body(14)).foregroundStyle(Glass.ink.opacity(0.6))
                Spacer()
                Text(isEditing ? "Modifica pasto" : "Pianifica").font(Glass.display(16, .semibold))
                Spacer()
                Button(isEditing ? "Salva" : "Aggiungi") { save() }
                    .font(Glass.body(14, .bold))
                    .foregroundStyle(canSave ? Glass.amberText : Glass.ink.opacity(0.3))
                    .disabled(!canSave)
                    .accessibilityIdentifier("savePlannedMeal")
            }
            .padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized)
                        .font(Glass.body(13)).foregroundStyle(Glass.ink.opacity(0.5))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(MealSlot.allCases) { s in
                                GlassChip(label: s.label, selected: slot == s, tint: Glass.amber) { slot = s }
                            }
                        }
                    }

                    if !recipes.isEmpty {
                        SectionLabel(text: "Da una ricetta")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(recipes) { r in
                                    GlassChip(label: r.name, selected: pickedRecipe?.id == r.id,
                                              tint: Glass.amber) { applyRecipe(r) }
                                }
                            }
                        }
                    }

                    SectionLabel(text: "Alimenti")
                    FoodBasketEditor(items: $basket)
                }
                .padding(.horizontal, 22).padding(.top, 4).padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .glassScreen(.warm)
        .onAppear { populateIfEditing() }
    }

    @MainActor
    private func populateIfEditing() {
        guard let existing, basket.isEmpty else { return }
        if let rid = existing.recipeId {
            pickedRecipe = recipes.first { $0.id == rid }
        }
        let foodMap = Dictionary(allFoods.map { ($0.id, $0) }) { a, _ in a }
        basket = existing.items
            .sorted { $0.orderIndex < $1.orderIndex }
            .compactMap { it in
                guard let fid = it.foodId, let f = foodMap[fid] else { return nil }
                return BasketItem(food: f, grams: it.quantityG)
            }
    }

    @MainActor
    private func applyRecipe(_ r: Recipe) {
        pickedRecipe = (pickedRecipe?.id == r.id) ? nil : r
        guard let picked = pickedRecipe else { basket = []; return }
        basket = picked.items
            .sorted { $0.orderIndex < $1.orderIndex }
            .compactMap { it in
                guard let fid = it.foodId,
                      let f = try? context.fetch(
                        FetchDescriptor<Food>(predicate: #Predicate { $0.id == fid })).first
                else { return nil }
                return BasketItem(food: f, grams: it.quantityG)
            }
    }

    @MainActor
    private func save() {
        guard canSave else { return }
        let items = basket.map { (food: $0.food, grams: $0.grams) }
        if let existing {
            DietSync.updatePlannedMeal(existing, slot: slot, recipe: pickedRecipe, items: items, in: context)
        } else {
            DietSync.planMeal(date: day, slot: slot, recipe: pickedRecipe, items: items, in: context)
        }
        dismiss()
    }
}
