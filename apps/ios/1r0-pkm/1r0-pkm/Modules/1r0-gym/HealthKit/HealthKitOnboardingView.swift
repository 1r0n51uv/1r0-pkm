//
//  HealthKitOnboardingView.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Spiega perché servono i permessi HealthKit (ADR-0004) prima di
//  richiederli. Stile Glass Dark.
//

import SwiftUI

struct HealthKitOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    /// chiamata dopo la richiesta permessi (true = richiesta completata)
    var onDone: (Bool) -> Void = { _ in }
    @State private var requesting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Apple Salute")
                    .font(Glass.display(26, .bold)).padding(.top, 8)

                row("scalemass",
                    "1r0-gym legge il peso corporeo più recente da Salute per l'andamento nei Progressi.")
                row("lock.shield",
                    "Solo questi dati, niente altro. Puoi revocare i permessi da Impostazioni → Salute.")

                Button {
                    Task {
                        requesting = true
                        let ok = await HealthKitService.shared.requestAuthorization()
                        requesting = false
                        onDone(ok)
                        dismiss()
                    }
                } label: {
                    Text(requesting ? "…" : "Consenti")
                        .font(Glass.body(16, .semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(LinearGradient(colors: [Glass.accent, Glass.accent2],
                                                  startPoint: .leading, endPoint: .trailing),
                                   in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white)
                }
                .disabled(requesting || !HealthKitService.shared.isAvailable)
                .accessibilityIdentifier("healthAllow")

                if !HealthKitService.shared.isAvailable {
                    Text("HealthKit non è disponibile su questo dispositivo.")
                        .font(Glass.body(12)).foregroundStyle(Glass.accent2)
                }
            }
            .padding(20)
        }
        .glassScreen()
    }

    private func row(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Glass.accent)
                .frame(width: 26)
            Text(text).font(Glass.body(14)).foregroundStyle(Glass.textPrimary)
        }
    }
}
