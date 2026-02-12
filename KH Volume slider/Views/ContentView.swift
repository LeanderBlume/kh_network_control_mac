//
//  ContentView.swift
//  KH Volume slider
//
//  Created by Leander Blume on 21.12.24.
//

import Foundation
import SwiftUI

struct ContentView: View {
    @Environment(KHAccess.self) private var khAccess: KHAccess
    @State private var showError: Bool = false

    var body: some View {
        #if os(iOS)
            TabView {
                Tab("Controls", systemImage: "speaker.wave.3") {
                    NavigationStack {
                        MainTabiOS()
                        // toolbar is handled in Tab view
                        // .navigationTitle(Text("Controls"))
                    }
                }
                Tab("Devices", systemImage: "list.bullet.indent") {
                    NavigationStack {
                        ParameterTab()
                            .toolbar { BrowserToolbar(showError: $showError) }
                        // .navigationTitle(Text("Device browser"))
                    }
                }
                Tab("Backups", systemImage: "externaldrive") {
                    NavigationStack {
                        BackupViewiOS()
                            .toolbar { BrowserToolbar(showError: $showError) }
                        // .navigationTitle(Text("Backups"))
                    }
                }
            }
            .onAppear { Task { await khAccess.setup() } }
        #elseif os(macOS)
            TabView {
                Tab("Controls", systemImage: "speaker.wave.3") {
                    ScrollView {
                        MainTabmacOS()
                    }
                }
                Tab("Devices", systemImage: "list.bullet.indent") {
                    ParameterTab()
                        .toolbar { BrowserToolbar(showError: $showError) }
                }
                Tab("Backups", systemImage: "externaldrive") {
                    BackupViewMacOS()
                        .toolbar { BrowserToolbar(showError: $showError) }
                }
            }
            .onAppear { Task { await khAccess.setup() } }
            .scenePadding()
            .frame(minWidth: 450)
        #endif
    }
}

#Preview {
    ContentView().environment(KHAccess())
}
