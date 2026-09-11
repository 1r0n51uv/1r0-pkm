//
//  DietTabView.swift
//  1r0-pkm · Modules/1r0-diet
//
//  Dashboard giornaliera del modulo dieta (ADR-0017 slice 1): anello
//  calorie, barre macro, pasti della giornata. Stile Glass Dark (ADR-0023),
//  layout dal mockup "GlassDiet" — accento ambra.
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

struct DietTabView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MealEntry.consumedAt, order: .reverse) private var allMeals: [MealEntry]
    @Query(sort: \NutritionGoal.effectiveFrom, order: .reverse) private var goals: [NutritionGoal]
    @Query(sort: \PlannedMeal.plannedDate) private var allPlanned: [PlannedMeal]
    @Query private var allFoods: [Food]
    @State private var logSlot: MealSlot?
    @State private var showGoal = false
    @State private var showPlan = false
    @State private var showSettings = false
    @State private var showReport = false
    @State private var openReportAfterSettings = false
    /// Energia attiva di oggi da HealthKit (ADR-0019 amendata): alza la quota
    /// calorica del giorno senza toccare `nutrition_goals`.
    @State private var activeEnergyKcal: Double = 0

    private var today: [MealEntry] {
        allMeals.filter { Calendar.current.isDateInToday($0.consumedAt) }
    }
    private func meals(_ slot: MealSlot) -> [MealEntry] {
        today.filter { $0.mealSlot == slot }
    }
    private var foodMap: [UUID: Food] { Dictionary(allFoods.map { ($0.id, $0) }) { a, _ in a } }
    /// Pasto pianificato per oggi non ancora mangiato (ADR-0029: dieta
    /// settimanale a template). `nil` se non pianificato o già confermato.
    private func plannedToday(_ slot: MealSlot) -> PlannedMeal? {
        allPlanned.first {
            Calendar.current.isDateInToday($0.plannedDate) && $0.mealSlot == slot && $0.status == .planned
        }
    }
    private var dayTotals: Macros {
        today.reduce(.zero) { $0 + $1.totals }
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
                VStack(spacing: 12) {
                    ForEach(MealSlot.allCases) { slot in mealCard(slot) }
                }
                TrackersCard(waterTargetMl: DietSync.current(goals)?.waterMlTarget)
                GlassPrimaryButton(title: "Aggiungi alimento", systemImage: "plus",
                                   fill: Glass.amber, onInk: Color(red: 0.12, green: 0.06, blue: 0),
                                   height: 56) {
                    logSlot = defaultSlot()
                }
                .accessibilityIdentifier("addFood")
            }
            .padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .glassScreen(.warm)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $logSlot) { slot in
            LogFoodView(slot: slot)
                .presentationDetents([.large])
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showGoal) {
            NutritionGoalView()
                .presentationDetents([.large])
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showPlan) {
            MealPlanView()
                .presentationDetents([.large])
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showSettings, onDismiss: {
            // il Report si apre solo a chiusura completata di Impostazioni:
            // due `.sheet` in successione immediata ha un dismiss() rotto
            // (nota XCUITest), un NavigationLink push dentro il sheet
            // impiccava il runloop dei test (Andamento mai raggiunto).
            if openReportAfterSettings {
                openReportAfterSettings = false
                showReport = true
            }
        }) {
            NavigationStack {
                DietSettingsView(onOpenReport: { openReportAfterSettings = true })
            }
            .presentationDetents([.large])
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showReport) {
            DietReportView()
                .presentationDetents([.large])
                .presentationBackground(.ultraThinMaterial)
        }
        .task {
            await DietSync.pullFoods(into: context)
            await DietSync.pullMealEntries(into: context)
            await DietSync.pullGoals(into: context)
            await Outbox.flushOutbox(context)
            if HealthKitPreference.isEnabled() {
                activeEnergyKcal = await HealthKitService.shared.todayActiveEnergyKcal()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Oggi")
                    .font(Glass.display(28, .bold)).tracking(-0.5)
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized)
                    .font(Glass.body(14)).foregroundStyle(Glass.textSecondary)
            }
            Spacer(minLength: 8)
            GlassIconButton(systemName: "calendar") { showPlan = true }
                .accessibilityIdentifier("openPlan")
            GlassIconButton(systemName: "target") { showGoal = true }
                .accessibilityIdentifier("editGoal")
            GlassIconButton(systemName: "gearshape") { showSettings = true }
                .accessibilityIdentifier("dietSettings")
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

    private func mealCard(_ slot: MealSlot) -> some View {
        let entries = meals(slot)
        let items = entries.flatMap { $0.items }.sorted { $0.orderIndex < $1.orderIndex }
        let kcal = items.reduce(0) { $0 + $1.calories }
        let logged = !items.isEmpty
        let plan = logged ? nil : plannedToday(slot)
        let statusText: String = {
            if logged { return "\(Int(kcal.rounded())) kcal" }
            if plan != nil { return "pianificato" }
            return "non ancora loggato"
        }()
        let highlighted = logged || plan != nil

        return VStack(spacing: 0) {
            mealCardHeader(slot, logged: logged, plan: plan, highlighted: highlighted, statusText: statusText)
            if logged {
                loggedItemsList(items)
            } else if let plan {
                plannedItemsList(plan)
            }
        }
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.white.opacity(highlighted ? 0.12 : 0.08)))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private func mealCardHeader(_ slot: MealSlot, logged: Bool, plan: PlannedMeal?, highlighted: Bool, statusText: String) -> some View {
        HStack {
            HStack(spacing: 10) {
                if let plan {
                    Button {
                        Task { @MainActor in
                            DietSync.completePlannedMeal(plan, foods: foodMap, in: context)
                        }
                    } label: {
                        Image(systemName: "circle")
                            .font(.system(size: 18)).foregroundStyle(Glass.amber)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("checkPlanned_\(slot.rawValue)")
                } else {
                    Image(systemName: slot.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(logged ? Glass.amber : Glass.ink.opacity(0.4))
                }
                Text(slot.label)
                    .font(Glass.display(16, .semibold))
                    .foregroundStyle(highlighted ? Glass.ink : Glass.ink.opacity(0.6))
            }
            Spacer()
            Text(statusText)
                .font(Glass.body(13))
                .foregroundStyle(Glass.ink.opacity(highlighted ? 0.5 : 0.35))
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Glass.ink.opacity(0.4))
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 18).padding(.vertical, 16)
        .onTapGesture { logSlot = slot }
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
