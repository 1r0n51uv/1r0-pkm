//
//  AddFoodView.swift
//  1r0-pkm · Modules/1r0-diet
//
//  Crea un alimento custom (ADR-0017/0018 `source = "custom"`): nome +
//  kcal/macro per 100 g. Offline-first: insert locale + OutboxEntry
//  "food.create". Stile Glass Dark — accento ambra.
//

import SwiftUI
import SwiftData

struct AddFoodView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    /// Chiamato col Food creato, così il chiamante può selezionarlo subito.
    var onCreated: (Food) -> Void = { _ in }

    @State private var name = ""
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""

    private func num(_ s: String) -> Double? {
        Double(s.replacingOccurrences(of: ",", with: "."))
    }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (num(kcal) ?? 0) > 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Nuovo alimento")
                    .font(Glass.display(24, .bold)).padding(.top, 8)

                field("NOME", text: $name, placeholder: "Petto di pollo alla griglia",
                      id: "foodName", keyboard: .default)

                Text("VALORI PER 100 g")
                    .font(Glass.body(11, .semibold)).tracking(0.6)
                    .foregroundStyle(Glass.textSecondary).padding(.top, 4)

                field("KCAL", text: $kcal, placeholder: "165", id: "foodKcal", keyboard: .decimalPad)
                HStack(spacing: 12) {
                    field("PROTEINE (g)", text: $protein, placeholder: "31", id: "foodProtein", keyboard: .decimalPad)
                    field("CARBO (g)", text: $carbs, placeholder: "0", id: "foodCarbs", keyboard: .decimalPad)
                }
                field("GRASSI (g)", text: $fat, placeholder: "3.6", id: "foodFat", keyboard: .decimalPad)

                GlassPrimaryButton(title: "Salva", fill: Glass.amber,
                                   onInk: Color(red: 0.12, green: 0.06, blue: 0), action: save)
                    .opacity(canSave ? 1 : 0.4)
                    .disabled(!canSave)
                    .accessibilityIdentifier("saveFood")
                    .padding(.top, 4)
            }
            .padding(20)
        }
        .glassScreen(.warm)
        .scrollDismissesKeyboard(.immediately)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fatto") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .accessibilityIdentifier("kbDone")
            }
        }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String,
                       id: String, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(Glass.body(11, .semibold)).tracking(0.6).foregroundStyle(Glass.textSecondary)
            TextField("", text: text, prompt: Text(placeholder).foregroundColor(Glass.textSecondary))
                .font(Glass.body(16))
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .padding(14)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.12)))
                .accessibilityIdentifier(id)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @MainActor
    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let f = DietSync.createFood(
            name: trimmed,
            kcal: num(kcal) ?? 0,
            protein: num(protein) ?? 0,
            carbs: num(carbs) ?? 0,
            fat: num(fat) ?? 0,
            in: context
        )
        onCreated(f)
        dismiss()
    }
}
