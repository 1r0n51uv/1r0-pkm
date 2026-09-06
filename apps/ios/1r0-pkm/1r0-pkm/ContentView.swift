//
//  ContentView.swift
//  1r0-pkm
//
//  Shell a tab del modulo 1r0-gym. Altre tab (sessione, progressi…) dopo.
//

import SwiftUI

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
        .onAppear {
            let a = UITabBarAppearance()
            a.configureWithTransparentBackground()
            a.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
            UITabBar.appearance().standardAppearance = a
            UITabBar.appearance().scrollEdgeAppearance = a
        }
    }
}
