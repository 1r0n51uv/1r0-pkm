//
//  DietSync.swift
//  1r0-pkm · Modules/1r0-diet
//
//  Pull dal backend + azioni di dominio del modulo dieta (ADR-0017 slice 1).
//  L'outbox è quello condiviso (OutboxEntry / GymSync.flushOutbox, ADR-0006):
//  i kind `food.create` e `mealentry.create` sono gestiti in GymSync.send.
//

import Foundation
import SwiftData

enum DietSync {

    /// Scarica il catalogo alimenti e fa upsert nello store locale.
    @MainActor
    static func pullFoods(into context: ModelContext) async {
        do {
            let data = try await ApiClient.shared.get("v1/foods")
            let rows = try JSONDecoder.api.decode([FoodDTO].self, from: data)
            for r in rows {
                guard let uuid = UUID(uuidString: r.id) else { continue }
                let existing = try context.fetch(
                    FetchDescriptor<Food>(predicate: #Predicate { $0.id == uuid })
                ).first
                let f = existing ?? Food(id: uuid, name: r.name, caloriesPer100g: 0)
                f.name = r.name
                f.source = r.source
                f.externalId = r.external_id
                f.barcode = r.barcode
                f.brand = r.brand
                f.servingSizeG = num(r.serving_size_g)
                f.caloriesPer100g = num(r.calories_per_100g) ?? 0
                f.proteinGPer100g = num(r.protein_g_per_100g) ?? 0
                f.carbsGPer100g = num(r.carbs_g_per_100g) ?? 0
                f.fatGPer100g = num(r.fat_g_per_100g) ?? 0
                f.caffeineMgPer100g = num(r.caffeine_mg_per_100g)
                f.syncedAt = .now
                if existing == nil { context.insert(f) }
            }
            try context.save()
        } catch {
            // offline / backend giù: si riprova al prossimo giro.
        }
    }

    /// Scarica i pasti loggati (con item) e fa upsert.
    @MainActor
    static func pullMealEntries(into context: ModelContext) async {
        do {
            let data = try await ApiClient.shared.get("v1/meal-entries")
            let rows = try JSONDecoder.api.decode([MealEntryDTO].self, from: data)
            for r in rows {
                guard let uuid = UUID(uuidString: r.id),
                      let slot = MealSlot(rawValue: r.meal_slot) else { continue }
                let existing = try context.fetch(
                    FetchDescriptor<MealEntry>(predicate: #Predicate { $0.id == uuid })
                ).first
                let m = existing ?? MealEntry(id: uuid, mealSlot: slot)
                if existing == nil { context.insert(m) }
                m.consumedAt = JSONDecoder.iso.date(from: r.consumed_at) ?? m.consumedAt
                m.mealSlot = slot
                m.notes = r.notes
                m.syncedAt = .now
                // rimpiazza gli item (snapshot dal backend). NB: non
                // assegnare `m.items = [...]` mentre gli item si auto-
                // registrano via `meal: m` — SwiftData crasha. Cancella i
                // vecchi, poi `insert` i nuovi e lascia fare all'inverse rel.
                for old in m.items { context.delete(old) }
                for (i, it) in (r.items ?? []).enumerated() {
                    context.insert(MealEntryItem(
                        meal: m,
                        foodId: it.food_id.flatMap(UUID.init(uuidString:)),
                        foodName: it.food_name ?? "—",
                        quantityG: num(it.quantity_g) ?? 0,
                        macros: Macros(kcal: num(it.calories) ?? 0,
                                       proteinG: num(it.protein_g) ?? 0,
                                       carbsG: num(it.carbs_g) ?? 0,
                                       fatG: num(it.fat_g) ?? 0),
                        orderIndex: it.order_index ?? i
                    ))
                }
            }
            try context.save()
        } catch { }
    }

    // MARK: - Azioni

    /// Crea un alimento custom + accoda `food.create` (offline-first).
    @MainActor
    @discardableResult
    static func createFood(name: String, kcal: Double, protein: Double,
                           carbs: Double, fat: Double, in context: ModelContext) -> Food {
        let f = Food(name: name, source: "custom", caloriesPer100g: kcal,
                     proteinGPer100g: protein, carbsGPer100g: carbs, fatGPer100g: fat)
        context.insert(f)
        enqueue("food.create", [
            "id": f.id.uuidString, "name": name, "source": "custom",
            "caloriesPer100g": kcal, "proteinGPer100g": protein,
            "carbsGPer100g": carbs, "fatGPer100g": fat,
        ], in: context)
        return f
    }

    /// Logga un pasto (uno o più alimenti) + accoda `mealentry.create`.
    @MainActor
    @discardableResult
    static func logMeal(slot: MealSlot, date: Date = .now,
                        items: [(food: Food, grams: Double)],
                        in context: ModelContext) -> MealEntry {
        let m = MealEntry(consumedAt: date, mealSlot: slot)
        context.insert(m)
        var payloadItems: [[String: Any]] = []
        for (i, pair) in items.enumerated() {
            let mac = pair.food.macros(forGrams: pair.grams)
            let it = MealEntryItem(meal: m, foodId: pair.food.id, foodName: pair.food.name,
                                   quantityG: pair.grams, macros: mac, orderIndex: i)
            context.insert(it)
            payloadItems.append([
                "foodId": pair.food.id.uuidString, "foodName": pair.food.name,
                "quantityG": pair.grams, "calories": mac.kcal,
                "proteinG": mac.proteinG, "carbsG": mac.carbsG, "fatG": mac.fatG,
                "orderIndex": i,
            ])
        }
        enqueue("mealentry.create", [
            "id": m.id.uuidString,
            "consumedAt": ISO8601DateFormatter().string(from: date),
            "mealSlot": slot.rawValue,
            "items": payloadItems,
        ], in: context)
        return m
    }

    // MARK: - Ricette + pianificazione pasti (ADR-0017 slice 2)

    @MainActor
    static func pullRecipes(into context: ModelContext) async {
        do {
            let data = try await ApiClient.shared.get("v1/recipes")
            let rows = try JSONDecoder.api.decode([RecipeDTO].self, from: data)
            for r in rows {
                guard let uuid = UUID(uuidString: r.id) else { continue }
                let existing = try context.fetch(
                    FetchDescriptor<Recipe>(predicate: #Predicate { $0.id == uuid })
                ).first
                let rec = existing ?? Recipe(id: uuid, name: r.name)
                if existing == nil { context.insert(rec) }
                rec.name = r.name
                rec.notes = r.notes
                rec.updatedAt = JSONDecoder.iso.date(from: r.updated_at ?? "") ?? rec.updatedAt
                rec.syncedAt = .now
                // rimpiazza gli item (vedi nota anti-crash in pullMealEntries).
                for old in rec.items { context.delete(old) }
                for (i, it) in (r.items ?? []).enumerated() {
                    context.insert(RecipeItem(
                        recipe: rec,
                        foodId: it.food_id.flatMap(UUID.init(uuidString:)),
                        foodName: it.food_name ?? "—",
                        quantityG: num(it.quantity_g) ?? 0,
                        orderIndex: it.order_index ?? i
                    ))
                }
            }
            try context.save()
        } catch { }
    }

    @MainActor
    static func pullPlannedMeals(from: Date, to: Date, into context: ModelContext) async {
        let q = "from=\(isoDate(from))&to=\(isoDate(to))"
        do {
            let data = try await ApiClient.shared.get("v1/planned-meals?\(q)")
            let rows = try JSONDecoder.api.decode([PlannedMealDTO].self, from: data)
            for r in rows {
                guard let uuid = UUID(uuidString: r.id),
                      let slot = MealSlot(rawValue: r.meal_slot),
                      let day = date(r.planned_date) else { continue }
                let existing = try context.fetch(
                    FetchDescriptor<PlannedMeal>(predicate: #Predicate { $0.id == uuid })
                ).first
                let p = existing ?? PlannedMeal(id: uuid, plannedDate: day, mealSlot: slot)
                if existing == nil { context.insert(p) }
                p.plannedDate = day
                p.mealSlot = slot
                p.status = PlanStatus(rawValue: r.status ?? "planned") ?? .planned
                p.recipeId = r.recipe_id.flatMap(UUID.init(uuidString:))
                p.mealEntryId = r.meal_entry_id.flatMap(UUID.init(uuidString:))
                p.syncedAt = .now
                for old in p.items { context.delete(old) }
                for (i, it) in (r.items ?? []).enumerated() {
                    context.insert(PlannedMealItem(
                        plannedMeal: p,
                        foodId: it.food_id.flatMap(UUID.init(uuidString:)),
                        foodName: it.food_name ?? "—",
                        quantityG: num(it.quantity_g) ?? 0,
                        orderIndex: it.order_index ?? i
                    ))
                }
            }
            try context.save()
        } catch { }
    }

    /// Crea/aggiorna una ricetta + accoda `recipe.create` (upsert idempotente).
    @MainActor
    @discardableResult
    static func saveRecipe(name: String, notes: String? = nil,
                           items: [(food: Food, grams: Double)],
                           existing: Recipe? = nil,
                           in context: ModelContext) -> Recipe {
        let rec = existing ?? Recipe(name: name)
        rec.name = name
        rec.notes = notes
        rec.updatedAt = .now
        rec.syncedAt = nil
        if existing == nil { context.insert(rec) }
        for old in rec.items { context.delete(old) }
        var payloadItems: [[String: Any]] = []
        for (i, pair) in items.enumerated() {
            context.insert(RecipeItem(recipe: rec, foodId: pair.food.id,
                                      foodName: pair.food.name, quantityG: pair.grams,
                                      orderIndex: i))
            payloadItems.append([
                "foodId": pair.food.id.uuidString, "foodName": pair.food.name,
                "quantityG": pair.grams, "orderIndex": i,
            ])
        }
        var payload: [String: Any] = ["id": rec.id.uuidString, "name": name,
                                      "items": payloadItems]
        if let notes, !notes.isEmpty { payload["notes"] = notes }
        enqueue("recipe.create", payload, in: context)
        return rec
    }

    /// Pianifica un pasto per un giorno + accoda `plannedmeal.create`.
    @MainActor
    @discardableResult
    static func planMeal(date day: Date, slot: MealSlot, recipe: Recipe? = nil,
                         items: [(food: Food, grams: Double)],
                         in context: ModelContext) -> PlannedMeal {
        let d = Calendar.current.startOfDay(for: day)
        let p = PlannedMeal(plannedDate: d, mealSlot: slot, recipeId: recipe?.id)
        context.insert(p)
        var payloadItems: [[String: Any]] = []
        for (i, pair) in items.enumerated() {
            context.insert(PlannedMealItem(plannedMeal: p, foodId: pair.food.id,
                                           foodName: pair.food.name, quantityG: pair.grams,
                                           orderIndex: i))
            payloadItems.append([
                "foodId": pair.food.id.uuidString, "foodName": pair.food.name,
                "quantityG": pair.grams, "orderIndex": i,
            ])
        }
        var payload: [String: Any] = [
            "id": p.id.uuidString, "plannedDate": isoDate(d),
            "mealSlot": slot.rawValue, "status": "planned", "items": payloadItems,
        ]
        if let recipe { payload["recipeId"] = recipe.id.uuidString }
        enqueue("plannedmeal.create", payload, in: context)
        return p
    }

    /// Conferma un pasto pianificato: crea il `MealEntry` collegato (log) e
    /// mette lo stato `completed`. Accoda `mealentry.create` + `plannedmeal.create`.
    @MainActor
    static func completePlannedMeal(_ p: PlannedMeal, foods: [UUID: Food],
                                    in context: ModelContext) {
        guard p.status != .completed else { return }
        let pairs: [(food: Food, grams: Double)] = p.items.compactMap { it in
            guard let f = it.foodId.flatMap({ foods[$0] }) else { return nil }
            return (f, it.quantityG)
        }
        let entry = logMeal(slot: p.mealSlot, date: .now, items: pairs, in: context)
        p.status = .completed
        p.mealEntryId = entry.id
        p.syncedAt = nil
        enqueuePlannedMeal(p, in: context)
    }

    @MainActor
    static func skipPlannedMeal(_ p: PlannedMeal, in context: ModelContext) {
        p.status = .skipped
        p.syncedAt = nil
        enqueuePlannedMeal(p, in: context)
    }

    /// Re-accoda lo stato corrente di un pasto pianificato (upsert).
    @MainActor
    private static func enqueuePlannedMeal(_ p: PlannedMeal, in context: ModelContext) {
        let payloadItems = p.items
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { it -> [String: Any] in
                var d: [String: Any] = ["foodName": it.foodName,
                                        "quantityG": it.quantityG,
                                        "orderIndex": it.orderIndex]
                if let fid = it.foodId { d["foodId"] = fid.uuidString }
                return d
            }
        var payload: [String: Any] = [
            "id": p.id.uuidString, "plannedDate": isoDate(p.plannedDate),
            "mealSlot": p.mealSlot.rawValue, "status": p.status.rawValue,
            "items": payloadItems,
        ]
        if let rid = p.recipeId { payload["recipeId"] = rid.uuidString }
        if let mid = p.mealEntryId { payload["mealEntryId"] = mid.uuidString }
        enqueue("plannedmeal.create", payload, in: context)
    }

    // MARK: - Obiettivo nutrizionale (ADR-0019, append-only)

    @MainActor
    static func pullGoals(into context: ModelContext) async {
        do {
            let data = try await ApiClient.shared.get("v1/nutrition-goals")
            let rows = try JSONDecoder.api.decode([NutritionGoalDTO].self, from: data)
            for r in rows {
                guard let uuid = UUID(uuidString: r.id),
                      let mode = GoalMode(rawValue: r.mode) else { continue }
                let existing = try context.fetch(
                    FetchDescriptor<NutritionGoal>(predicate: #Predicate { $0.id == uuid })
                ).first
                let g = existing ?? NutritionGoal(id: uuid, mode: mode, macros: .zero)
                g.mode = mode
                g.caloriesTarget = num(r.calories_target) ?? 0
                g.proteinGTarget = num(r.protein_g_target) ?? 0
                g.carbsGTarget = num(r.carbs_g_target) ?? 0
                g.fatGTarget = num(r.fat_g_target) ?? 0
                g.waterMlTarget = num(r.water_ml_target)
                g.effectiveFrom = date(r.effective_from) ?? g.effectiveFrom
                g.activityLevelRaw = r.activity_level
                g.sourceNote = r.source_note
                g.syncedAt = .now
                if existing == nil { context.insert(g) }
            }
            try context.save()
        } catch { }
    }

    /// Inserisce una NUOVA riga obiettivo (mai update — ADR-0019) + accoda
    /// `nutritiongoal.create`.
    @MainActor
    @discardableResult
    static func setGoal(mode: GoalMode, macros: Macros, waterMl: Double? = nil,
                        activity: ActivityLevel? = nil, note: String? = nil,
                        in context: ModelContext) -> NutritionGoal {
        let g = NutritionGoal(mode: mode, macros: macros, waterMlTarget: waterMl,
                              effectiveFrom: Calendar.current.startOfDay(for: .now),
                              activityLevel: activity, sourceNote: note)
        context.insert(g)
        var payload: [String: Any] = [
            "id": g.id.uuidString, "mode": mode.rawValue,
            "caloriesTarget": macros.kcal, "proteinGTarget": macros.proteinG,
            "carbsGTarget": macros.carbsG, "fatGTarget": macros.fatG,
            "effectiveFrom": isoDate(g.effectiveFrom),
        ]
        if let waterMl { payload["waterMlTarget"] = waterMl }
        if let activity { payload["activityLevel"] = activity.rawValue }
        if let note { payload["sourceNote"] = note }
        enqueue("nutritiongoal.create", payload, in: context)
        return g
    }

    /// Obiettivo "corrente": la riga più recente con `effectiveFrom <= oggi`.
    static func current(_ goals: [NutritionGoal], on day: Date = .now) -> NutritionGoal? {
        let end = Calendar.current.startOfDay(for: day)
        return goals
            .filter { $0.effectiveFrom <= end }
            .max { ($0.effectiveFrom, $0.createdAt) < ($1.effectiveFrom, $1.createdAt) }
    }

    // Le date "civili" (`effective_from`, `planned_date`) sono senza fuso:
    // le si interpreta nel calendario locale, coerente con lo
    // `startOfDay(for:)` locale usato nelle viste (niente scivolamento di un
    // giorno per chi non è a UTC).
    private static func date(_ s: String) -> Date? {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        f.calendar = .init(identifier: .gregorian); f.timeZone = .current
        return f.date(from: String(s.prefix(10)))
    }
    private static func isoDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        f.calendar = .init(identifier: .gregorian); f.timeZone = .current
        return f.string(from: d)
    }

    // MARK: - Lista della spesa (ADR-0017 slice 3)

    @MainActor
    static func pullShoppingList(into context: ModelContext) async {
        do {
            let data = try await ApiClient.shared.get("v1/shopping-list")
            let rows = try JSONDecoder.api.decode([ShoppingItemDTO].self, from: data)
            for r in rows {
                guard let uuid = UUID(uuidString: r.id) else { continue }
                let existing = try context.fetch(
                    FetchDescriptor<ShoppingListItem>(predicate: #Predicate { $0.id == uuid })
                ).first
                let it = existing ?? ShoppingListItem(id: uuid, customName: r.custom_name ?? "")
                if existing == nil { context.insert(it) }
                it.foodId = r.food_id.flatMap(UUID.init(uuidString:))
                it.customName = r.custom_name ?? ""
                it.quantityText = r.quantity_text
                it.isChecked = r.is_checked ?? false
                it.source = ShoppingSource(rawValue: r.source ?? "manual") ?? .manual
                it.syncedAt = .now
            }
            try context.save()
        } catch { }
    }

    @MainActor
    @discardableResult
    static func addShoppingItem(name: String, quantity: String? = nil,
                                foodId: UUID? = nil, source: ShoppingSource = .manual,
                                in context: ModelContext) -> ShoppingListItem {
        let it = ShoppingListItem(foodId: foodId, customName: name,
                                  quantityText: quantity, source: source)
        context.insert(it)
        enqueueShoppingItem(it, in: context)
        return it
    }

    @MainActor
    static func setShoppingChecked(_ it: ShoppingListItem, _ checked: Bool,
                                   in context: ModelContext) {
        it.isChecked = checked
        it.syncedAt = nil
        enqueueShoppingItem(it, in: context)
    }

    @MainActor
    static func deleteShoppingItem(_ it: ShoppingListItem, in context: ModelContext) {
        let id = it.id.uuidString
        context.delete(it)
        try? context.save()
        Task { try? await ApiClient.shared.delete("v1/shopping-list/\(id)") }
    }

    /// Aggiunge alla lista gli alimenti dei pasti pianificati passati che non
    /// sono già presenti (per nome). Non tocca le voci esistenti.
    @MainActor
    @discardableResult
    static func generateShoppingList(from planned: [PlannedMeal],
                                     existing: [ShoppingListItem],
                                     in context: ModelContext) -> Int {
        var have = Set(existing.map { $0.displayName.lowercased() })
        var added = 0
        for p in planned where p.status != .skipped {
            for item in p.items {
                let key = item.foodName.lowercased()
                guard !key.isEmpty, !have.contains(key) else { continue }
                have.insert(key)
                _ = addShoppingItem(name: item.foodName,
                                    quantity: "\(Int(item.quantityG)) g",
                                    foodId: item.foodId, source: .generated, in: context)
                added += 1
            }
        }
        return added
    }

    @MainActor
    private static func enqueueShoppingItem(_ it: ShoppingListItem, in context: ModelContext) {
        var payload: [String: Any] = [
            "id": it.id.uuidString, "customName": it.customName,
            "isChecked": it.isChecked, "source": it.source.rawValue,
        ]
        if let f = it.foodId { payload["foodId"] = f.uuidString }
        if let q = it.quantityText { payload["quantityText"] = q }
        enqueue("shoppingitem.put", payload, in: context)
    }

    // MARK: - Tracker: acqua / integratori / caffeina (ADR-0017 slice 4)

    @MainActor
    static func pullWaterLogs(into context: ModelContext) async {
        do {
            let data = try await ApiClient.shared.get("v1/water-logs")
            let rows = try JSONDecoder.api.decode([WaterLogDTO].self, from: data)
            for r in rows {
                guard let uuid = UUID(uuidString: r.id) else { continue }
                let existing = try context.fetch(
                    FetchDescriptor<WaterLog>(predicate: #Predicate { $0.id == uuid })
                ).first
                let w = existing ?? WaterLog(id: uuid, amountMl: 0)
                if existing == nil { context.insert(w) }
                w.loggedAt = JSONDecoder.iso.date(from: r.logged_at) ?? w.loggedAt
                w.amountMl = num(r.amount_ml) ?? 0
                w.syncedAt = .now
            }
            try context.save()
        } catch { }
    }

    @MainActor
    @discardableResult
    static func addWater(ml: Double, in context: ModelContext) -> WaterLog {
        let w = WaterLog(amountMl: ml)
        context.insert(w)
        enqueue("waterlog.create", [
            "id": w.id.uuidString, "amountMl": ml,
            "loggedAt": ISO8601DateFormatter().string(from: w.loggedAt),
        ], in: context)
        return w
    }

    @MainActor
    static func pullSupplements(into context: ModelContext) async {
        do {
            let data = try await ApiClient.shared.get("v1/supplements")
            let rows = try JSONDecoder.api.decode([SupplementDTO].self, from: data)
            for r in rows {
                guard let uuid = UUID(uuidString: r.id) else { continue }
                let existing = try context.fetch(
                    FetchDescriptor<Supplement>(predicate: #Predicate { $0.id == uuid })
                ).first
                let s = existing ?? Supplement(id: uuid, name: r.name)
                if existing == nil { context.insert(s) }
                s.name = r.name
                s.doseText = r.dose_text
                s.scheduleText = r.schedule_text
                s.active = r.active ?? true
                s.syncedAt = .now
            }
            try context.save()
        } catch { }
    }

    @MainActor
    static func pullSupplementLogs(into context: ModelContext) async {
        do {
            let data = try await ApiClient.shared.get("v1/supplement-logs")
            let rows = try JSONDecoder.api.decode([SupplementLogDTO].self, from: data)
            for r in rows {
                guard let uuid = UUID(uuidString: r.id),
                      let sid = UUID(uuidString: r.supplement_id) else { continue }
                let existing = try context.fetch(
                    FetchDescriptor<SupplementLog>(predicate: #Predicate { $0.id == uuid })
                ).first
                let l = existing ?? SupplementLog(id: uuid, supplementId: sid)
                if existing == nil { context.insert(l) }
                l.supplementId = sid
                l.loggedAt = JSONDecoder.iso.date(from: r.logged_at) ?? l.loggedAt
                l.taken = r.taken ?? true
                l.syncedAt = .now
            }
            try context.save()
        } catch { }
    }

    @MainActor
    @discardableResult
    static func addSupplement(name: String, dose: String? = nil, schedule: String? = nil,
                              in context: ModelContext) -> Supplement {
        let s = Supplement(name: name, doseText: dose, scheduleText: schedule)
        context.insert(s)
        var payload: [String: Any] = ["id": s.id.uuidString, "name": name, "active": true]
        if let dose { payload["doseText"] = dose }
        if let schedule { payload["scheduleText"] = schedule }
        enqueue("supplement.put", payload, in: context)
        return s
    }

    @MainActor
    static func deleteSupplement(_ s: Supplement, in context: ModelContext) {
        let id = s.id.uuidString
        context.delete(s)
        try? context.save()
        Task { try? await ApiClient.shared.delete("v1/supplements/\(id)") }
    }

    /// La spunta di oggi per un integratore (crea o aggiorna la riga del giorno).
    @MainActor
    static func setSupplementTaken(_ supp: Supplement, taken: Bool,
                                   logs: [SupplementLog], on day: Date = .now,
                                   in context: ModelContext) {
        let sid = supp.id
        let existing = logs.first {
            $0.supplementId == sid && Calendar.current.isDate($0.loggedAt, inSameDayAs: day)
        }
        let l = existing ?? SupplementLog(supplementId: sid, loggedAt: day, taken: taken)
        if existing == nil { context.insert(l) }
        l.taken = taken
        l.syncedAt = nil
        enqueue("supplementlog.put", [
            "id": l.id.uuidString, "supplementId": sid.uuidString,
            "taken": taken, "loggedAt": ISO8601DateFormatter().string(from: l.loggedAt),
        ], in: context)
    }

    @MainActor
    static func pullCaffeineLogs(into context: ModelContext) async {
        do {
            let data = try await ApiClient.shared.get("v1/caffeine-logs")
            let rows = try JSONDecoder.api.decode([CaffeineLogDTO].self, from: data)
            for r in rows {
                guard let uuid = UUID(uuidString: r.id) else { continue }
                let existing = try context.fetch(
                    FetchDescriptor<CaffeineLog>(predicate: #Predicate { $0.id == uuid })
                ).first
                let ca = existing ?? CaffeineLog(id: uuid, sourceName: "", caffeineMg: 0)
                if existing == nil { context.insert(ca) }
                ca.loggedAt = JSONDecoder.iso.date(from: r.logged_at) ?? ca.loggedAt
                ca.sourceName = r.source_name ?? "caffè"
                ca.caffeineMg = num(r.caffeine_mg) ?? 0
                ca.syncedAt = .now
            }
            try context.save()
        } catch { }
    }

    @MainActor
    @discardableResult
    static func addCaffeine(mg: Double, source: String = "Caffè",
                            in context: ModelContext) -> CaffeineLog {
        let ca = CaffeineLog(sourceName: source, caffeineMg: mg)
        context.insert(ca)
        enqueue("caffeinelog.create", [
            "id": ca.id.uuidString, "sourceName": source, "caffeineMg": mg,
            "loggedAt": ISO8601DateFormatter().string(from: ca.loggedAt),
        ], in: context)
        return ca
    }

    // MARK: - Ricerca esterna (ADR-0018)

    /// Ricerca testuale su OpenFoodFacts + USDA (via backend). Ritorna
    /// candidati transitori (non SwiftData): l'utente ne sceglie uno e solo
    /// allora diventa un `Food` locale (in `materialize`).
    static func searchRemote(_ query: String) async -> [FoodCandidate] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2,
              let enc = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return [] }
        do {
            let data = try await ApiClient.shared.get("v1/foods/search?q=\(enc)")
            return try JSONDecoder.api.decode([FoodCandidate].self, from: data)
        } catch {
            return []
        }
    }

    /// Lookup barcode: prima la cache backend (`foods`), poi OpenFoodFacts.
    static func lookupBarcode(_ code: String) async -> FoodCandidate? {
        let c = code.filter(\.isNumber)
        guard c.count >= 6 else { return nil }
        do {
            let data = try await ApiClient.shared.get("v1/foods/barcode/\(c)")
            return try JSONDecoder.api.decode(FoodCandidate.self, from: data)
        } catch {
            return nil
        }
    }

    /// Trasforma un candidato in un `Food` locale (riusa quello già presente
    /// per stesso barcode o external_id) + accoda `food.create`.
    @MainActor
    @discardableResult
    static func materialize(_ cand: FoodCandidate, in context: ModelContext) -> Food {
        let bc = cand.barcode, ext = cand.externalId, src = cand.source
        if let bc, !bc.isEmpty,
           let hit = try? context.fetch(
               FetchDescriptor<Food>(predicate: #Predicate { $0.barcode == bc })).first {
            return hit
        }
        if let ext, !ext.isEmpty,
           let hit = try? context.fetch(FetchDescriptor<Food>(
               predicate: #Predicate { $0.externalId == ext && $0.source == src })).first {
            return hit
        }
        let f = Food(
            name: cand.name, source: cand.source, externalId: cand.externalId,
            barcode: cand.barcode, brand: cand.brand, servingSizeG: cand.servingSizeG,
            caloriesPer100g: cand.caloriesPer100g,
            proteinGPer100g: cand.proteinGPer100g,
            carbsGPer100g: cand.carbsGPer100g,
            fatGPer100g: cand.fatGPer100g,
            caffeineMgPer100g: cand.caffeineMgPer100g
        )
        context.insert(f)
        var payload: [String: Any] = [
            "id": f.id.uuidString, "name": cand.name, "source": cand.source,
            "caloriesPer100g": cand.caloriesPer100g,
            "proteinGPer100g": cand.proteinGPer100g,
            "carbsGPer100g": cand.carbsGPer100g,
            "fatGPer100g": cand.fatGPer100g,
        ]
        if let v = cand.externalId { payload["externalId"] = v }
        if let v = cand.barcode { payload["barcode"] = v }
        if let v = cand.brand { payload["brand"] = v }
        if let v = cand.servingSizeG { payload["servingSizeG"] = v }
        if let v = cand.caffeineMgPer100g { payload["caffeineMgPer100g"] = v }
        enqueue("food.create", payload, in: context)
        return f
    }

    @MainActor
    private static func enqueue(_ kind: String, _ payload: [String: Any], in context: ModelContext) {
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            context.insert(OutboxEntry(kind: kind, payload: data))
        }
        try? context.save()
        let ctx = context
        Task { await GymSync.flushOutbox(ctx) }
    }

    private static func num(_ v: FoodDTO.Num?) -> Double? { v?.value }
}

/// Risultato di ricerca esterna (ADR-0018) — transitorio, non SwiftData.
/// Il backend normalizza OFF/USDA a questa forma (numeri JSON, non stringhe).
struct FoodCandidate: Decodable, Identifiable, Hashable {
    var id: String { "\(source)/\(externalId ?? name)" }
    let name: String
    let source: String                 // "openfoodfacts" | "usda"
    let externalId: String?
    let barcode: String?
    let brand: String?
    let servingSizeG: Double?
    let caloriesPer100g: Double
    let proteinGPer100g: Double
    let carbsGPer100g: Double
    let fatGPer100g: Double
    let caffeineMgPer100g: Double?
}

// MARK: - wire

/// Postgres restituisce `numeric` come stringa; accetta anche numeri JSON.
struct FoodDTO: Decodable {
    struct Num: Decodable {
        let value: Double?
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let d = try? c.decode(Double.self) { value = d }
            else if let s = try? c.decode(String.self) { value = Double(s) }
            else { value = nil }
        }
    }
    let id: String
    let name: String
    let source: String
    let external_id: String?
    let barcode: String?
    let brand: String?
    let serving_size_g: Num?
    let calories_per_100g: Num?
    let protein_g_per_100g: Num?
    let carbs_g_per_100g: Num?
    let fat_g_per_100g: Num?
    let caffeine_mg_per_100g: Num?
}

struct NutritionGoalDTO: Decodable {
    let id: String
    let mode: String
    let calories_target: FoodDTO.Num?
    let protein_g_target: FoodDTO.Num?
    let carbs_g_target: FoodDTO.Num?
    let fat_g_target: FoodDTO.Num?
    let water_ml_target: FoodDTO.Num?
    let effective_from: String
    let activity_level: String?
    let source_note: String?
}

struct MealEntryDTO: Decodable {
    struct Item: Decodable {
        let food_id: String?
        let food_name: String?
        let quantity_g: FoodDTO.Num?
        let calories: FoodDTO.Num?
        let protein_g: FoodDTO.Num?
        let carbs_g: FoodDTO.Num?
        let fat_g: FoodDTO.Num?
        let order_index: Int?
    }
    let id: String
    let consumed_at: String
    let meal_slot: String
    let notes: String?
    let items: [Item]?
}

/// item di ricetta / pasto pianificato (solo nome + quantità, macro
/// calcolati dal `Food` all'uso).
struct PlanItemDTO: Decodable {
    let food_id: String?
    let food_name: String?
    let quantity_g: FoodDTO.Num?
    let order_index: Int?
}

struct RecipeDTO: Decodable {
    let id: String
    let name: String
    let notes: String?
    let updated_at: String?
    let items: [PlanItemDTO]?
}

struct PlannedMealDTO: Decodable {
    let id: String
    let planned_date: String
    let meal_slot: String
    let recipe_id: String?
    let status: String?
    let meal_entry_id: String?
    let items: [PlanItemDTO]?
}

struct ShoppingItemDTO: Decodable {
    let id: String
    let food_id: String?
    let custom_name: String?
    let quantity_text: String?
    let is_checked: Bool?
    let source: String?
}

struct WaterLogDTO: Decodable {
    let id: String
    let logged_at: String
    let amount_ml: FoodDTO.Num?
}

struct SupplementDTO: Decodable {
    let id: String
    let name: String
    let dose_text: String?
    let schedule_text: String?
    let active: Bool?
}

struct SupplementLogDTO: Decodable {
    let id: String
    let supplement_id: String
    let logged_at: String
    let taken: Bool?
}

struct CaffeineLogDTO: Decodable {
    let id: String
    let logged_at: String
    let source_name: String?
    let caffeine_mg: FoodDTO.Num?
}
