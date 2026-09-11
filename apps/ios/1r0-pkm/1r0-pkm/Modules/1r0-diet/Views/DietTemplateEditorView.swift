//
//  DietTemplateEditorView.swift
//  1r0-pkm · Modules/1r0-diet/Views
//
//  Dieta settimanale a template (ADR-0029): un template assegna una ricetta
//  per ciascuno dei 5 slot (ADR-0024) di ciascun giorno; "Applica" lo traduce
//  in `PlannedMeal` per una settimana specifica (`DietSync.applyTemplate`).
//  Reso da `MealPlanView` (icona "calendar.badge.clock").
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
                                        Text("\(t.items.filter { $0.recipeId != nil }.count) pasti assegnati")
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
            RecipePickerSheet(recipes: recipes, current: template.item(weekday: target.weekday, slot: target.slot)?.recipeId) { picked in
                assign(picked, weekday: target.weekday, slot: target.slot)
            }
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
        return Button { pickerFor = (weekday, slot) } label: {
            HStack(spacing: 10) {
                Image(systemName: slot.systemImage).font(.system(size: 12))
                    .foregroundStyle(item?.recipeId != nil ? Glass.amber : Glass.ink.opacity(0.35))
                    .frame(width: 18)
                Text(slot.label).font(Glass.body(12, .semibold)).foregroundStyle(Glass.textSecondary)
                    .frame(width: 130, alignment: .leading)
                Text(item?.recipeName ?? "—")
                    .font(Glass.body(13)).foregroundStyle(item?.recipeName != nil ? Glass.textPrimary : Glass.textFaint)
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

    private func assign(_ recipe: Recipe?, weekday: Int, slot: MealSlot) {
        if let existing = template.item(weekday: weekday, slot: slot) {
            existing.recipeId = recipe?.id
            existing.recipeName = recipe?.name
        } else {
            let it = DietTemplateItem(template: template, weekday: weekday, mealSlot: slot,
                                      recipeId: recipe?.id, recipeName: recipe?.name)
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

/// Sheet minimale: scegli una ricetta o "Nessuna" per svuotare lo slot.
private struct RecipePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let recipes: [Recipe]
    let current: UUID?
    let onPick: (Recipe?) -> Void

    var body: some View {
        NavigationStack {
            List {
                Button {
                    onPick(nil); dismiss()
                } label: {
                    HStack { Text("Nessuna"); Spacer(); if current == nil { Image(systemName: "checkmark") } }
                }
                ForEach(recipes) { r in
                    Button {
                        onPick(r); dismiss()
                    } label: {
                        HStack { Text(r.name); Spacer(); if current == r.id { Image(systemName: "checkmark") } }
                    }
                }
            }
            .navigationTitle("Scegli ricetta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
}
