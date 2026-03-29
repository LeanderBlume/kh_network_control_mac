import Foundation
import SwiftUI

struct MenuBarView: View {
    @Binding var commonState: KHState
    @Environment(KHAccess.self) private var khAccess: KHAccess
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    
    func setup() async {
        await khAccess.setup()
        await fetch()
    }

    func fetch() async {
        commonState = await khAccess.fetch()
    }

    func rescan() async {
        await khAccess.scan()
        await setup()
    }

    func clearCache() async {
        do {
            try SchemaCache().clear()
            try StateCache().clear()
        } catch {
            print("Failed to clear cache with error:", error)
            return
        }
        await setup()
    }

    @ViewBuilder
    var buttonBarTop: some View {
        @Bindable var khAccess = khAccess

        HStack {
            Button("Main window", systemImage: "macwindow") {
                openWindow(id: "main-window")
                dismissWindow()
                #if os(macOS)
                    NSApp.activate()
                #endif
            }

            Spacer()

            Menu("Actions") {
                ToolbarFetchButton(fetchCallback: fetch)
                ToolbarConnectButton(connectCallback: setup)
                ToolbarRescanButton(rescanCallback: rescan)
                ToolbarClearCacheButton(clearCacheCallback: clearCache)

                #if os(macOS)
                    Button("Quit", systemImage: "xmark.rectangle") {
                        NSApplication.shared.terminate(nil)
                    }
                #endif
            }
        }
        .disabled(khAccess.status.isBusy())
    }

    @ViewBuilder
    var buttonBarBottom: some View {
        HStack {
            StatusDisplay(status: khAccess.status)
            Spacer()
        }
    }

    var body: some View {
        @Bindable var khAccess = khAccess

        VStack(spacing: 20) {
            buttonBarTop

            Grid(alignment: .leading) {
                GridRow {
                    Text("Mute")
                    Toggle(
                        "Toggle",
                        systemImage: "speaker.slash.fill",
                        isOn: $commonState.muted
                    )
                    /// toggleStyle .button might crash the app on macOS 15. Or maybe it's the other thing in the EQ tab.
                    // .toggleStyle(.button)
                    // .toggleStyle(.switch)
                    .onChange(of: commonState.muted) {
                        Task { await khAccess.sendToAll(commonState) }
                    }
                    .disabled(khAccess.status != .ready)
                    .labelsHidden()
                }
                GridRow {
                    Text("Volume")

                    Slider(value: $commonState.volume, in: 0...120, step: 3) {
                        editing in
                        if !editing { Task { await khAccess.sendToAll(commonState) } }
                    }

                    TextField(
                        "Volume",
                        value: $commonState.volume,
                        format: .number.precision(.fractionLength(1))
                    )
                    .frame(width: 80)
                    .onSubmit { Task { await khAccess.sendToAll(commonState) } }
                    .labelsHidden()
                }
                GridRow {
                    Text("Logo")

                    Slider(value: $commonState.logoBrightness, in: 0...125, step: 5)
                    { editing in
                        if !editing { Task { await khAccess.sendToAll(commonState) } }
                    }

                    TextField(
                        "Logo",
                        value: $commonState.logoBrightness,
                        format: .number.rounded()
                    )
                    .frame(width: 80)
                    .onSubmit { Task { await khAccess.sendToAll(commonState) } }
                    .labelsHidden()
                }
            }
            .disabled(khAccess.status != .ready)

            buttonBarBottom
        }
        .frame(minWidth: 350)
        .scenePadding()
        .onAppear { Task { await setup() } }
    }
}
