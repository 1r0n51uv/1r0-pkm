import SwiftUI

struct WatchContentView: View {
    @StateObject private var connector = WatchConnector.shared

    var body: some View {
        VStack(spacing: 10) {
            Text(connector.lastReceivedMessage)
                .font(.footnote)
                .multilineTextAlignment(.center)

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
}
