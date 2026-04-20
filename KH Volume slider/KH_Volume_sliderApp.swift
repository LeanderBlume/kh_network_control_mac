//
//  KH_Volume_sliderApp.swift
//  KH Volume slider
//
//  Created by Leander Blume on 21.12.24.
//

import SwiftUI

typealias ParameterPathDict = [DeviceModel: [String: [String]]]

@main
struct KH_Volume_sliderApp: App {
    @State private var khAccess: KHAccess
    @State private var stateManager: StateManager

    // decodes to ParameterPathDict
    @AppStorage("paths") private var paths: Data?

    init() {
        let khAccess = KHAccess()
        self.khAccess = khAccess
        stateManager = StateManager(khAccess)

        if let p = paths {
            if (try? JSONDecoder().decode(ParameterPathDict.self, from: p)) != nil {
                return
            }
        }
        // paths is either nil or in the wrong format, re-initialize it.
        do {
            paths = try JSONEncoder().encode(ParameterPathDict())
        } catch {
            print("Error encoding default paths:", error)
        }
    }

    var body: some Scene {
        #if os(macOS)
            MenuBarExtra("SSC Control", systemImage: "hifispeaker.2") {
                MenuBarView(stateManager: $stateManager)
                    .environment(khAccess)
            }
            .menuBarExtraStyle(.window)
        #endif
        WindowGroup(id: "main-window") {
            ContentView(stateManager: $stateManager)
                .environment(khAccess)
        }
        .defaultSize(width: 400, height: 400)
    }
}
