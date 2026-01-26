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
    @Environment(\.openWindow) private var openWindow

    @ViewBuilder
    var macOSButtonBar: some View {
        HStack {
            Button("Fetch") { Task { await khAccess.fetch() } }
                .disabled(khAccess.status.isBusy())

            Button("Rescan") {
                Task {
                    await khAccess.scan()
                    await khAccess.setup()
                }
            }
            .disabled(khAccess.status.isBusy())

            Button("Browse") { openWindow(id: "tree-viewer") }
            Spacer()
            StatusDisplay(status: khAccess.status)
            #if os(macOS)
                Button("Quit") { NSApplication.shared.terminate(nil) }
            #endif
        }
    }

    @ToolbarContentBuilder
    var standardToolbar: some ToolbarContent {
        #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                StatusDisplayCompact(status: khAccess.status)
            }
        #endif
        ToolbarItemGroup {
            HStack {
                Button("Rescan") {
                    Task {
                        await khAccess.scan()
                        await khAccess.setup()
                    }
                }
                Divider()
                Button("Fetch", systemImage: "arrow.clockwise") {
                    Task { await khAccess.fetch() }
                }
                .disabled(khAccess.devices.isEmpty)
            }
            .disabled(khAccess.status.isBusy())
        }
    }

    @ToolbarContentBuilder
    var browserToolbar: some ToolbarContent {
        #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                StatusDisplayCompact(status: khAccess.status)
            }
        #endif
        ToolbarItem {
            Button("Query parameters") {
                Task { await khAccess.populateParameters() }
            }
        }
    }

    var body: some View {
        #if os(iOS)
            TabView {
                Tab("Volume", systemImage: "speaker.wave.3") {
                    NavigationStack {
                        VolumeTab()
                            .scenePadding()
                            .disabled(!khAccess.status.isClean())
                            .toolbar { standardToolbar }
                    }
                }
                Tab("DSP", systemImage: "slider.vertical.3") {
                    NavigationView {
                        EqTab()
                            .scenePadding()
                            .disabled(!khAccess.status.isClean())
                            .toolbar { standardToolbar }
                    }
                }
                Tab("Hardware", systemImage: "hifispeaker") {
                    // .keyboard-placed toolbars don't show up in NavigationStack due to a bug, so we have to fall back to NavigationView.
                    NavigationView {
                        HardwareTab()
                            .scenePadding()
                            .disabled(!khAccess.status.isClean())
                            .toolbar { standardToolbar }
                    }
                }
                Tab("Browser", systemImage: "list.bullet.indent") {
                    NavigationStack {
                        ParameterTab()
                            .toolbar { browserToolbar }
                    }
                }
                Tab("Backup", systemImage: "heart") {
                    NavigationStack {
                        BackupView()
                            .toolbar { browserToolbar }
                    }
                }
            }
            .onAppear { Task { await khAccess.setup() } }
        #elseif os(macOS)
            TabView {
                Tab("Volume", systemImage: "speaker.wave.3") {
                    VolumeTab()
                        .scenePadding()
                        .disabled(!khAccess.status.isClean())
                }
                Tab("DSP", systemImage: "slider.vertical.3") {
                    EqTab()
                        .scenePadding()
                        .disabled(!khAccess.status.isClean())
                }
                Tab("Hardware", systemImage: "hifispeaker") {
                    HardwareTab()
                        .scenePadding()
                        .disabled(!khAccess.status.isClean())
                }
                Tab("Browser", systemImage: "list.bullet.indent") {
                    ParameterTab()
                        .scenePadding()
                }
                Tab("Backup", systemImage: "heart") {
                    BackupView()
                        .scenePadding()
                }
            }
            .onAppear { Task { await khAccess.setup() } }
            .scenePadding()
            .frame(minWidth: 450)

            macOSButtonBar.scenePadding()
        #endif
    }
}

#Preview {
    ContentView().environment(KHAccess())
}
