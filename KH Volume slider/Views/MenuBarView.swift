import Foundation
import SwiftUI

struct MenuBarView: View {
    @Binding var khState: KHState
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
                ToolbarFetchButton(khState: $khState)
                ToolbarConnectButton(khState: $khState)
                ToolbarRescanButton(khState: $khState)
                ToolbarClearCacheButton(khState: $khState)

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
                        isOn: $khState.muted
                    )
                    /// toggleStyle .button might crash the app on macOS 15. Or maybe it's the other thing in the EQ tab.
                    // .toggleStyle(.button)
                    // .toggleStyle(.switch)
                    .onChange(of: khState.muted) {
                        Task { await khAccess.send(khState) }
                    }
                    .disabled(khAccess.status != .ready)
                    .labelsHidden()
                }
                GridRow {
                    Text("Volume")

                    Slider(value: $khState.volume, in: 0...120, step: 3) {
                        editing in
                        if !editing { Task { await khAccess.send(khState) } }
                    }

                    TextField(
                        "Volume",
                        value: $khState.volume,
                        format: .number.precision(.fractionLength(1))
                    )
                    .frame(width: 80)
                    .onSubmit { Task { await khAccess.send(khState) } }
                    .labelsHidden()
                }
                GridRow {
                    Text("Logo")

                    Slider(value: $khState.logoBrightness, in: 0...125, step: 5)
                    { editing in
                        if !editing { Task { await khAccess.send(khState) } }
                    }

                    TextField(
                        "Logo",
                        value: $khState.logoBrightness,
                        format: .number.rounded()
                    )
                    .frame(width: 80)
                    .onSubmit { Task { await khAccess.send(khState) } }
                    .labelsHidden()
                }
            }
            .disabled(khAccess.status != .ready)

            buttonBarBottom
        }
        .frame(minWidth: 350)
        .scenePadding()
        .onAppear { Task { await khAccess.setup() } }
    }
}
