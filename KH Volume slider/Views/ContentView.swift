//
//  ContentView.swift
//  KH Volume slider
//
//  Created by Leander Blume on 21.12.24.
//

import Foundation
import SwiftUI

struct ContentView: View {
    @Binding var stateManager: StateManager

    @Environment(KHAccess.self) private var khAccess: KHAccess
    @State private var showError: Bool = false

    var bodyiOS: some View {
        TabView {
            Tab("Controls", systemImage: "speaker.wave.3") {
                NavigationStack {
                    MainTab(stateManager: $stateManager)
                    // toolbar is handled in Tab view
                    // .navigationTitle(Text("Controls"))
                }
            }
            Tab("Devices", systemImage: "list.bullet.indent") {
                NavigationStack {
                    DevicesView(stateManager: stateManager)
                        .toolbar {
                            BrowserToolbar(
                                showError: $showError,
                                stateManager: stateManager
                            )
                        }
                    // .navigationTitle(Text("Device browser"))
                }
            }
            Tab("Backups", systemImage: "externaldrive") {
                NavigationStack {
                    BackupView(stateManager: stateManager)
                        .toolbar {
                            BrowserToolbar(
                                showError: $showError,
                                stateManager: stateManager
                            )
                        }
                    // .navigationTitle(Text("Backups"))
                }
            }
        }
        .onAppear { Task { await stateManager.setup() } }
    }

    var bodymacOS: some View {
        TabView {
            Tab("Controls", systemImage: "speaker.wave.3") {
                ScrollView {
                    MainTab(stateManager: $stateManager)
                }
            }
            Tab("Devices", systemImage: "list.bullet.indent") {
                DevicesView(stateManager: stateManager)
                    .toolbar {
                        BrowserToolbar(
                            showError: $showError,
                            stateManager: stateManager
                        )
                    }
            }
            Tab("Backups", systemImage: "externaldrive") {
                BackupView(stateManager: stateManager)
                    .toolbar {
                        BrowserToolbar(
                            showError: $showError,
                            stateManager: stateManager
                        )
                    }
            }
        }
        // .onAppear { Task { await setup() } }
        .scenePadding()
        .frame(minWidth: 450, minHeight: 600)
    }

    var body: some View {
        Group {
            #if os(iOS)
                bodyiOS
            #elseif os(macOS)
                bodymacOS
            #endif
        }
    }
}

#Preview {
    @Previewable @State var stateManager = StateManager(KHAccess())

    ContentView(stateManager: $stateManager)
        .environment(stateManager.khAccess)
}
