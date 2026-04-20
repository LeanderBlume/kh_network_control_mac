import Foundation
import SwiftUI

struct MenuBarView: View {
    @Binding var stateManager: StateManager

    @Environment(KHAccess.self) private var khAccess: KHAccess
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    func fetch() async { await stateManager.fetch() }

    @ViewBuilder
    var buttonBarTop: some View {
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
                ToolbarConnectButton(connectCallback: { await stateManager.setup() })
                ToolbarRescanButton(rescanCallback: { await stateManager.rescan() })
                ToolbarClearCacheButton(clearCacheCallback: {
                    await stateManager.clearCache()
                })

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

            let mismatchedParameters = Set(
                SSCParameter.allDefaultParameters.filter {
                    !$0.allEqual(stateManager.deviceStates)
                }
            )
            let mps = [.muted, .volume, .logoBrightness].filter {
                mismatchedParameters.contains($0)
            }
            if !mps.isEmpty {
                Image(systemName: "info.circle")
                Text(
                    "Device mismatch: "
                        + mps.map({ $0.description() }).sorted().joined(separator: ", ")
                )
            }
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            buttonBarTop

            Grid(alignment: .leading) {
                GridRow {
                    Text("Mute")
                    Toggle(
                        "Toggle",
                        systemImage: "speaker.slash.fill",
                        isOn: $stateManager.commonState.muted
                    )
                    /// toggleStyle .button might crash the app on macOS 15. Or maybe it's the other thing in the EQ tab.
                    // .toggleStyle(.button)
                    // .toggleStyle(.switch)
                    .onChange(of: stateManager.commonState.muted) {
                        Task { await stateManager.sendToAll(.muted) }
                    }
                    .disabled(khAccess.status != .ready)
                    .labelsHidden()
                }
                GridRow {
                    Text("Volume")

                    Slider(value: $stateManager.commonState.volume, in: 0...120, step: 3) {
                        editing in
                        if !editing { Task { await stateManager.sendToAll(.volume) } }
                    }

                    TextField(
                        "Volume",
                        value: $stateManager.commonState.volume,
                        format: .number.precision(.fractionLength(1))
                    )
                    .frame(width: 80)
                    .onSubmit { Task { await stateManager.sendToAll(.volume) } }
                    .labelsHidden()
                }
                GridRow {
                    Text("Logo")

                    Slider(value: $stateManager.commonState.logoBrightness, in: 0...125, step: 5) {
                        editing in
                        if !editing { Task { await stateManager.sendToAll(.logoBrightness) } }
                    }

                    TextField(
                        "Logo",
                        value: $stateManager.commonState.logoBrightness,
                        format: .number.rounded()
                    )
                    .frame(width: 80)
                    .onSubmit { Task { await stateManager.sendToAll(.logoBrightness) } }
                    .labelsHidden()
                }
            }
            .disabled(khAccess.status != .ready)

            buttonBarBottom
        }
        .frame(minWidth: 350)
        .scenePadding()
        .onAppear { Task { await stateManager.setup() } }
    }
}
