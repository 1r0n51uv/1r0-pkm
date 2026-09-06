//
//  _r0_pkmApp.swift
//  1r0-pkm
//
//  Created by 1r0n51uv on 05/09/26.
//

import SwiftUI

@main
struct _r0_pkmApp: App {
    // Activate WatchConnectivity at launch, not lazily on first view render —
    // "sessione mai attivata" è il fallimento più comune di questo spike (issue #1).
    @StateObject private var connector = PhoneConnector.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connector)
        }
    }
}
