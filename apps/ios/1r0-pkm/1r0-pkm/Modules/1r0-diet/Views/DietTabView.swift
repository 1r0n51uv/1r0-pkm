//
//  DietTabView.swift
//  1r0-pkm · Modules/1r0-diet
//
//  Dashboard giornaliera del modulo dieta (ADR-0017 slice 1, redesign
//  ADR-0036): anello calorie (sempre di oggi) + striscia giorni + i 5 pasti
//  con lo switch mangiato/saltato — la pianificazione (ex `MealPlanView`,
//  una pagina a parte) è ora la stessa vista: niente più due schermate quasi
//  identiche per "oggi" e "pianifica". Stile Glass Dark (ADR-0023), accento
//  ambra.
//

import SwiftUI
import SwiftData

/// Obiettivo calorico/macro. Slice 1 usa un default fisso; `NutritionGoal`
/// append-only e modalità (manuale/TDEE/fase) arrivano con ADR-0019.
enum DietGoal {
    static let kcal: Double = 2200
    static let proteinG: Double = 170
    static let carbsG: Double = 220
    static let fatG: Double = 70
}

/// Quanti giorni indietro/avanti mostrare nella striscia (ex `MealPlanView`,
/// ADR-0032: copre anche il passato per poter correggere retroattivamente).
private let daysBack = 10
private let daysForward = 13

