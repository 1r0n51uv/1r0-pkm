//
//  LogFoodView.swift
//  1r0-pkm · Modules/1r0-diet
//
//  Sheet "Aggiungi alimento" (ADR-0017 slice 1): scegli lo slot, cerca un
//  alimento a catalogo (o creane uno custom), imposta i grammi con
//  anteprima macro live, logga. Layout dai mockup "GlassFoodSearch" +
//  "GlassMealLog" — accento ambra. Barcode/OpenFoodFacts: ADR-0018.
//

import SwiftUI
import SwiftData

struct LogFoodView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Food.name) private var foods: [Food]

    @State var slot: MealSlot
    @State private var search = ""
    @State private var picked: Food?
    @State private var grams: Double = 100
    @State private var showAddFood = false

    private var filtered: [Food] {
        let q = search.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return foods }
        return foods.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    slotPicker
                    GlassField(placeholder: "Cerca un alimento…", text: $search,
                               identifier: "foodSearch")

                    if filtered.isEmpty {
                        Text(foods.isEmpty ? "Nessun alimento a catalogo." : "Nessun risultato.")
                            .font(Glass.body(13)).foregroundStyle(Glass.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(filtered) { foodRow($0) }
                        }
                    }

                    Button { showAddFood = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("Crea alimento personalizzato")
                        }
                        .font(Glass.body(14, .semibold)).foregroundStyle(Glass.ink.opacity(0.65))
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.04)))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("createFood")
                    .padding(.bottom, picked == nil ? 12 : 220)
                }
                .padding(.horizontal, 22).padding(.top, 4)
            }
            .scrollIndicators(.hidden)
        }
        .glassScreen(.warm)
        .overlay(alignment: .bottom) { if picked != nil { composeCard } }
        .sheet(isPresented: $showAddFood) {
            AddFoodView { newFood in picked = newFood; grams = newFood.servingSizeG ?? 100 }
                .presentationDetents([.large])
                .presentationBackground(.ultraThinMaterial)
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
            Text("Aggiungi alimento").font(Glass.display(16, .semibold))
            Spacer()
            Text(slot.label).font(Glass.body(13, .semibold)).foregroundStyle(Glass.ink.opacity(0.5))
                .frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 4)
    }

    private var slotPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MealSlot.allCases) { s in
                    GlassChip(label: s.label, selected: slot == s, tint: Glass.amber) { slot = s }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func foodRow(_ f: Food) -> some View {
        let selected = picked?.id == f.id
        return Button {
            picked = f
            grams = f.servingSizeG ?? 100
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(LinearGradient(colors: [Glass.amber.opacity(0.85), Glass.amber.opacity(0.4)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 40, height: 40)
                    .overlay(Image(systemName: "fork.knife")
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 2) {
                    Text(f.name).font(Glass.body(14, .semibold)).lineLimit(1)
                    Text("\(Int(f.caloriesPer100g.rounded())) kcal / 100 g · \(sourceLabel(f.source))")
                        .font(Glass.body(12)).foregroundStyle(Glass.ink.opacity(0.45)).lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: selected ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(selected ? Glass.amber : Glass.ink.opacity(0.35))
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(selected ? Glass.amber.opacity(0.5) : Color.white.opacity(0.12),
                              lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    private var composeCard: some View {
        let f = picked!
        let mac = f.macros(forGrams: grams)
        return VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(f.name).font(Glass.display(16, .semibold)).lineLimit(1)
                    Text("\(Int(f.caloriesPer100g.rounded())) kcal / 100 g")
                        .font(Glass.body(12)).foregroundStyle(Glass.ink.opacity(0.45))
                }
                Spacer()
                HStack(spacing: 8) {
                    stepBtn("minus") { grams = max(5, grams - 10) }
                    Text("\(Int(grams)) g")
                        .font(Glass.display(16, .bold)).monospacedDigit()
                        .frame(minWidth: 44)
                        .accessibilityIdentifier("grams")
                    stepBtn("plus") { grams += 10 }
                }
                .padding(4)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            HStack {
                macroStat("\(Int(mac.kcal.rounded()))", "kcal")
                macroStat("\(Int(mac.proteinG.rounded()))g", "proteine")
                macroStat("\(Int(mac.carbsG.rounded()))g", "carbo")
                macroStat("\(Int(mac.fatG.rounded()))g", "grassi")
            }
            GlassPrimaryButton(title: "Aggiungi al pasto", systemImage: "checkmark",
                               fill: Glass.amber, onInk: Color(red: 0.12, green: 0.06, blue: 0)) {
                DietSync.logMeal(slot: slot, items: [(f, grams)], in: context)
                dismiss()
            }
            .accessibilityIdentifier("addToMeal")
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Color.white.opacity(0.16)))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 20, y: -8)
        .padding(.horizontal, 16).padding(.bottom, 12)
    }

    private func stepBtn(_ name: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 13, weight: .bold)).foregroundStyle(Glass.ink)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func macroStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Glass.display(16, .bold)).monospacedDigit()
            Text(label).font(Glass.body(11)).foregroundStyle(Glass.ink.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
    }

    private func sourceLabel(_ s: String) -> String {
        switch s {
        case "openfoodfacts": return "OpenFoodFacts"
        case "usda": return "USDA"
        default: return "Creato da te"
        }
    }
}
