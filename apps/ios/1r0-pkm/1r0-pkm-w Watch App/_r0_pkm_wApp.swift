//
//  _r0_pkm_wApp.swift
//  1r0-pkm-w Watch App
//
//  Created by 1r0n51uv on 05/09/26.
//

import SwiftUI

@main
struct _r0_pkm_w_Watch_AppApp: App {
    // Activate WatchConnectivity at launch, come lato iPhone.
    @StateObject private var connector = WatchConnector.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connector)
        }
    }
}
