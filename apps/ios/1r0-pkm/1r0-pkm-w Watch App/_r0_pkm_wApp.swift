//
//  _r0_pkm_wApp.swift
//  1r0-pkm-w Watch App
//

import SwiftUI

@main
struct _r0_pkm_w_Watch_AppApp: App {
    @StateObject private var model = WatchSessionModel()

    init() {
        _ = WatchConnector.shared   // attiva WatchConnectivity all'avvio
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(model)
        }
    }
}
