import SwiftUI

struct ContentView: View {
    @StateObject private var connector = PhoneConnector.shared

    var body: some View {
        VStack(spacing: 20) {
            Text("1r0 — Watch spike")
                .font(.title2).bold()

            VStack(spacing: 6) {
                Text("Ultimo messaggio dal Watch:")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(connector.lastReceivedMessage)
                    .font(.body)
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
}
