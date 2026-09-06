//
//  ContentView.swift
//  1r0-pkm
//
//  Shell di navigazione. Per ora il modulo 1r0-gym espone il catalogo
//  esercizi; le altre tab (sessione, progressi, schede…) arrivano dopo.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ExerciseListView()
        }
        .tint(Glass.accent)
    }
}
