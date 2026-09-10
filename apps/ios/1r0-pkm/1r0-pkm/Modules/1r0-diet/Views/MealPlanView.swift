//
//  MealPlanView.swift
//  1r0-pkm · Modules/1r0-diet
//
//  Pianificazione pasti (ADR-0017 slice 2): striscia dei prossimi 7 giorni,
//  slot per giorno, ogni pasto pianificato si conferma ("Mangiato" → crea un
//  MealEntry) o si salta. Le ricette si compongono a parte (RecipeListView).
//  Stile Glass Dark (ADR-0023), accento ambra.
//

import SwiftUI
import SwiftData

struct MealPlanView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \PlannedMeal.plannedDate) private var planned: [PlannedMeal]
    @Query private var foods: [Food]

    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var composeSlot: MealSlot?
    @State private var showRecipes = false
    @State private var showShopping = false

    private var foodMap: [UUID: Food] { Dictionary(foods.map { ($0.id, $0) }) { a, _ in a } }
    private let cal = Calendar.current

    private var week: [Date] {
        (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: cal.startOfDay(for: .now)) }
    }
    private func meals(_ slot: MealSlot) -> [PlannedMeal] {
        planned.filter {
            cal.isDate($0.plannedDate, inSameDayAs: selectedDay) && $0.mealSlot == slot
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                dayStrip
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(MealSlot.allCases) { slot in slotCard(slot) }
                    }
                    .padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
            .glassScreen(.warm)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showRecipes) { RecipeListView() }
            .navigationDestination(isPresented: $showShopping) { ShoppingListView() }
            .sheet(item: $composeSlot) { slot in
                PlanMealSheet(day: selectedDay, slot: slot)
                    .presentationDetents([.large])
                    .presentationBackground(.ultraThinMaterial)
            }
            .task {
                await DietSync.pullRecipes(into: context)
                // finestra allargata di ±1 giorno: la GET usa date UTC, la UI
                // filtra poi per giorno locale (`isDate(_:inSameDayAs:)`).
                let from = cal.date(byAdding: .day, value: -1, to: week[0]) ?? week[0]
                let to = cal.date(byAdding: .day, value: 8, to: week[0]) ?? week[0]
                await DietSync.pullPlannedMeals(from: from, to: to, into: context)
                await Outbox.flushOutbox(context)
            }
        }
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
            Text("Pianificazione").font(Glass.display(16, .semibold))
            Spacer()
            GlassIconButton(systemName: "cart") { showShopping = true }
                .accessibilityIdentifier("openShopping")
            GlassIconButton(systemName: "book.closed") { showRecipes = true }
                .accessibilityIdentifier("openRecipes")
        }
        .padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 4)
    }

    private var dayStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(week, id: \.self) { d in
                    let sel = cal.isDate(d, inSameDayAs: selectedDay)
                    Button { selectedDay = d } label: {
                        VStack(spacing: 4) {
                            Text(d.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                                .font(Glass.body(10, .bold)).tracking(0.5)
                            Text(d.formatted(.dateTime.day()))
                                .font(Glass.display(17, .bold)).monospacedDigit()
                        }
                        .foregroundStyle(sel ? Color(red: 0.12, green: 0.06, blue: 0) : Glass.ink.opacity(0.6))
                        .frame(width: 46, height: 58)
                        .background {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(sel ? Glass.amber : Color.white.opacity(0.05))
                        }
                        .overlay {
                            if !sel {
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.10))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22)
        }
    }

    private func slotCard(_ slot: MealSlot) -> some View {
        let list = meals(slot)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: slot.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(list.isEmpty ? Glass.ink.opacity(0.35) : Glass.amber)
                Text(slot.label).font(Glass.display(15, .semibold))
                Spacer()
                Button {
                    composeSlot = slot
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Glass.ink.opacity(0.55))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("plan_\(slot.rawValue)")
            }

            if list.isEmpty {
                Text("Niente in programma")
                    .font(Glass.body(12)).foregroundStyle(Glass.ink.opacity(0.35))
            } else {
                ForEach(list) { p in plannedRow(p) }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassRow(corner: 20)
    }

    private func plannedRow(_ p: PlannedMeal) -> some View {
        let mac = p.totals(foods: foodMap)
        let title = p.items.first.map { first -> String in
            p.items.count > 1 ? "\(first.foodName) +\(p.items.count - 1)" : first.foodName
        } ?? "Pasto"
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title).font(Glass.body(14, .semibold)).lineLimit(1)
                Spacer(minLength: 4)
                statusPill(p.status)
            }
            HStack(spacing: 10) {
                Text("\(Int(mac.kcal.rounded())) kcal")
                    .font(Glass.body(12)).foregroundStyle(Glass.ink.opacity(0.5))
                Spacer()
                if p.status == .planned {
                    Button("Salta") {
                        Task { @MainActor in DietSync.skipPlannedMeal(p, in: context) }
                    }
                    .font(Glass.body(12, .semibold)).foregroundStyle(Glass.ink.opacity(0.55))
                    .accessibilityIdentifier("skipPlanned")
                    Button("Mangiato") {
                        Task { @MainActor in
                            DietSync.completePlannedMeal(p, foods: foodMap, in: context)
                        }
                    }
                    .font(Glass.body(12, .bold)).foregroundStyle(Glass.amberText)
                    .accessibilityIdentifier("completePlanned")
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.05)))
    }

    private func statusPill(_ s: PlanStatus) -> some View {
        let c: Color = s == .completed ? Glass.green : (s == .skipped ? Glass.ink.opacity(0.4) : Glass.amber)
        return Text(s.label.uppercased())
            .font(Glass.body(9, .bold)).tracking(0.5).foregroundStyle(c)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(c.opacity(0.15)))
            .overlay(Capsule().strokeBorder(c.opacity(0.35)))
    }
}

/// Foglio "pianifica un pasto": ricetta rapida o paniere di alimenti.
struct PlanMealSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Recipe.updatedAt, order: .reverse) private var recipes: [Recipe]

    let day: Date
    @State var slot: MealSlot
    @State private var basket: [BasketItem] = []
    @State private var pickedRecipe: Recipe?

    private var canSave: Bool { !basket.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Annulla") { dismiss() }
                    .font(Glass.body(14)).foregroundStyle(Glass.ink.opacity(0.6))
                Spacer()
                Text("Pianifica").font(Glass.display(16, .semibold))
                Spacer()
                Button("Aggiungi") { save() }
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
        DietSync.planMeal(date: day, slot: slot, recipe: pickedRecipe,
                          items: basket.map { (food: $0.food, grams: $0.grams) },
                          in: context)
        dismiss()
    }
}
