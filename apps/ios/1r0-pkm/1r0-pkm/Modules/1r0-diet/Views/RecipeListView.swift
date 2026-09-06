//
//  RecipeListView.swift
//  1r0-pkm · Modules/1r0-diet
//
//  Elenco delle ricette (pasti riutilizzabili, ADR-0017 slice 2) + creazione
//  / modifica. Stile Glass Dark (ADR-0023), accento ambra.
//

import SwiftUI
import SwiftData

struct RecipeListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Recipe.updatedAt, order: .reverse) private var recipes: [Recipe]
    @Query private var foods: [Food]

    @State private var showAdd = false
    @State private var editing: Recipe?

    private var foodMap: [UUID: Food] { Dictionary(foods.map { ($0.id, $0) }) { a, _ in a } }

    var body: some View {
        VStack(spacing: 0) {
            header
            if recipes.isEmpty {
                Spacer()
                GlassEmptyState(systemImage: "book.closed",
                                title: "Nessuna ricetta",
                                message: "Salva un pasto ricorrente per richiamarlo al volo quando logghi o pianifichi.") {
                    GlassPrimaryButton(title: "Nuova ricetta", systemImage: "plus",
                                       fill: Glass.amber,
                                       onInk: Color(red: 0.12, green: 0.06, blue: 0)) { showAdd = true }
                        .accessibilityIdentifier("addRecipe")
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(recipes) { r in row(r) }
                    }
                    .padding(.horizontal, 22).padding(.top, 6).padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
        }
        .glassScreen(.warm)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAdd) {
            AddRecipeView().presentationDetents([.large])
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(item: $editing) { r in
            AddRecipeView(recipe: r).presentationDetents([.large])
                .presentationBackground(.ultraThinMaterial)
        }
        .task { await DietSync.pullRecipes(into: context) }
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
            Text("Ricette").font(Glass.display(16, .semibold))
            Spacer()
            GlassIconButton(systemName: "plus", tint: Glass.amber) { showAdd = true }
                .accessibilityIdentifier("addRecipe")
        }
        .padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 4)
    }

    private func row(_ r: Recipe) -> some View {
        let mac = r.totals(foods: foodMap)
        return Button { editing = r } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [Glass.amber.opacity(0.85), Glass.amber.opacity(0.4)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                    .overlay(Image(systemName: "book.closed.fill")
                        .font(.system(size: 17, weight: .bold)).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 3) {
                    Text(r.name).font(Glass.body(15, .semibold)).lineLimit(1)
                    Text("\(r.items.count) alimenti · \(Int(mac.kcal.rounded())) kcal")
                        .font(Glass.body(12)).foregroundStyle(Glass.ink.opacity(0.45))
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Glass.ink.opacity(0.3))
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .glassRow(corner: 18)
        }
        .buttonStyle(.plain)
    }
}

struct AddRecipeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var recipe: Recipe?
    @State private var name = ""
    @State private var notes = ""
    @State private var basket: [BasketItem] = []
    @State private var seeded = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !basket.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Annulla") { dismiss() }
                    .font(Glass.body(14)).foregroundStyle(Glass.ink.opacity(0.6))
                Spacer()
                Text(recipe == nil ? "Nuova ricetta" : "Modifica ricetta")
                    .font(Glass.display(16, .semibold))
                Spacer()
                Button("Salva") { save() }
                    .font(Glass.body(14, .bold))
                    .foregroundStyle(canSave ? Glass.amberText : Glass.ink.opacity(0.3))
                    .disabled(!canSave)
                    .accessibilityIdentifier("saveRecipe")
            }
            .padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    plainField("Nome della ricetta", text: $name, id: "recipeName")
                    plainField("Note (facoltative)", text: $notes, id: "recipeNotes")
                    SectionLabel(text: "Alimenti")
                    FoodBasketEditor(items: $basket)
                }
                .padding(.horizontal, 22).padding(.top, 4).padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .glassScreen(.warm)
        .onAppear {
            guard !seeded, let r = recipe else { seeded = true; return }
            name = r.name
            notes = r.notes ?? ""
            let byId = r.items.sorted { $0.orderIndex < $1.orderIndex }
            basket = byId.compactMap { it in
                guard let fid = it.foodId,
                      let f = try? context.fetch(
                        FetchDescriptor<Food>(predicate: #Predicate { $0.id == fid })).first
                else { return nil }
                return BasketItem(food: f, grams: it.quantityG)
            }
            seeded = true
        }
    }

    private func plainField(_ placeholder: String, text: Binding<String>, id: String) -> some View {
        TextField("", text: text,
                  prompt: Text(placeholder).foregroundColor(Glass.ink.opacity(0.42)))
            .font(Glass.body(15))
            .padding(.horizontal, 16).frame(height: 50)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.06)))
            .accessibilityIdentifier(id)
    }

    @MainActor
    private func save() {
        guard canSave else { return }
        DietSync.saveRecipe(
            name: name.trimmingCharacters(in: .whitespaces),
            notes: notes.trimmingCharacters(in: .whitespaces).isEmpty ? nil
                : notes.trimmingCharacters(in: .whitespaces),
            items: basket.map { (food: $0.food, grams: $0.grams) },
            existing: recipe,
            in: context
        )
        dismiss()
    }
}
