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
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Fetch parameters", systemImage: "square.and.arrow.down") {
                Task { await khAccess.fetchParameters() }
            }
            .disabled(khAccess.devices.isEmpty)
        }
    }

    @ToolbarContentBuilder
    var browserToolbarmacOS: some ToolbarContent {
        ToolbarItem(placement: .status) {
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
        ToolbarItemGroup(placement: .secondaryAction) {
            Button("Rescan", systemImage: "bonjour") {
                Task {
                    await khAccess.scan()
                    await khAccess.setup()
                }
            }
            .disabled(khAccess.status.isBusy())
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Fetch parameters", systemImage: "square.and.arrow.down") {
                Task { await khAccess.fetchParameters() }
            }
            .disabled(khAccess.devices.isEmpty)
        }
    }

    var body: some View {
        #if os(iOS)
            TabView {
                Tab("Controls", systemImage: "speaker.wave.3") {
                    NavigationStack {
                        MainTabiOS()
                        // .navigationTitle(Text("Controls"))
                    }
                }
                Tab("Devices", systemImage: "list.bullet.indent") {
                    NavigationStack {
                        ParameterTab()
                            // .navigationTitle(Text("Device browser"))
                            .toolbar { browserToolbar }
                    }
                }
                Tab("Backups", systemImage: "externaldrive") {
                    NavigationStack {
                        BackupView()
                        // .navigationTitle(Text("Backups"))
                        // .toolbar { standardToolbar }
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
                        .toolbar { browserToolbarmacOS }
                }
                Tab("Backups", systemImage: "externaldrive") {
                    BackupViewMacOS()
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
