import SwiftUI

@main
struct OneRoSpikeWatchApp: App {
    // Activate WatchConnectivity at launch, come lato iPhone.
    @StateObject private var connector = WatchConnector.shared

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(connector)
        }
    }
}
