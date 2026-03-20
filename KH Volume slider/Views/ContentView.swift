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

    @ViewBuilder
    var bodyiOS: some View {
        TabView {
            NavigationStack {
                MainTabiOS()
                /// toolbar is handled in Tab view because of focus state dependency
                // .navigationTitle(Text("Controls"))
            }
            .tabItem {
                Label("Controls", systemImage: "speaker.wave.3")
            }

            NavigationStack {
                DevicesView()
                    .toolbar { BrowserToolbar(showError: $showError) }
                // .navigationTitle(Text("Device browser"))
            }
            .tabItem {
                Label("Devices", systemImage: "list.bullet.indent")
            }

            NavigationStack {
                BackupView()
                    .toolbar { BrowserToolbar(showError: $showError) }
                // .navigationTitle(Text("Backups"))
            }
            .tabItem {
                Label("Backups", systemImage: "externaldrive")
            }
        }
        // .onAppear { Task { await khAccess.setup() } }
    }

    @ViewBuilder
    var bodymacOS: some View {
        TabView {
            ScrollView {
                MainTabmacOS()
            }
            .tabItem {
                Label("Controls", systemImage: "speaker.wave.3")
            }

            DevicesView()
                .toolbar { BrowserToolbar(showError: $showError) }
                .tabItem {
                    Label("Devices", systemImage: "list.bullet.indent")
                }

            BackupView()
                .toolbar { BrowserToolbar(showError: $showError) }
                .tabItem {
                    Label("Backups", systemImage: "externaldrive")
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
    ContentView().environment(KHAccess())
}
