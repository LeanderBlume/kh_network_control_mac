//
//  KH_Volume_sliderApp.swift
//  KH Volume slider
//
//  Created by Leander Blume on 21.12.24.
//

import SwiftUI

@main
struct KH_Volume_sliderApp: App {
    @State private var khAccess = KHAccess()
    
    var body: some Scene {
        #if os(macOS)
        MenuBarExtra("KH Volume slider", systemImage: "hifispeaker.2") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
        .environment(khAccess)
        
        Settings {
            SettingsView()
        }
        #elseif os(iOS)
        WindowGroup {
            ContentView()
        }
        .environment(khAccess)
        #endif
        WindowGroup("Parameters", id: "tree-viewer") {
            SSCTreeView()
        }
        .environment(khAccess)
    }
}
