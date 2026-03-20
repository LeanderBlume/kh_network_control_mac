//
//  Toolbars.swift
//  KH Volume slider
//
//  Created by Leander Blume on 12.02.26.
//
import SwiftUI

struct ToolbarStatusDisplay: View {
    var status: KHDeviceStatus
    @Binding var showError: Bool
    @EnvironmentObject private var khAccess: KHAccess

    var body: some View {
        Button {
            showError.toggle()
        } label: {
            StatusDisplayCompact(status: status)
        }
        .sheet(isPresented: $showError) {
            VStack {
                ScrollView {
                    VStack(alignment: .leading) {
                        if khAccess.devices.isEmpty {
                            StatusDisplay(status: status)
                                .padding(.bottom, 10)
                        }
                        ForEach(
                            khAccess.devices.sorted { $0.state.name < $1.state.name }
                        ) { device in
                            let ds = device.status
                            HStack {
                                Text("Status of device \"\(device.state.name)\":")
                                    .font(.title2)
                                Spacer()
                                StatusDisplayCompact(status: ds)
                            }
                            .padding(.bottom, 5)

                            StatusDisplayText(status: ds)
                                .padding(.bottom, 10)
                        }
                    }
                }

                Button("Dismiss") { showError.toggle() }
                    .padding(.top, 10)
            }
            .scenePadding()
            .presentationDetents([.medium])
        }
        .help("Show status")
    }
}

struct ToolbarFetchButton: View {
    @EnvironmentObject private var khAccess: KHAccess

    var body: some View {
        Button("Refresh", systemImage: "arrow.clockwise") {
            Task { await khAccess.fetch() }
        }
        .disabled(khAccess.devices.isEmpty || khAccess.status.isBusy())
    }
}

struct ToolbarFetchParametersButton: View {
    @EnvironmentObject private var khAccess: KHAccess

    var body: some View {
        Button("Fetch parameters", systemImage: "square.and.arrow.down") {
            Task { await khAccess.fetchParameterTree() }
        }
        .disabled(khAccess.devices.isEmpty || khAccess.status.isBusy())
    }
}

struct ToolbarRescanButton: View {
    @EnvironmentObject private var khAccess: KHAccess

    var body: some View {
        Button("Rescan", systemImage: "bonjour") {
            Task {
                await khAccess.scan()
                await khAccess.setup()
            }
        }
        .disabled(khAccess.status.isBusy())
        .help("Scan for devices")
    }
}

struct ToolbarClearCacheButton: View {
    @EnvironmentObject private var khAccess: KHAccess

    var body: some View {
        Button("Clear cache", systemImage: "clear") {
            Task {
                try SchemaCache().clear()
                try StateCache().clear()
                await khAccess.setup()
            }
        }
        .help("Clear device schema and state cache")
    }
}

struct MainToolbar: ToolbarContent {
    @Binding var showError: Bool
    @EnvironmentObject private var khAccess: KHAccess

    @ToolbarContentBuilder
    var bodyiOS: some ToolbarContent {
        #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                ToolbarStatusDisplay(status: khAccess.status, showError: $showError)
            }
        #endif
        ToolbarItemGroup(placement: .secondaryAction) {
            ToolbarFetchButton()
            ToolbarFetchParametersButton()
            ToolbarRescanButton()
            ToolbarClearCacheButton()
        }
        ToolbarItem(placement: .primaryAction) {
            ToolbarFetchButton()
        }
    }

    @ToolbarContentBuilder
    var bodyMacOS: some ToolbarContent {
        ToolbarItem(placement: .status) {
            ToolbarStatusDisplay(status: khAccess.status, showError: $showError)
        }
        ToolbarItemGroup(placement: .secondaryAction) {
            ToolbarFetchParametersButton()
            ToolbarRescanButton()
            ToolbarClearCacheButton()
        }
        ToolbarItem(placement: .primaryAction) {
            ToolbarFetchButton()
        }
    }

    var body: some ToolbarContent {
        #if os(iOS)
            bodyiOS
        #elseif os(macOS)
            bodyMacOS
        #endif
    }
}

struct BrowserToolbar: ToolbarContent {
    @Binding var showError: Bool
    @EnvironmentObject private var khAccess: KHAccess

    @ToolbarContentBuilder
    var bodyiOS: some ToolbarContent {
        #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                ToolbarStatusDisplay(status: khAccess.status, showError: $showError)
            }
        #endif
        ToolbarItemGroup(placement: .secondaryAction) {
            ToolbarFetchButton()
            ToolbarFetchParametersButton()
            ToolbarRescanButton()
            ToolbarClearCacheButton()
        }
        ToolbarItem(placement: .primaryAction) {
            ToolbarFetchParametersButton()
        }
    }

    @ToolbarContentBuilder
    var bodyMacOS: some ToolbarContent {
        ToolbarItem(placement: .status) {
            ToolbarStatusDisplay(status: khAccess.status, showError: $showError)
        }
        ToolbarItemGroup(placement: .secondaryAction) {
            ToolbarFetchButton()
            ToolbarRescanButton()
            ToolbarClearCacheButton()
        }
        ToolbarItem(placement: .primaryAction) {
            ToolbarFetchParametersButton()
        }
    }

    var body: some ToolbarContent {
        #if os(iOS)
            bodyiOS
        #elseif os(macOS)
            bodyMacOS
        #endif
    }
}

// iOS only
struct ToolbarDoneAndCancel: ToolbarContent {
    @FocusState.Binding var textFieldFocused: Bool
    @EnvironmentObject private var khAccess: KHAccess

    var body: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Done", systemImage: "checkmark") {
                Task { await khAccess.send() }
                textFieldFocused = false
            }
            .buttonStyle(.borderedProminent)
        }
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", systemImage: "keyboard.chevron.compact.down") {
                textFieldFocused = false
            }
        }
    }
}
