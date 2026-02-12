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

    var body: some View {
        Button {
            showError.toggle()
        } label: {
            if showError {
                StatusDisplay(status: status).padding(.trailing, 7)
            } else {
                StatusDisplayCompact(status: status)
            }
        }
    }
}

struct ToolbarFetchButton: View {
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
        Button("Fetch", systemImage: "arrow.clockwise") {
            Task { await khAccess.fetch() }
        }
        .disabled(khAccess.devices.isEmpty || khAccess.status.isBusy())
    }
}

struct ToolbarFetchParametersButton: View {
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
        Button("Fetch parameters", systemImage: "square.and.arrow.down") {
            Task { await khAccess.fetchParameterTree() }
        }
        .disabled(khAccess.devices.isEmpty || khAccess.status.isBusy())
    }
}

struct ToolbarRescanButton: View {
    @Environment(KHAccess.self) private var khAccess: KHAccess

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

struct MainToolbar: ToolbarContent {
    @Binding var showError: Bool
    @Environment(KHAccess.self) private var khAccess: KHAccess

    @ToolbarContentBuilder
    var bodyiOS: some ToolbarContent {
        #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                ToolbarStatusDisplay(status: khAccess.status, showError: $showError)
            }
        #endif
        ToolbarItem(placement: .secondaryAction) {
            ToolbarRescanButton()
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
            ToolbarRescanButton()
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
    @Environment(KHAccess.self) private var khAccess: KHAccess

    @ToolbarContentBuilder
    var bodyiOS: some ToolbarContent {
        #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                ToolbarStatusDisplay(status: khAccess.status, showError: $showError)
            }
        #endif
        ToolbarItem(placement: .secondaryAction) {
            ToolbarRescanButton()
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
        ToolbarItem(placement: .secondaryAction) {
            ToolbarRescanButton()
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
    @Environment(KHAccess.self) private var khAccess: KHAccess

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
            // .buttonStyle(.borderedProminent)
        }
    }
}
