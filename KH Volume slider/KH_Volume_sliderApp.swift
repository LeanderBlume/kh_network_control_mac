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
    @State private var khAccess = KHAccess()
    @State var commonState = KHState()

    // decodes to ParameterPathDict
    @AppStorage("paths") private var paths: Data?

    init() {
        if let p = paths {
            if let _ = try? JSONDecoder().decode(ParameterPathDict.self, from: p) {
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
            MenuBarView(commonState: $commonState)
                .environment(khAccess)
        }
        .menuBarExtraStyle(.window)
        #endif
        WindowGroup(id: "main-window") {
            ContentView(commonState: $commonState)
                .environment(khAccess)
        }
        .defaultSize(width: 400, height: 400)
    }
}
