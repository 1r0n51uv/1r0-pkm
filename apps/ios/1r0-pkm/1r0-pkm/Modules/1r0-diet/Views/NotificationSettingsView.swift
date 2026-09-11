//
//  NotificationSettingsView.swift
//  1r0-pkm · Modules/1r0-diet/Views
//
//  Impostazioni notifiche (glossario): un interruttore per categoria di
//  Promemoria, non per singola istanza (ADR-0027). Scrive `ReminderSettings`
//  (UserDefaults) e chiede al motore di riconciliare.
//

import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    private let settings = ReminderSettings()

    @State private var missingMeal = true
    @State private var water = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Notifiche").font(Glass.display(24, .bold)).padding(.top, 4)
                Text("Promemoria locali, valutati sui dati già presenti. "
                     + "Puoi spegnere una categoria qui.")
                    .font(Glass.body(13)).foregroundStyle(Glass.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                row("Pasto mancante", "Ti avvisa se non hai segnato un pasto "
                    + "entro il suo orario.", isOn: $missingMeal)
                row("Acqua", "Ti avvisa se sei sotto la quota d'acqua della "
                    + "giornata.", isOn: $water)
            }
            .padding(.horizontal, 22).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .glassScreen(.warm)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Fine") { dismiss() }.font(Glass.body(14, .bold))
            }
        }
        .onAppear {
            missingMeal = settings.isEnabled(.missingMeal)
            water = settings.isEnabled(.water)
        }
        .onChange(of: missingMeal) { _, v in
            settings.setEnabled(v, for: .missingMeal)
            RemindersEngine.shared.refresh()
        }
        .onChange(of: water) { _, v in
            settings.setEnabled(v, for: .water)
            RemindersEngine.shared.refresh()
        }
    }

    private func row(_ title: String, _ subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Glass.body(15, .semibold))
                Text(subtitle).font(Glass.body(12)).foregroundStyle(Glass.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(Glass.green)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.05)))
    }
}
