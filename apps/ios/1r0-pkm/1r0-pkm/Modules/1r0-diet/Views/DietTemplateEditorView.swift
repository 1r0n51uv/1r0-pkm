//
//  DietTemplateEditorView.swift
//  1r0-pkm · Modules/1r0-diet/Views
//
//  Dieta settimanale a template (ADR-0029): un template assegna una ricetta
//  **o un alimento semplice** (ADR-0032, es. "noci" senza incapsularlo in
//  una ricetta) per ciascuno dei 5 slot (ADR-0024) di ciascun giorno;
//  "Applica" lo traduce in `PlannedMeal` per una settimana specifica
//  (`DietSync.applyTemplate`). Reso da `MealPlanView` (icona
//  "calendar.badge.clock").
//

import SwiftUI
import SwiftData

/// Lunedì..domenica, in italiano, ordine ISO (1 = lunedì).
private let weekdayLabels = ["Lunedì", "Martedì", "Mercoledì", "Giovedì", "Venerdì", "Sabato", "Domenica"]

struct DietTemplateEditorView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DietTemplate.createdAt) private var templates: [DietTemplate]
    @State private var newName = ""
    @State private var showNew = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Diete settimanali").font(Glass.display(24, .bold)).padding(.top, 4)
                Text("Assegna una ricetta per ogni pasto della settimana, poi applica il "
                     + "template a una settimana specifica.")
                    .font(Glass.body(13)).foregroundStyle(Glass.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if templates.isEmpty {
                    GlassEmptyState(systemImage: "calendar.badge.clock", title: "Nessun template",
                                    message: "Crea la tua prima dieta settimanale.") {
                        GlassPrimaryButton(title: "Nuovo template", systemImage: "plus",
                                           fill: Glass.amber, onInk: Color(red: 0.12, green: 0.06, blue: 0)) {
                            showNew = true
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.top, 40)
                } else {
                    VStack(spacing: 10) {
                        ForEach(templates) { t in
                            NavigationLink { DietTemplateDetailView(template: t) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(t.name).font(Glass.body(15, .semibold)).foregroundStyle(Glass.textPrimary)
                                        Text("\(t.items.filter { $0.recipeId != nil || $0.foodId != nil }.count) pasti assegnati")
                                            .font(Glass.body(11)).foregroundStyle(Glass.textFaint)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Glass.textFaint)
                                }
                                .padding(14)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.05)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    GlassPrimaryButton(title: "Nuovo template", systemImage: "plus",
                                       fill: Glass.amber, onInk: Color(red: 0.12, green: 0.06, blue: 0)) {
                        showNew = true
                    }
                    .accessibilityIdentifier("newTemplate")
                }
            }
            .padding(.horizontal, 22).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .glassScreen(.warm)
        .navigationTitle("Diete settimanali")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Nuovo template", isPresented: $showNew) {
            TextField("Nome (es. \"Settimana tipo\")", text: $newName)
            Button("Annulla", role: .cancel) { newName = "" }
            Button("Crea") {
                let trimmed = newName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                context.insert(DietTemplate(name: trimmed))
                try? context.save()
                newName = ""
            }
        }
    }
}

struct DietTemplateDetailView: View {
    @Bindable var template: DietTemplate
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var recipes: [Recipe]
    @Query(sort: \Food.name) private var foods: [Food]

