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
            NavigationStack {
                MainTab(stateManager: $stateManager)
                // toolbar is handled in Tab view
                // .navigationTitle(Text("Controls"))
            }
            .tabItem {
                Label("Controls", systemImage: "speaker.wave.3")
            }

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
            .tabItem {
                Label("Devices", systemImage: "list.bullet.indent")
            }

            NavigationStack {
                SettingsView(stateManager: stateManager)
                    .toolbar {
                        BrowserToolbar(
                            showError: $showError,
                            stateManager: stateManager
                        )
                    }
                // .navigationTitle(Text("Backups"))
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
        .onAppear { Task { await stateManager.setup() } }
    }

    var bodymacOS: some View {
        TabView {
            ScrollView {
                MainTab(stateManager: $stateManager)
            }
            .tabItem {
                Label("Controls", systemImage: "speaker.wave.3")
            }

            DevicesView(stateManager: stateManager)
                .toolbar {
                    BrowserToolbar(
                        showError: $showError,
                        stateManager: stateManager
                    )
                }
                .tabItem {
                    Label("Devices", systemImage: "list.bullet.indent")
                }

            SettingsView(stateManager: stateManager)
                .toolbar {
                    BrowserToolbar(
                        showError: $showError,
                        stateManager: stateManager
                    )
                }
                .tabItem {
                    Label("Settings", systemImage: "gear")
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
