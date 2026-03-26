//
//  ContentView.swift
//  KH Volume slider
//
//  Created by Leander Blume on 21.12.24.
//

import Foundation
import SwiftUI

struct ContentView: View {
    @Binding var khState: KHState
    @Environment(KHAccess.self) private var khAccess: KHAccess
    @State private var showError: Bool = false

    var bodyiOS: some View {
        TabView {
            Tab("Controls", systemImage: "speaker.wave.3") {
                NavigationStack {
                    MainTab(khState: $khState)
                    // toolbar is handled in Tab view
                    // .navigationTitle(Text("Controls"))
                }
            }
            Tab("Devices", systemImage: "list.bullet.indent") {
                NavigationStack {
                    DevicesView()
                        .toolbar {
                            BrowserToolbar(khState: $khState, showError: $showError)
                        }
                    // .navigationTitle(Text("Device browser"))
                }
            }
            Tab("Backups", systemImage: "externaldrive") {
                NavigationStack {
                    BackupView(khState: $khState)
                        .toolbar {
                            BrowserToolbar(khState: $khState, showError: $showError)
                        }
                    // .navigationTitle(Text("Backups"))
                }
            }
        }
        .onAppear { Task { khState = await khAccess.setup() } }
    }

    var bodymacOS: some View {
        TabView {
            Tab("Controls", systemImage: "speaker.wave.3") {
                ScrollView {
                    MainTab(khState: $khState)
                }
            }
            Tab("Devices", systemImage: "list.bullet.indent") {
                DevicesView()
                    .toolbar {
                        BrowserToolbar(khState: $khState, showError: $showError)
                    }
            }
            Tab("Backups", systemImage: "externaldrive") {
                BackupView(khState: $khState)
                    .toolbar {
                        BrowserToolbar(khState: $khState, showError: $showError)
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
    ContentView(khState: $khState).environment(khAccess)
    let _ = Task { await khAccess.setup() }
}