    @State private var pickerFor: (weekday: Int, slot: MealSlot)?
    @State private var applyWeekStart = DietTemplateDetailView.thisMonday()
    @State private var applyResult: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(1...7, id: \.self) { weekday in
                    dayCard(weekday)
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Applica a una settimana")
                    HStack(spacing: 8) {
                        GlassChip(label: "Questa settimana",
                                 selected: Calendar.current.isDate(applyWeekStart, inSameDayAs: Self.thisMonday()),
                                 tint: Glass.amber) { applyWeekStart = Self.thisMonday() }
                        GlassChip(label: "Prossima settimana",
                                 selected: Calendar.current.isDate(applyWeekStart, inSameDayAs: Self.nextMonday()),
                                 tint: Glass.amber) { applyWeekStart = Self.nextMonday() }
                    }
                    DatePicker("Settimana di", selection: $applyWeekStart, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .font(Glass.body(13))
                        .onChange(of: applyWeekStart) { _, new in applyWeekStart = Self.monday(of: new) }
                    GlassPrimaryButton(title: "Applica il template", systemImage: "checkmark.circle",
                                       fill: Glass.green, onInk: Color(red: 0.01, green: 0.09, blue: 0.05)) {
                        let n = DietSync.applyTemplate(template, weekStart: applyWeekStart, in: context)
                        applyResult = n > 0
                            ? "\(n) pasti pianificati per la settimana del \(applyWeekStart.formatted(date: .abbreviated, time: .omitted))."
                            : "Nessun pasto da applicare: assegna almeno una ricetta."
                    }
                    .accessibilityIdentifier("applyTemplate")
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 22).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .glassScreen(.warm)
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        DietSync.deleteTemplate(template, in: context)
                        dismiss()
                    } label: { Label("Elimina template", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(item: Binding(
            get: { pickerFor.map { PickerTarget(weekday: $0.weekday, slot: $0.slot) } },
            set: { pickerFor = $0.map { ($0.weekday, $0.slot) } }
        )) { target in
            let existing = template.item(weekday: target.weekday, slot: target.slot)
            TemplateItemPickerSheet(recipes: recipes, foods: foods,
                                    currentRecipeId: existing?.recipeId, currentFoodId: existing?.foodId,
                                    onPickRecipe: { assignRecipe($0, weekday: target.weekday, slot: target.slot) },
                                    onPickFood: { assignFood($0, grams: $1, weekday: target.weekday, slot: target.slot) },
                                    onClear: { clearAssignment(weekday: target.weekday, slot: target.slot) })
            .presentationDetents([.medium, .large])
            .presentationBackground(.ultraThinMaterial)
        }
        .alert("Template applicato", isPresented: .constant(applyResult != nil)) {
            Button("OK") { applyResult = nil }
        } message: { Text(applyResult ?? "") }
    }

    private func dayCard(_ weekday: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(weekdayLabels[weekday - 1]).font(Glass.body(14, .bold)).foregroundStyle(Glass.textPrimary)
            VStack(spacing: 6) {
                ForEach(MealSlot.allCases) { slot in slotRow(weekday, slot) }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.05)))
    }

    private func slotRow(_ weekday: Int, _ slot: MealSlot) -> some View {
        let item = template.item(weekday: weekday, slot: slot)
        let assigned = item?.assignedName
        return Button { pickerFor = (weekday, slot) } label: {
            HStack(spacing: 10) {
                Image(systemName: slot.systemImage).font(.system(size: 12))
                    .foregroundStyle(assigned != nil ? Glass.amber : Glass.ink.opacity(0.35))
                    .frame(width: 18)
                Text(slot.label).font(Glass.body(12, .semibold)).foregroundStyle(Glass.textSecondary)
                    .frame(width: 130, alignment: .leading)
                Text(assigned ?? "—")
                    .font(Glass.body(13)).foregroundStyle(assigned != nil ? Glass.textPrimary : Glass.textFaint)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Glass.textFaint)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.03)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("slot_\(weekday)_\(slot.rawValue)")
    }

    private func assignRecipe(_ recipe: Recipe, weekday: Int, slot: MealSlot) {
        if let existing = template.item(weekday: weekday, slot: slot) {
            existing.recipeId = recipe.id
            existing.recipeName = recipe.name
            existing.foodId = nil
            existing.foodName = nil
        } else {
            // Creare il figlio con `template:` nell'init e poi `context.insert`
            // non basta: `template.items` (letto in `slotRow` subito dopo, non
            // via @Query) resta stantio finché non si passa dal lato "a molti"
            // della relazione — append, non assegnazione dell'intero array
            // (quella impicca, nota memoria SwiftData).
            let it = DietTemplateItem(weekday: weekday, mealSlot: slot,
                                      recipeId: recipe.id, recipeName: recipe.name)
            template.items.append(it)
            context.insert(it)
        }
        try? context.save()
    }

    private func assignFood(_ food: Food, grams: Double, weekday: Int, slot: MealSlot) {
        if let existing = template.item(weekday: weekday, slot: slot) {
            existing.recipeId = nil
            existing.recipeName = nil
            existing.foodId = food.id
            existing.foodName = food.name
            existing.foodGrams = grams
        } else {
            let it = DietTemplateItem(weekday: weekday, mealSlot: slot,
                                      foodId: food.id, foodName: food.name, foodGrams: grams)
            template.items.append(it)
            context.insert(it)
        }
        try? context.save()
    }

    private func clearAssignment(weekday: Int, slot: MealSlot) {
        if let existing = template.item(weekday: weekday, slot: slot) {
            existing.recipeId = nil; existing.recipeName = nil
            existing.foodId = nil; existing.foodName = nil
        } else {
            let it = DietTemplateItem(weekday: weekday, mealSlot: slot)
            template.items.append(it)
            context.insert(it)
        }
        try? context.save()
    }

    private struct PickerTarget: Identifiable { let weekday: Int; let slot: MealSlot
        var id: String { "\(weekday)-\(slot.rawValue)" } }

    static func thisMonday() -> Date { monday(of: .now) }
    static func nextMonday() -> Date {
        Calendar.current.date(byAdding: .day, value: 7, to: thisMonday()) ?? thisMonday()
    }
    static func monday(of date: Date) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2 // lunedì
        let start = cal.startOfDay(for: date)
        let weekday = cal.component(.weekday, from: start) // 1=dom..7=sab (calendario di sistema)
        let isoWeekday = weekday == 1 ? 7 : weekday - 1     // 1=lun..7=dom
        return cal.date(byAdding: .day, value: -(isoWeekday - 1), to: start) ?? start
    }
}

