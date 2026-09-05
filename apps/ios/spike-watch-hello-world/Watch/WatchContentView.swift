import SwiftUI

struct WatchContentView: View {
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

            Text(connector.statusText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    WatchContentView()
        .environmentObject(WatchConnector.shared)
}
