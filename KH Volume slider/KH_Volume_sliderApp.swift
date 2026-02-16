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

    // decodes to [String: [String]]
    @AppStorage("paths") private var paths: Data = Data()

    init() {
        do {
            paths = try JSONEncoder().encode(KHParameters.devicePathDictDefault())
        } catch {
            return
        }
    }

    var body: some Scene {
        #if os(macOS)
        MenuBarExtra("KH Volume slider", systemImage: "hifispeaker.2") {
            MenuBarView()
                .environment(khAccess)
        }
        .menuBarExtraStyle(.window)
        #endif
        WindowGroup(id: "main-window") {
            ContentView()
                .environment(khAccess)
        }
    }
}
