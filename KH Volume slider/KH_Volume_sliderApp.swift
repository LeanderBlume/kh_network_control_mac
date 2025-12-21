//
//  KH_Volume_sliderApp.swift
//  KH Volume slider
//
//  Created by Leander Blume on 21.12.24.
//

import SwiftUI

@main
struct KH_Volume_sliderApp: App {
    var body: some Scene {
        #if os(macOS)
        MenuBarExtra("KH Volume slider", systemImage: "hifispeaker.2") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
        Settings {
            SettingsView()
        }
        #elseif os(iOS)
        WindowGroup {
            ContentView()
        }
        #endif
        WindowGroup(id: "tree-viewer") {
            SSCTreeView()
        }
    }
}
