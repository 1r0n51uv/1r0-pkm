import SwiftUI

@main
struct OneRoSpikeApp: App {
    // Activate WatchConnectivity at launch, not lazily on first view render —
    // "sessione mai attivata" è il fallimento più comune di questo spike.
    @StateObject private var connector = PhoneConnector.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connector)
        }
    }
}
