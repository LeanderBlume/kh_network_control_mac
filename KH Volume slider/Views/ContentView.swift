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
    @State private var showError: Bool = false

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
                Button {
                    showError.toggle()
                } label: {
                    StatusDisplayCompact(status: khAccess.status)
                        .popover(
                            isPresented: $showError,
                            attachmentAnchor: .point(.bottom)
                        ) {
                            StatusDisplayText(status: khAccess.status)
                                .padding(.horizontal)
                                .presentationCompactAdaptation(.popover)
                        }
                }
            }
        #endif
        ToolbarItemGroup(placement: .secondaryAction) {
            Button("Rescan", systemImage: "bonjour") {
                Task {
                    await khAccess.scan()
                    await khAccess.setup()
                }
            }
            .disabled(khAccess.status.isBusy())
            Button("Fetch parameters", systemImage: "square.and.arrow.down") {
                Task { await khAccess.fetchParameters() }
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Fetch", systemImage: "arrow.clockwise") {
                Task { await khAccess.fetch() }
            }
            .disabled(khAccess.devices.isEmpty || khAccess.status.isBusy())
        }
    }

    @ToolbarContentBuilder
    var standardToolbarMacOS: some ToolbarContent {
        ToolbarItem(placement: .status) {
            StatusDisplayCompact(status: khAccess.status).frame(width: 37)
        }
        ToolbarItem {
            Button("Rescan", systemImage: "bonjour") {
                Task {
                    await khAccess.scan()
                    await khAccess.setup()
                }
            }
            .disabled(khAccess.status.isBusy())
        }
        ToolbarItem {
            Button("Fetch", systemImage: "arrow.clockwise") {
                Task { await khAccess.fetch() }
            }
            .disabled(khAccess.devices.isEmpty || khAccess.status.isBusy())
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
            Button("Fetch parameters") {
                Task { await khAccess.fetchParameters() }
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
                            .toolbar { standardToolbar }
                    }
                }
                Tab("Backup", systemImage: "heart") {
                    NavigationStack {
                        BackupView()
                            .toolbar { standardToolbar }
                    }
                }
            }
            .onAppear { Task { await khAccess.setup() } }
        #elseif os(macOS)
            TabView {
                Tab("Main", systemImage: "speaker.wave.3") {
                    MainTab()
                        .scenePadding()
                        .disabled(!khAccess.status.isClean())
                }
                Tab("DSP", systemImage: "slider.vertical.3") {
                    EqTab()
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
            .toolbar { standardToolbarMacOS }

        // macOSButtonBar.scenePadding()
        #endif
    }
}

#Preview {
    ContentView().environment(KHAccess())
}
