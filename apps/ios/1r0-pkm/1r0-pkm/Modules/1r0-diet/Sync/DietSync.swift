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
