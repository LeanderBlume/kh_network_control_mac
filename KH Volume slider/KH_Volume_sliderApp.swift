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
    @State var commonState = KHState(deviceID: nil)
    @State var deviceStates: [KHState] = []

    // decodes to ParameterPathDict
    @AppStorage("paths") private var paths: Data?

    init() {
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
    
    func fetch() async {
        deviceStates = await khAccess.fetchAll()
        commonState = deviceStates.first ?? KHState(deviceID: nil)
    }

    func setup() async {
        await khAccess.setup()
        await fetch()
    }

    func send() async {
        await khAccess.send(commonState)
    }

    func rescan() async {
        await khAccess.scan()
        await setup()
    }

    func clearCache() async {
        do {
            try SchemaCache().clear()
            try StateCache().clear()
        } catch {
            print("Failed to clear cache with error:", error)
            return
        }
        await setup()
    }

    var body: some Scene {
        #if os(macOS)
            MenuBarExtra("SSC Control", systemImage: "hifispeaker.2") {
                MenuBarView(
                    commonState: $commonState,
                    setupCallback: setup,
                    fetchCallback: fetch,
                    rescanCallback: rescan,
                    clearCacheCallback: clearCache,
                )
                .environment(khAccess)
            }
            .menuBarExtraStyle(.window)
        #endif
        WindowGroup(id: "main-window") {
            ContentView(
                commonState: $commonState,
                deviceStates: $deviceStates,
                setupCallback: setup,
                fetchCallback: fetch,
                sendCallback: send,
                rescanCallback: rescan,
                clearCacheCallback: clearCache,
            )
                .environment(khAccess)
        }
        .defaultSize(width: 400, height: 400)
    }
}
