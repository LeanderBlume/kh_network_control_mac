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
    @Environment(KHAccess.self) private var khAccess: KHAccess

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
                                Text("Device: \(device.state.name)")
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
    @Binding var khState: KHState
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
        Button("Refresh", systemImage: "arrow.clockwise") {
            Task { khState = await khAccess.fetch() }
        }
        .disabled(khAccess.devices.isEmpty || khAccess.status.isBusy())
        .help("Quick refresh")
    }
}

struct ToolbarFetchParametersButton: View {
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
        Button("Fetch parameters", systemImage: "square.and.arrow.down") {
            Task { await khAccess.fetchParameterTree() }
        }
        .disabled(khAccess.devices.isEmpty || khAccess.status.isBusy())
        .help("Fetch full parameter trees")
    }
}

struct ToolbarRescanButton: View {
    @Binding var khState: KHState
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
        Button("Rescan", systemImage: "bonjour") {
            Task {
                await khAccess.scan()
                khState = await khAccess.setup()
            }
        }
        .disabled(khAccess.status.isBusy())
        .help("Scan for devices")
    }
}

struct ToolbarClearCacheButton: View {
    @Binding var khState: KHState
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
        Button("Clear cache", systemImage: "trash") {
            Task {
                try SchemaCache().clear()
                try StateCache().clear()
                khState = await khAccess.setup()
            }
        }
        .help("Clear device schema and state cache")
    }
}

struct ToolbarConnectButton: View {
    @Binding var khState: KHState
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
        Button("Connect", systemImage: "arrowtriangle.right") {
            Task {
                khState = await khAccess.setup()
            }
        }
        .disabled(khAccess.status.isBusy())
        .help("Connect (re-run setup)")
    }
}

struct MainToolbar: ToolbarContent {
    @Binding var khState: KHState
    @Binding var showError: Bool
    @Environment(KHAccess.self) private var khAccess: KHAccess

    @ToolbarContentBuilder
    var bodyiOS: some ToolbarContent {
        #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                ToolbarStatusDisplay(status: khAccess.status, showError: $showError)
            }
        #endif
        ToolbarItemGroup(placement: .secondaryAction) {
            ToolbarFetchButton(khState: $khState)
            // ToolbarFetchParametersButton()

            ToolbarConnectButton(khState: $khState)
            ToolbarRescanButton(khState: $khState)
            ToolbarClearCacheButton(khState: $khState)
        }
        ToolbarItem(placement: .primaryAction) {
            ToolbarFetchButton(khState: $khState)
        }
    }

    @ToolbarContentBuilder
    var bodyMacOS: some ToolbarContent {
        ToolbarItem(placement: .status) {
            ToolbarStatusDisplay(status: khAccess.status, showError: $showError)
        }
        ToolbarItemGroup(placement: .secondaryAction) {
            // ToolbarFetchParametersButton()

            ToolbarConnectButton(khState: $khState)
            ToolbarRescanButton(khState: $khState)
            ToolbarClearCacheButton(khState: $khState)
        }
        ToolbarItem(placement: .primaryAction) {
            ToolbarFetchButton(khState: $khState)
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
    @Binding var khState: KHState
    @Binding var showError: Bool
    @Environment(KHAccess.self) private var khAccess: KHAccess

    @ToolbarContentBuilder
    var bodyiOS: some ToolbarContent {
        #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                ToolbarStatusDisplay(status: khAccess.status, showError: $showError)
            }
        #endif
        ToolbarItemGroup(placement: .secondaryAction) {
            // ToolbarFetchButton()
            ToolbarFetchParametersButton()

            ToolbarConnectButton(khState: $khState)
            ToolbarRescanButton(khState: $khState)
            ToolbarClearCacheButton(khState: $khState)
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
            // ToolbarFetchButton()

            ToolbarConnectButton(khState: $khState)
            ToolbarRescanButton(khState: $khState)
            ToolbarClearCacheButton(khState: $khState)
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

    var body: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Done", systemImage: "checkmark") {
                // Task { await khAccess.send() }
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
