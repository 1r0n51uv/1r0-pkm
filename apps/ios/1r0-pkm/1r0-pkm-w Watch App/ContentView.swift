//
//  ContentView.swift
//  1r0-pkm-w Watch App
//
//  Placeholder — il log sessione da Watch (ADR-0016) si costruirà qui sul
//  trasporto WatchConnector già validato.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var connector: WatchConnector

    var body: some View {
        VStack(spacing: 8) {
            Text("1r0-gym")
                .font(.headline)
            Text(connector.isActivated ? "pronto" : "connessione…")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView().environmentObject(WatchConnector.shared)
}
