//
//  ContentView.swift
//  1r0-pkm-w Watch App
//
//  Wrapper storico — la UI vera è WatchRootView.
//

import SwiftUI

struct ContentView: View {
    var body: some View { WatchRootView() }
}

#Preview {
    WatchRootView().environmentObject(WatchSessionModel())
}
