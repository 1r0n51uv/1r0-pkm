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
    @State private var logSlot: MealSlot?
    @State private var showGoal = false
    @State private var showReport = false
    @State private var showPlan = false

    private var today: [MealEntry] {
        allMeals.filter { Calendar.current.isDateInToday($0.consumedAt) }
    }
    private func meals(_ slot: MealSlot) -> [MealEntry] {
        today.filter { $0.mealSlot == slot }
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
        .sheet(isPresented: $showReport) {
            DietReportView()
                .presentationDetents([.large])
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showPlan) {
            MealPlanView()
                .presentationDetents([.large])
                .presentationBackground(.ultraThinMaterial)
        }
        .task {
            await DietSync.pullFoods(into: context)
            await DietSync.pullMealEntries(into: context)
            await DietSync.pullGoals(into: context)
            await GymSync.flushOutbox(context)
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
            GlassIconButton(systemName: "chart.line.uptrend.xyaxis") { showReport = true }
                .accessibilityIdentifier("showReport")
            GlassIconButton(systemName: "target") { showGoal = true }
                .accessibilityIdentifier("editGoal")
        }
    }

    private var summaryCard: some View {
        let t = dayTotals
        let g = goal
        let frac = min(1, g.kcal > 0 ? t.kcal / g.kcal : 0)
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
                    Text("di \(kcalString(g.kcal)) kcal")
                        .font(Glass.body(13)).foregroundStyle(Glass.ink.opacity(0.55))
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

        return VStack(spacing: 0) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: slot.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(logged ? Glass.amber : Glass.ink.opacity(0.4))
                    Text(slot.label)
                        .font(Glass.display(16, .semibold))
                        .foregroundStyle(logged ? Glass.ink : Glass.ink.opacity(0.6))
                }
                Spacer()
                Text(logged ? "\(Int(kcal.rounded())) kcal" : "non ancora loggato")
                    .font(Glass.body(13))
                    .foregroundStyle(Glass.ink.opacity(logged ? 0.5 : 0.35))
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Glass.ink.opacity(0.4))
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 18).padding(.vertical, 16)
            .onTapGesture { logSlot = slot }

            if logged {
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
        }
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.white.opacity(logged ? 0.12 : 0.08)))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func kcalString(_ v: Double) -> String {
        let n = Int(v.rounded())
        return n >= 1000 ? "\(n / 1000).\(String(format: "%03d", n % 1000))" : "\(n)"
    }

    private func defaultSlot() -> MealSlot {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<11: return .breakfast
        case 11..<15: return .lunch
        case 18..<23: return .dinner
        default: return .snack
        }
    }
}