/// Sheet: scegli una ricetta, un alimento semplice dall'elenco cibi
/// (ADR-0032, es. "noci" — usa `FoodBasketEditor` per riusare ricerca cache
/// locale/OpenFoodFacts/USDA + stepper grammi), o "Nessuna" per svuotare lo
/// slot.
private struct TemplateItemPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let recipes: [Recipe]
    let foods: [Food]
    let currentRecipeId: UUID?
    let currentFoodId: UUID?
    let onPickRecipe: (Recipe) -> Void
    let onPickFood: (Food, Double) -> Void
    let onClear: () -> Void

    @State private var foodBasket: [BasketItem] = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onClear(); dismiss()
                    } label: {
                        HStack {
                            Text("Nessuna")
                            Spacer()
                            if currentRecipeId == nil && currentFoodId == nil { Image(systemName: "checkmark") }
                        }
                    }
                }
                Section("Ricette") {
                    ForEach(recipes) { r in
                        Button {
                            onPickRecipe(r); dismiss()
                        } label: {
                            HStack { Text(r.name); Spacer(); if currentRecipeId == r.id { Image(systemName: "checkmark") } }
                        }
                    }
                }
                Section("Alimenti") {
                    FoodBasketEditor(items: $foodBasket)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    if let picked = foodBasket.last {
                        Button {
                            onPickFood(picked.food, picked.grams); dismiss()
                        } label: {
                            Text("Usa \(picked.food.name)").font(Glass.body(14, .bold))
                        }
                        .accessibilityIdentifier("useFoodInTemplate")
                    }
                }
            }
            .navigationTitle("Scegli ricetta o alimento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .onChange(of: foodBasket.count) { _, n in
                // un solo alimento per slot: il più recente sostituisce i precedenti.
                if n > 1 { foodBasket.removeFirst(n - 1) }
            }
        }
    }
}
