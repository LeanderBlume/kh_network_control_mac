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
    @Environment(KHAccess.self) private var khAccess: KHAccess
    @State private var showError: Bool = false

    var bodyiOS: some View {
        TabView {
            Tab("Controls", systemImage: "speaker.wave.3") {
                NavigationStack {
                    MainTab(commonState: $commonState)
                    // toolbar is handled in Tab view
                    // .navigationTitle(Text("Controls"))
                }
            }
            Tab("Devices", systemImage: "list.bullet.indent") {
                NavigationStack {
                    DevicesView()
                        .toolbar {
                            BrowserToolbar(commonState: $commonState, showError: $showError)
                        }
                    // .navigationTitle(Text("Device browser"))
                }
            }
            Tab("Backups", systemImage: "externaldrive") {
                NavigationStack {
                    BackupView(commonState: $commonState)
                        .toolbar {
                            BrowserToolbar(commonState: $commonState, showError: $showError)
                        }
                    // .navigationTitle(Text("Backups"))
                }
            }
        }
        .onAppear { Task { commonState = await khAccess.setup() } }
    }

    var bodymacOS: some View {
        TabView {
            Tab("Controls", systemImage: "speaker.wave.3") {
                ScrollView {
                    MainTab(commonState: $commonState)
                }
            }
            Tab("Devices", systemImage: "list.bullet.indent") {
                DevicesView()
                    .toolbar {
                        BrowserToolbar(commonState: $commonState, showError: $showError)
                    }
            }
            Tab("Backups", systemImage: "externaldrive") {
                BackupView(commonState: $commonState)
                    .toolbar {
                        BrowserToolbar(commonState: $commonState, showError: $showError)
                    }
            }
        }
        // .onAppear { Task { await khAccess.setup() } }
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
    let _ = Task { khState = await khAccess.setup() }
}
