//
//  ContentView.swift
//  1r0-pkm-w Watch App
//
//  Created by 1r0n51uv on 05/09/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var connector: WatchConnector

    var body: some View {
        VStack(spacing: 10) {
            Text(connector.lastReceivedMessage)
                .font(.footnote)
                .multilineTextAlignment(.center)
            if connector.receivedCount > 0 {
                Text("ricevuti: \(connector.receivedCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button("Invia a iPhone") {
                connector.sendHelloToPhone()
            }

            Button("Logga set (100kg × 5)") {
                connector.sendTestSetLog()
            }

            Text(connector.statusText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchConnector.shared)
}
