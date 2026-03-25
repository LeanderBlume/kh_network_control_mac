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

    // decodes to ParameterPathDict
    @AppStorage("paths") private var paths: Data?

    init() {
        if paths != nil { return }
        let emptyDict = ParameterPathDict()
        do {
            paths = try JSONEncoder().encode(emptyDict)
        } catch {
            print("Error encoding default paths:", error)
            return
        }
    }

    var body: some Scene {
        #if os(macOS)
        MenuBarExtra("SSC Control", systemImage: "hifispeaker.2") {
            MenuBarView()
                .environment(khAccess)
        }
        .menuBarExtraStyle(.window)
        #endif
        WindowGroup(id: "main-window") {
            ContentView()
                .environment(khAccess)
        }
        .defaultSize(width: 400, height: 400)
    }
}
