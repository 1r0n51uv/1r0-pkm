//
//  ContentView.swift
//  1r0-pkm
//
//  Created by 1r0n51uv on 05/09/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var connector: PhoneConnector

    var body: some View {
        VStack(spacing: 20) {
            Text("1r0-pkm — Watch spike")
                .font(.title2).bold()

            VStack(spacing: 6) {
                Text("Ultimo messaggio dal Watch:")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(connector.lastReceivedMessage)
                    .font(.body)
                if connector.receivedCount > 0 {
                    Text("ricevuti: \(connector.receivedCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Button("Invia \"Ciao\" al Watch") {
                connector.sendHelloToWatch()
            }
            .buttonStyle(.borderedProminent)

            Text(connector.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .environmentObject(PhoneConnector.shared)
}
