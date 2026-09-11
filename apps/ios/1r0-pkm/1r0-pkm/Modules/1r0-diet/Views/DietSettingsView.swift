//
//  DietSettingsView.swift
//  1r0-pkm · Modules/1r0-diet/Views
//
//  Tab "Impostazioni" (ADR-0031, era un sheet dall'header Dieta, ADR-0029):
//  prima voce il collegamento esplicito ad Apple Salute (`HealthKitPreference`,
//  separato dal permesso di sistema), poi le notifiche — un interruttore per
//  categoria di Promemoria, non per singola istanza (ADR-0027) — l'accesso
//  all'andamento (ADR-0020) e, in fondo, il database backend (ADR-0034).
//

import SwiftUI

struct DietSettingsView: View {
    private let reminderSettings = ReminderSettings()

    @State private var healthKitOn = false
    @State private var healthKitBusy = false
    @State private var missingMeal = true
    @State private var water = true
    @State private var useDevDB = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Impostazioni").font(Glass.display(24, .bold)).padding(.top, 4)

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Salute")
                    healthRow
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Notifiche")
                    Text("Promemoria locali, valutati sui dati già presenti.")
                        .font(Glass.body(13)).foregroundStyle(Glass.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    toggleRow("Pasto mancante", "Ti avvisa se non hai segnato un pasto "
                        + "entro il suo orario.", isOn: $missingMeal)
                    toggleRow("Acqua", "Ti avvisa se sei sotto la quota d'acqua della "
                        + "giornata.", isOn: $water)
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Report")
                    NavigationLink {
                        DietReportView()
                    } label: {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundStyle(Glass.amber)
                            Text("Andamento").font(Glass.body(15, .semibold)).foregroundStyle(Glass.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Glass.textFaint)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("openReport")
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Database")
                    dbTargetRow
                }
            }
            .padding(.horizontal, 22).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .glassScreen(.warm)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            healthKitOn = HealthKitPreference.isEnabled()
            missingMeal = reminderSettings.isEnabled(.missingMeal)
            water = reminderSettings.isEnabled(.water)
            useDevDB = DBTargetPreference.isDevEnabled()
        }
        .onChange(of: missingMeal) { _, v in
            reminderSettings.setEnabled(v, for: .missingMeal)
            RemindersEngine.shared.refresh()
        }
        .onChange(of: water) { _, v in
            reminderSettings.setEnabled(v, for: .water)
            RemindersEngine.shared.refresh()
        }
    }

    /// ADR-0034: instrada le chiamate al backend verso il database di
    /// sviluppo/test invece di quello di produzione (`X-Db-Target: dev`,
    /// `ApiClient`). Non svuota la cache locale — i dati dell'altro
    /// database restano mescolati finché l'app non riparte da uno store
    /// pulito.
    private var dbTargetRow: some View {
        Toggle(isOn: Binding(
            get: { useDevDB },
            set: { newValue in
                useDevDB = newValue
                DBTargetPreference.setDevEnabled(newValue)
            }
        )) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Usa database di sviluppo").font(Glass.body(15, .semibold))
                Text(useDevDB
                     ? "Attivo: le sincronizzazioni usano i dati di test, non quelli reali."
                     : "Spento: le sincronizzazioni usano i dati reali di produzione.")
                    .font(Glass.body(12)).foregroundStyle(Glass.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(Glass.amber)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.05)))
        .accessibilityIdentifier("devDBToggle")
    }

    private var healthRow: some View {
        Toggle(isOn: Binding(
            get: { healthKitOn },
            set: { newValue in
                healthKitOn = newValue
                HealthKitPreference.setEnabled(newValue)
                if newValue {
                    healthKitBusy = true
                    Task {
                        _ = await HealthKitService.shared.requestAuthorization()
                        healthKitBusy = false
                    }
                }
            }
        )) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Collega Apple Salute").font(Glass.body(15, .semibold))
                Text(healthKitBusy ? "Richiesta permessi…"
                     : "Scrive energia/macro dei pasti; legge acqua ed energia attiva "
                       + "per la quota del giorno e il promemoria acqua.")
                    .font(Glass.body(12)).foregroundStyle(Glass.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(Glass.green)
        .disabled(healthKitBusy)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.05)))
        .accessibilityIdentifier("healthKitToggle")
    }

    private func toggleRow(_ title: String, _ subtitle: String, isOn: Binding<Bool>) -> some View {
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
