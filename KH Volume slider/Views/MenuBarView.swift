import Foundation
import SwiftUI

struct MenuBarView: View {
    @Binding var commonState: KHState
    @Binding var deviceStates: [KHState]

    @Environment(KHAccess.self) private var khAccess: KHAccess
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    func syncCommonToDeviceStates(_ p: SSCParameter) {
        deviceStates = deviceStates.map { state in
            p.copy(from: commonState, into: state)
        }
    }
    
    func syncDeviceStatesToCommon() {
        guard !deviceStates.isEmpty else { return }
        for p in SSCParameter.allDefaultParameters {
            if p.allEqual(deviceStates) {
                commonState = p.copy(from: deviceStates.first!, into: commonState)
            }
        }
    }

    func send(_ parameter: SSCParameter) async {
        syncCommonToDeviceStates(parameter)
        await khAccess.sendIndividual(deviceStates)
    }

    func setup() async {
        await khAccess.setup()
        await fetch()
    }

    func fetch() async {
        deviceStates = await khAccess.fetchAll().sorted(by: { $0.name < $1.name })
        syncDeviceStatesToCommon()
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

            let mismatchedParameters = Set(
                SSCParameter.allDefaultParameters.filter { !$0.allEqual(deviceStates) }
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
                        isOn: $commonState.muted
                    )
                    /// toggleStyle .button might crash the app on macOS 15. Or maybe it's the other thing in the EQ tab.
                    // .toggleStyle(.button)
                    // .toggleStyle(.switch)
                    .onChange(of: commonState.muted) {
                        Task { await send(.muted) }
                    }
                    .disabled(khAccess.status != .ready)
                    .labelsHidden()
                }
                GridRow {
                    Text("Volume")

                    Slider(value: $commonState.volume, in: 0...120, step: 3) {
                        editing in
                        if !editing { Task { await send(.volume) } }
                    }

                    TextField(
                        "Volume",
                        value: $commonState.volume,
                        format: .number.precision(.fractionLength(1))
                    )
                    .frame(width: 80)
                    .onSubmit { Task { await send(.volume) } }
                    .labelsHidden()
                }
                GridRow {
                    Text("Logo")

                    Slider(value: $commonState.logoBrightness, in: 0...125, step: 5) {
                        editing in
                        if !editing { Task { await send(.logoBrightness) } }
                    }

                    TextField(
                        "Logo",
                        value: $commonState.logoBrightness,
                        format: .number.rounded()
                    )
                    .frame(width: 80)
                    .onSubmit { Task { await send(.logoBrightness) } }
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
