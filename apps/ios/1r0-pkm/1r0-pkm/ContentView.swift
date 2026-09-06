//
//  ContentView.swift
//  1r0-pkm
//
//  Shell a tab del modulo 1r0-gym. Altre tab (sessione, progressi…) dopo.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack { SessionTabView() }
                .tabItem { Label("Sessione", systemImage: "figure.strengthtraining.traditional") }

            NavigationStack { RoutineListView() }
                .tabItem { Label("Schede", systemImage: "square.stack.3d.up") }

            NavigationStack { ExerciseListView() }
                .tabItem { Label("Catalogo", systemImage: "dumbbell") }

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
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                Text("\(failed.count) modifiche non sincronizzate")
                    .font(Glass.body(13, .medium))
                Spacer(minLength: 8)
                Button {
                    retrying = true
                    let ctx = context
                    Task {
                        await GymSync.retryFailed(ctx)
                        retrying = false
                    }
                } label: {
                    Text(retrying ? "…" : "Riprova").font(Glass.body(13, .semibold))
                }
                .disabled(retrying)
            }
            .foregroundStyle(Glass.textPrimary)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Glass.accent2.opacity(0.22), in: Capsule())
            .overlay(Capsule().strokeBorder(Glass.accent2.opacity(0.45)))
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.snappy, value: failed.count)
        }
    }
}
