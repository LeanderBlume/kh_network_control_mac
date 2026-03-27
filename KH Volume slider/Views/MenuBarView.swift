import Foundation
import SwiftUI

struct MenuBarView: View {
    @Binding var commonState: KHState
    @Environment(KHAccess.self) private var khAccess: KHAccess
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

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
                ToolbarFetchButton(commonState: $commonState)
                ToolbarConnectButton(commonState: $commonState)
                ToolbarRescanButton(commonState: $commonState)
                ToolbarClearCacheButton(commonState: $commonState)

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
                        Task { await khAccess.send(commonState) }
                    }
                    .disabled(khAccess.status != .ready)
                    .labelsHidden()
                }
                GridRow {
                    Text("Volume")

                    Slider(value: $commonState.volume, in: 0...120, step: 3) {
                        editing in
                        if !editing { Task { await khAccess.send(commonState) } }
                    }

                    TextField(
                        "Volume",
                        value: $commonState.volume,
                        format: .number.precision(.fractionLength(1))
                    )
                    .frame(width: 80)
                    .onSubmit { Task { await khAccess.send(commonState) } }
                    .labelsHidden()
                }
                GridRow {
                    Text("Logo")

                    Slider(value: $commonState.logoBrightness, in: 0...125, step: 5)
                    { editing in
                        if !editing { Task { await khAccess.send(commonState) } }
                    }

                    TextField(
                        "Logo",
                        value: $commonState.logoBrightness,
                        format: .number.rounded()
                    )
                    .frame(width: 80)
                    .onSubmit { Task { await khAccess.send(commonState) } }
                    .labelsHidden()
                }
            }
            .disabled(khAccess.status != .ready)

            buttonBarBottom
        }
        .frame(minWidth: 350)
        .scenePadding()
        .onAppear { Task { commonState = await khAccess.setup() } }
    }
}
