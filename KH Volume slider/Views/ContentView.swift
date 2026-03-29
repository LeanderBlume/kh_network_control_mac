//
//  ContentView.swift
//  KH Volume slider
//
//  Created by Leander Blume on 21.12.24.
//

import Foundation
import SwiftUI

struct ContentView: View {
    @Binding var commonState: KHState
    @Binding var deviceStates: [KHState]

    @Environment(KHAccess.self) private var khAccess: KHAccess
    @State private var showError: Bool = false

    var setupCallback: () async -> Void
    var fetchCallback: () async -> Void
    var sendCallback: () async -> Void
    var rescanCallback: () async -> Void
    var clearCacheCallback: () async -> Void

    var bodyiOS: some View {
        TabView {
            Tab("Controls", systemImage: "speaker.wave.3") {
                NavigationStack {
                    MainTab(
                        commonState: $commonState,
                        deviceStates: $deviceStates,
                        fetchCallback: fetchCallback,
                        sendCallback: sendCallback,
                        connectCallback: setupCallback,
                        rescanCallback: rescanCallback,
                        clearCacheCallback: clearCacheCallback
                    )
                    // toolbar is handled in Tab view
                    // .navigationTitle(Text("Controls"))
                }
            }
            Tab("Devices", systemImage: "list.bullet.indent") {
                NavigationStack {
                    DevicesView()
                        .toolbar {
                            BrowserToolbar(
                                showError: $showError,
                                fetchCallback: fetchCallback,
                                connectCallback: setupCallback,
                                rescanCallback: rescanCallback,
                                clearCacheCallback: clearCacheCallback
                            )
                        }
                    // .navigationTitle(Text("Device browser"))
                }
            }
            Tab("Backups", systemImage: "externaldrive") {
                NavigationStack {
                    BackupView(commonState: $commonState)
                        .toolbar {
                            BrowserToolbar(
                                showError: $showError,
                                fetchCallback: fetchCallback,
                                connectCallback: setupCallback,
                                rescanCallback: rescanCallback,
                                clearCacheCallback: clearCacheCallback
                            )
                        }
                    // .navigationTitle(Text("Backups"))
                }
            }
        }
        .onAppear { Task { await setupCallback() } }
    }

    var bodymacOS: some View {
        TabView {
            Tab("Controls", systemImage: "speaker.wave.3") {
                ScrollView {
                    MainTab(
                        commonState: $commonState,
                        deviceStates: $deviceStates,
                        fetchCallback: fetchCallback,
                        sendCallback: sendCallback,
                        connectCallback: setupCallback,
                        rescanCallback: rescanCallback,
                        clearCacheCallback: clearCacheCallback
                    )
                }
            }
            Tab("Devices", systemImage: "list.bullet.indent") {
                DevicesView()
                    .toolbar {
                        BrowserToolbar(
                            showError: $showError,
                            fetchCallback: fetchCallback,
                            connectCallback: setupCallback,
                            rescanCallback: rescanCallback,
                            clearCacheCallback: clearCacheCallback
                        )
                    }
            }
            Tab("Backups", systemImage: "externaldrive") {
                BackupView(commonState: $commonState)
                    .toolbar {
                        BrowserToolbar(
                            showError: $showError,
                            fetchCallback: fetchCallback,
                            connectCallback: setupCallback,
                            rescanCallback: rescanCallback,
                            clearCacheCallback: clearCacheCallback
                        )
                    }
            }
        }
        // .onAppear { Task { await setupCallback() } }
        .scenePadding()
        .frame(minWidth: 450, minHeight: 600)
    }

    var body: some View {
        #if os(iOS)
            bodyiOS
        #elseif os(macOS)
            bodymacOS
        #endif
    }
}

#Preview {
    @Previewable @State var commonState = KHState(deviceID: nil)
    @Previewable @State var deviceStates: [KHState] = []
    let khAccess = KHAccess()

    ContentView(
        commonState: $commonState,
        deviceStates: $deviceStates,
        setupCallback: {
            await khAccess.setup()
            deviceStates = await khAccess.fetchAll()
            commonState = deviceStates.first ?? KHState(deviceID: nil)
        },
        fetchCallback: {
            deviceStates = await khAccess.fetchAll()
            commonState = deviceStates.first ?? KHState(deviceID: nil)
        },
        sendCallback: {
            await khAccess.send(commonState)
        },
        rescanCallback: {
            await khAccess.scan()
            await khAccess.setup()
            deviceStates = await khAccess.fetchAll()
            commonState = deviceStates.first ?? KHState(deviceID: nil)
        },
        clearCacheCallback: {
            do {
                try SchemaCache().clear()
                try StateCache().clear()
                await khAccess.setup()
                deviceStates = await khAccess.fetchAll()
                commonState = deviceStates.first ?? KHState(deviceID: nil)
            } catch {
                print("Failed to clear cache with error:", error)
            }
        }
    ).environment(khAccess)

    let _ = Task { await khAccess.setup() }
}
