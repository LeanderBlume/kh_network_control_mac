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
            ScrollView {
                VStack(alignment: .leading) {
                    Text("Status")
                        .font(.title)
                        .padding(.bottom, 10)

                    if khAccess.devices.isEmpty {
                        StatusDisplay(status: status)
                            .padding(.bottom, 10)
                    }
                    ForEach(
                        khAccess.devices.sorted { $0.state.name < $1.state.name }
                    ) { device in
                        let ds = device.status
                        HStack {
                            Text(device.state.name)
                                .font(.title2)
                            Spacer()
                            StatusDisplayCompact(status: ds)
                        }
                        .padding(.bottom, 5)

                        StatusDisplayText(status: ds)
                            .padding(.bottom, 10)

                        if device.id != khAccess.devices.last?.id {
                            Divider()
                        }
                    }
                }
                .scenePadding()
            }
            .presentationDetents([.medium])
        }
        .help("Show status")
    }
}

struct ToolbarFetchButton: View {
    var fetchCallback: () async -> Void
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
        Button("Refresh", systemImage: "arrow.clockwise") {
            Task { await fetchCallback() }
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
    var rescanCallback: () async -> Void
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
        Button("Rescan", systemImage: "bonjour") {
            Task { await rescanCallback() }
        }
        .disabled(khAccess.status.isBusy())
        .help("Scan for devices")
    }
}

struct ToolbarClearCacheButton: View {
    var clearCacheCallback: () async -> Void
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
        Button("Clear cache", systemImage: "trash") {
            Task { await clearCacheCallback() }
        }
        .help("Clear device schema and state cache")
    }
}

struct ToolbarConnectButton: View {
    var connectCallback: () async -> Void
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
        Button("Connect", systemImage: "arrowtriangle.right") {
            Task { await connectCallback() }
        }
        .disabled(khAccess.status.isBusy())
        .help("Connect (re-run setup)")
    }
}

struct MainToolbar: ToolbarContent {
    @Binding var showError: Bool
    var stateManager: StateManager
    @Environment(KHAccess.self) private var khAccess: KHAccess

    @ToolbarContentBuilder
    var bodyiOS: some ToolbarContent {
        #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                ToolbarStatusDisplay(status: khAccess.status, showError: $showError)
            }
        #endif
        ToolbarItemGroup(placement: .secondaryAction) {
            ToolbarFetchButton(fetchCallback: stateManager.fetch)
            // ToolbarFetchParametersButton()

            ToolbarConnectButton(connectCallback: stateManager.setup)
            ToolbarRescanButton(rescanCallback: stateManager.rescan)
            ToolbarClearCacheButton(clearCacheCallback: stateManager.clearCache)
        }
        ToolbarItem(placement: .primaryAction) {
            ToolbarFetchButton(fetchCallback: stateManager.fetch)
        }
    }

    @ToolbarContentBuilder
    var bodyMacOS: some ToolbarContent {
        ToolbarItem(placement: .status) {
            ToolbarStatusDisplay(status: khAccess.status, showError: $showError)
        }
        ToolbarItemGroup(placement: .secondaryAction) {
            // ToolbarFetchParametersButton()

            ToolbarConnectButton(connectCallback: stateManager.setup)
            ToolbarRescanButton(rescanCallback: stateManager.rescan)
            ToolbarClearCacheButton(clearCacheCallback: stateManager.clearCache)
        }
        ToolbarItem(placement: .primaryAction) {
            ToolbarFetchButton(fetchCallback: stateManager.fetch)
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
    var stateManager: StateManager
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

            ToolbarConnectButton(connectCallback: stateManager.setup)
            ToolbarRescanButton(rescanCallback: stateManager.rescan)
            ToolbarClearCacheButton(clearCacheCallback: stateManager.clearCache)
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

            ToolbarConnectButton(connectCallback: stateManager.setup)
            ToolbarRescanButton(rescanCallback: stateManager.rescan)
            ToolbarClearCacheButton(clearCacheCallback: stateManager.clearCache)
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
    @FocusState.Binding var textFieldFocused: SSCParameter?
    var sendCallback: (SSCParameter) async -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Done", systemImage: "checkmark") {
                guard let p = textFieldFocused else {
                    print("Impossible case: No text field is focused.")
                    return
                }
                Task { await sendCallback(p) }
                textFieldFocused = nil
            }
            .buttonStyle(.borderedProminent)
        }
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", systemImage: "keyboard.chevron.compact.down") {
                textFieldFocused = nil
            }
        }
    }
}
