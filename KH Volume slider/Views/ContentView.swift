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
    @State var deviceStates: [KHState] = []

    @Environment(KHAccess.self) private var khAccess: KHAccess
    @State private var showError: Bool = false

    func setup() async {
        await khAccess.setup()
        await fetch()
    }

    func fetch() async {
        deviceStates = await khAccess.fetchAll()
        commonState = deviceStates.first ?? KHState()
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

    var bodyiOS: some View {
        TabView {
            Tab("Controls", systemImage: "speaker.wave.3") {
                NavigationStack {
                    MainTab(
                        commonState: $commonState,
                        deviceStates: $deviceStates,
                        fetchCallback: fetch,
                        sendCallback: send,
                        connectCallback: setup,
                        rescanCallback: rescan,
                        clearCacheCallback: clearCache
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
                                fetchCallback: fetch,
                                connectCallback: setup,
                                rescanCallback: rescan,
                                clearCacheCallback: clearCache
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
                                fetchCallback: fetch,
                                connectCallback: setup,
                                rescanCallback: rescan,
                                clearCacheCallback: clearCache
                            )
                        }
                    // .navigationTitle(Text("Backups"))
                }
            }
        }
        .onAppear { Task { await setup() } }
    }

    var bodymacOS: some View {
        TabView {
            Tab("Controls", systemImage: "speaker.wave.3") {
                ScrollView {
                    MainTab(
                        commonState: $commonState,
                        deviceStates: $deviceStates,
                        fetchCallback: fetch,
                        sendCallback: send,
                        connectCallback: setup,
                        rescanCallback: rescan,
                        clearCacheCallback: clearCache
                    )
                }
            }
            Tab("Devices", systemImage: "list.bullet.indent") {
                DevicesView()
                    .toolbar {
                        BrowserToolbar(
                            showError: $showError,
                            fetchCallback: fetch,
                            connectCallback: setup,
                            rescanCallback: rescan,
                            clearCacheCallback: clearCache
                        )
                    }
            }
            Tab("Backups", systemImage: "externaldrive") {
                BackupView(commonState: $commonState)
                    .toolbar {
                        BrowserToolbar(
                            showError: $showError,
                            fetchCallback: fetch,
                            connectCallback: setup,
                            rescanCallback: rescan,
                            clearCacheCallback: clearCache
                        )
                    }
            }
        }
        .onAppear { Task { await setup() } }
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
    @Previewable @State var khState = KHState()
    let khAccess = KHAccess()
    ContentView(commonState: $khState).environment(khAccess)
    let _ = Task {
        await khAccess.setup()
    }
}
