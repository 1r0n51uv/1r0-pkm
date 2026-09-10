//
//  ContentView.swift
//  1r0-pkm
//
//  Shell a tab (ADR-0008): 1r0-gym come **Palestra** (storico + grafici degli
//  allenamenti importati da Liftin', ADR-0027) e **Progressi** (peso/misure,
//  ADR-0012), 1r0-diet come **Dieta** (ADR-0017).
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack { GymHistoryView() }
                .tabItem { Label("Palestra", systemImage: "figure.strengthtraining.traditional") }

            NavigationStack { DietTabView() }
                .tabItem { Label("Dieta", systemImage: "fork.knife") }

            NavigationStack { ProgressTabView() }
                .tabItem { Label("Progressi", systemImage: "chart.xyaxis.line") }
        }
        .tint(Glass.accent)
        .preferredColorScheme(.dark)
        .overlay(alignment: .top) { SyncFailureBanner() }
        .onAppear {
            let a = UITabBarAppearance()
            a.configureWithTransparentBackground()
            a.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
            UITabBar.appearance().standardAppearance = a
            UITabBar.appearance().scrollEdgeAppearance = a
        }
    }
}

/// Banner globale quando l'outbox ha entry parcheggiate (4xx o troppi
/// tentativi, ADR-0006). "Riprova" le rimette in coda.
private struct SyncFailureBanner: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<OutboxEntry> { $0.failedPermanently })
    private var failed: [OutboxEntry]
    @State private var retrying = false

    var body: some View {
        if !failed.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Glass.amber)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(failed.count) modifiche non sincronizzate")
                        .font(Glass.body(13, .semibold))
                    Text("Verranno reinviate al ritorno della rete")
                        .font(Glass.body(11)).foregroundStyle(Glass.ink.opacity(0.5))
                }
                Spacer(minLength: 8)
                Button {
                    retrying = true
                    let ctx = context
                    Task {
                        await Outbox.retryFailed(ctx)
                        retrying = false
                    }
                } label: {
                    Text(retrying ? "…" : "Riprova")
                        .font(Glass.body(12, .bold)).foregroundStyle(Glass.amberText)
                }
                .disabled(retrying)
            }
            .foregroundStyle(Glass.textPrimary)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Glass.amber.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Glass.amber.opacity(0.35)))
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.snappy, value: failed.count)
        }
    }
}