struct DietTabView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MealEntry.consumedAt, order: .reverse) private var allMeals: [MealEntry]
    @Query(sort: \NutritionGoal.effectiveFrom, order: .reverse) private var goals: [NutritionGoal]
    @Query(sort: \PlannedMeal.plannedDate) private var allPlanned: [PlannedMeal]
    @Query private var allFoods: [Food]

    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var logSlot: MealSlot?
    @State private var composeSlot: MealSlot?
    @State private var editingPlan: PlannedMeal?
    @State private var showGoal = false
    @State private var showRecipes = false
    @State private var showShopping = false
    @State private var showTemplates = false
    /// Energia attiva di oggi da HealthKit (ADR-0019 amendata): alza la quota
    /// calorica del giorno senza toccare `nutrition_goals`.
    @State private var activeEnergyKcal: Double = 0
    /// Peso più recente da Salute (ADR-0036) — solo etichetta informativa,
    /// non entra nei calcoli di questa vista (per quello vedi Palestra →
    /// "Peso e misure", che lo registra come rilevazione).
    @State private var latestWeightKg: Double?

    private let cal = Calendar.current
    private let today = Calendar.current.startOfDay(for: .now)
    private var isToday: Bool { cal.isDate(selectedDay, inSameDayAs: today) }
    private var week: [Date] {
        (-daysBack...daysForward).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
    }

    private var todayMeals: [MealEntry] {
        allMeals.filter { cal.isDateInToday($0.consumedAt) }
    }
    private func meals(_ slot: MealSlot, on day: Date) -> [MealEntry] {
        allMeals.filter { cal.isDate($0.consumedAt, inSameDayAs: day) && $0.mealSlot == slot }
    }
    /// Il `PlannedMeal` di quello slot/giorno, qualunque sia lo stato — non
    /// solo `.planned`: anche `.completed`/`.skipped` restano visibili (con
    /// lo switch) per poterli correggere, come nella `MealPlanView` pre-fusione.
    private func plan(_ slot: MealSlot, on day: Date) -> PlannedMeal? {
        allPlanned.first {
            cal.isDate($0.plannedDate, inSameDayAs: day) && $0.mealSlot == slot
        }
    }
    private var foodMap: [UUID: Food] { Dictionary(allFoods.map { ($0.id, $0) }) { a, _ in a } }
    /// Il conteggio calorie resta sempre quello di **oggi**, qualunque
    /// giorno sia selezionato nella striscia per pianificare/correggere.
    private var dayTotals: Macros {
        todayMeals.reduce(.zero) { $0 + $1.totals }
    }

    /// Obiettivo corrente (ADR-0019) o il default fisso se non ne è stato
    /// ancora impostato uno.
    private var goal: Macros {
        DietSync.current(goals)?.macros
            ?? Macros(kcal: DietGoal.kcal, proteinG: DietGoal.proteinG,
                      carbsG: DietGoal.carbsG, fatG: DietGoal.fatG)
    }
    /// Quota calorica del giorno = obiettivo di base + energia attiva HealthKit.
    private var dayCalorieTarget: Double {
        NutritionMath.dailyCalorieQuota(baseKcal: goal.kcal, activeEnergyKcal: activeEnergyKcal)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                summaryCard
                dayStrip
                VStack(spacing: 12) {
                    ForEach(MealSlot.allCases) { slot in mealRow(slot) }
                }
                GlassPrimaryButton(title: "Aggiungi alimento", systemImage: "plus", fill: Glass.amber,
                                   onInk: Color(red: 0.12, green: 0.06, blue: 0)) {
                    logSlot = defaultSlot()
                }
                .accessibilityIdentifier("addFood")
                TrackersCard(waterTargetMl: DietSync.current(goals)?.waterMlTarget)
            }
            .padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .glassScreen(.warm)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showRecipes) { RecipeListView() }
        .navigationDestination(isPresented: $showShopping) { ShoppingListView() }
        .navigationDestination(isPresented: $showTemplates) { DietTemplateEditorView() }
        .sheet(item: $logSlot) { slot in
            LogFoodView(slot: slot)
                .presentationDetents([.large])
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(item: $composeSlot) { slot in
            PlanMealSheet(day: selectedDay, slot: slot)
                .presentationDetents([.large])
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(item: $editingPlan) { p in
            PlanMealSheet(day: p.plannedDate, slot: p.mealSlot, existing: p)
                .presentationDetents([.large])
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showGoal) {
            NutritionGoalView()
                .presentationDetents([.large])
                .presentationBackground(.ultraThinMaterial)
        }
        .task {
            await DietSync.pullFoods(into: context)
            await DietSync.pullMealEntries(into: context)
            await DietSync.pullGoals(into: context)
            await DietSync.pullRecipes(into: context)
            // finestra allargata di ±1 giorno oltre la striscia: la GET usa
            // date UTC, la UI filtra poi per giorno locale.
            let from = cal.date(byAdding: .day, value: -1, to: week[0]) ?? week[0]
            let to = cal.date(byAdding: .day, value: 1, to: week[week.count - 1]) ?? week[0]
            await DietSync.pullPlannedMeals(from: from, to: to, into: context)
            await Outbox.flushOutbox(context)
            if HealthKitPreference.isEnabled() {
                activeEnergyKcal = await HealthKitService.shared.todayActiveEnergyKcal()
                latestWeightKg = await HealthKitService.shared.latestBodyWeightKg()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(isToday ? "Oggi"
                     : selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized)
                    .font(Glass.display(28, .bold)).tracking(-0.5)
                HStack(spacing: 8) {
                    Text(isToday ? Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized
                         : (selectedDay < today ? "Giorno passato" : "In programma"))
                        .font(Glass.body(14)).foregroundStyle(Glass.textSecondary)
                    if let w = latestWeightKg {
                        HStack(spacing: 3) {
                            Image(systemName: "heart.fill").font(.system(size: 9))
                                .foregroundStyle(Glass.coralLight)
                            Text("\(fmt(w)) kg").font(Glass.body(12, .semibold))
                                .foregroundStyle(Glass.ink.opacity(0.55))
                        }
                        .accessibilityIdentifier("healthWeightLabel")
                    }
                }
            }
            Spacer(minLength: 8)
            GlassIconButton(systemName: "cart") { showShopping = true }
                .accessibilityIdentifier("openShopping")
            GlassIconButton(systemName: "book.closed") { showRecipes = true }
                .accessibilityIdentifier("openRecipes")
            GlassIconButton(systemName: "calendar.badge.clock") { showTemplates = true }
                .accessibilityIdentifier("openTemplates")
            GlassIconButton(systemName: "target") { showGoal = true }
                .accessibilityIdentifier("editGoal")
        }
    }

    private var dayStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(week, id: \.self) { d in
                        let sel = cal.isDate(d, inSameDayAs: selectedDay)
                        let isPast = d < today
                        Button { selectedDay = d } label: {
                            VStack(spacing: 4) {
                                Text(d.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                                    .font(Glass.body(10, .bold)).tracking(0.5)
                                Text(d.formatted(.dateTime.day()))
                                    .font(Glass.display(17, .bold)).monospacedDigit()
                            }
                            .foregroundStyle(sel ? Color(red: 0.12, green: 0.06, blue: 0)
                                             : Glass.ink.opacity(isPast ? 0.4 : 0.6))
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
                        .id(d)
                        .accessibilityIdentifier("day_\(isoDay(d))")
                    }
                }
            }
            .onAppear { proxy.scrollTo(today, anchor: .center) }
        }
    }

    private var summaryCard: some View {
        let t = dayTotals
        let g = goal
        let targetKcal = dayCalorieTarget
        let frac = min(1, targetKcal > 0 ? t.kcal / targetKcal : 0)
        return VStack(spacing: 20) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.10), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: frac)
                    .stroke(Glass.amber, style: .init(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text(kcalString(t.kcal))
                        .font(Glass.display(36, .bold)).tracking(-0.5).monospacedDigit()
                    Text("di \(kcalString(targetKcal)) kcal")
                        .font(Glass.body(13)).foregroundStyle(Glass.ink.opacity(0.55))
                    if activeEnergyKcal >= 50 {
                        Text("+\(kcalString(min(activeEnergyKcal, 1200))) da attività")
                            .font(Glass.body(10, .semibold)).foregroundStyle(Glass.greenText)
                    }
                }
            }
            .frame(width: 180, height: 180)
            .padding(.top, 4)

            VStack(spacing: 14) {
                macroBar("Proteine", t.proteinG, g.proteinG, Glass.ink)
                macroBar("Carboidrati", t.carbsG, g.carbsG, Glass.ink.opacity(0.6))
                macroBar("Grassi", t.fatG, g.fatG, Glass.ink.opacity(0.6))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    private func macroBar(_ label: String, _ value: Double, _ target: Double, _ fill: Color) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(label).font(Glass.body(13, .semibold)).foregroundStyle(Glass.ink.opacity(0.7))
                Spacer()
                Text("\(Int(value.rounded())) / \(Int(target)) g")
                    .font(Glass.body(13)).foregroundStyle(Glass.ink.opacity(0.5)).monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.09))
                    Capsule().fill(fill)
                        .frame(width: geo.size.width * CGFloat(min(1, target > 0 ? value / target : 0)))
                }
            }
            .frame(height: 7)
        }
    }

    // MARK: - pasti (ex DietTabView.mealCard + MealPlanView.slotCard fusi, ADR-0036)

    private func mealRow(_ slot: MealSlot) -> some View {
        let entries = meals(slot, on: selectedDay)
        let items = entries.flatMap { $0.items }.sorted { $0.orderIndex < $1.orderIndex }
        let eaten = !items.isEmpty
        let kcal = items.reduce(0) { $0 + $1.calories }
        let planForSlot = plan(slot, on: selectedDay)
        let hasContent = eaten || planForSlot != nil
        let statusText = eaten ? "\(Int(kcal.rounded())) kcal"
            : (planForSlot != nil ? "pianificato" : "non pianificato")

        return VStack(spacing: 0) {
            mealRowHeader(slot, entries: entries, eaten: eaten, plan: planForSlot,
                         hasContent: hasContent, statusText: statusText)
            if eaten {
                loggedItemsList(items)
            } else if let planForSlot {
                plannedItemsList(planForSlot)
            }
        }
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.white.opacity(hasContent ? 0.12 : 0.08)))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private func mealRowHeader(_ slot: MealSlot, entries: [MealEntry], eaten: Bool, plan: PlannedMeal?,
                               hasContent: Bool, statusText: String) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: slot.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(hasContent ? Glass.amber : Glass.ink.opacity(0.4))
                Text(slot.label)
                    .font(Glass.display(16, .semibold))
                    .foregroundStyle(hasContent ? Glass.ink : Glass.ink.opacity(0.6))
                if let plan, !eaten {
                    Button { editingPlan = plan } label: {
                        Image(systemName: "pencil").font(.system(size: 11))
                            .foregroundStyle(Glass.ink.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("editPlanned_\(slot.rawValue)")
                }
                if let plan { statusPill(plan.status) }
            }
            Spacer()
            Text(statusText)
                .font(Glass.body(13))
                .foregroundStyle(Glass.ink.opacity(hasContent ? 0.5 : 0.35))
            if hasContent {
                Toggle("", isOn: Binding(
                    get: { eaten },
                    set: { newValue in
                        Task { @MainActor in
                            if newValue, let plan {
                                DietSync.completePlannedMeal(plan, foods: foodMap, in: context)
                            } else if !newValue {
                                for e in entries { DietSync.deleteMealEntry(e, in: context) }
                            }
                        }
                    }
                ))
                .labelsHidden()
                .tint(Glass.amber)
                .accessibilityIdentifier("mealEatenToggle_\(slot.rawValue)")
            } else {
                Button { composeSlot = slot } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Glass.ink.opacity(0.4))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("plan_\(slot.rawValue)")
            }
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 18).padding(.vertical, 16)
    }

    private func statusPill(_ s: PlanStatus) -> some View {
        let c: Color = s == .completed ? Glass.green : (s == .skipped ? Glass.ink.opacity(0.4) : Glass.amber)
        return Text(s.label.uppercased())
            .font(Glass.body(9, .bold)).tracking(0.5).foregroundStyle(c)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(c.opacity(0.15)))
            .overlay(Capsule().strokeBorder(c.opacity(0.35)))
    }

    private func loggedItemsList(_ items: [MealEntryItem]) -> some View {
        VStack(spacing: 1) {
            ForEach(items) { it in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: [Glass.amber.opacity(0.85), Glass.amber.opacity(0.4)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                        .overlay(Image(systemName: "fork.knife")
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(.white))
                    Text(it.foodName).font(Glass.body(14)).foregroundStyle(Glass.ink.opacity(0.85))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("\(Int(it.quantityG))g")
                        .font(Glass.body(11)).foregroundStyle(Glass.ink.opacity(0.35))
                    Text("\(Int(it.calories.rounded())) kcal")
                        .font(Glass.body(13)).foregroundStyle(Glass.ink.opacity(0.45))
                }
                .padding(.horizontal, 18).padding(.vertical, 11)
                .background(Color.white.opacity(0.02))
            }
        }
        .background(Color.white.opacity(0.05))
    }

    private func plannedItemsList(_ plan: PlannedMeal) -> some View {
        VStack(spacing: 1) {
            ForEach(plan.items.sorted { $0.orderIndex < $1.orderIndex }) { it in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Glass.amber.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 32, height: 32)
                        .overlay(Image(systemName: "fork.knife")
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(Glass.amber.opacity(0.7)))
                    Text(it.foodName).font(Glass.body(14)).foregroundStyle(Glass.ink.opacity(0.6))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("\(Int(it.quantityG))g")
                        .font(Glass.body(11)).foregroundStyle(Glass.ink.opacity(0.3))
                }
                .padding(.horizontal, 18).padding(.vertical, 11)
                .background(Color.white.opacity(0.02))
            }
        }
        .background(Color.white.opacity(0.05))
    }

    private func kcalString(_ v: Double) -> String {
        let n = Int(v.rounded())
        return n >= 1000 ? "\(n / 1000).\(String(format: "%03d", n % 1000))" : "\(n)"
    }
    private func fmt(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }
    private func isoDay(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        return f.string(from: d)
    }

    private func defaultSlot() -> MealSlot {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<9: return .breakfast
        case 9..<11: return .morningSnack
        case 11..<15: return .lunch
        case 15..<18: return .afternoonSnack
        case 18..<23: return .dinner
        default: return .breakfast
        }
    }
}
