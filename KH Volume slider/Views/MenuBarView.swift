import Foundation
import SwiftUI

struct MenuBarView: View {
    @Environment(KHAccess.self) private var khAccess: KHAccess
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @ViewBuilder
    var buttonBarTop: some View {
        @Bindable var khAccess = khAccess

        HStack {
            Spacer()

            Menu("Actions") {
                Button("Fetch", systemImage: "arrow.clockwise") {
                    Task { await khAccess.fetch() }
                }

                Button("Rescan", systemImage: "bonjour") {
                    Task {
                        await khAccess.scan()
                        await khAccess.setup()
                    }
                }

                Button("Clear cache", systemImage: "clear") {
                    Task {
                        try SchemaCache().clear()
                        try StateCache().clear()
                        // await khAccess.scan()
                        await khAccess.setup()
                    }
                }
            }
        }
        .disabled(khAccess.status.isBusy())
    }

    @ViewBuilder
    var buttonBarBottom: some View {
        HStack {
            StatusDisplay(status: khAccess.status)

            Spacer()

            Button("Main window", systemImage: "link") {
                openWindow(id: "main-window")
                dismissWindow()
            }

            #if os(macOS)
                Button("Quit") { NSApplication.shared.terminate(nil) }
            #endif
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
                        isOn: $khAccess.state.muted
                    )
                    .toggleStyle(.button)
                    // .toggleStyle(.switch)
                    .onChange(of: khAccess.state.muted) {
                        Task { await khAccess.send() }
                    }
                    .disabled(khAccess.status != .ready)
                    .labelsHidden()
                }
                GridRow {
                    Text("Volume")

                    Slider(value: $khAccess.state.volume, in: 0...120, step: 3) {
                        editing in
                        if !editing { Task { await khAccess.send() } }
                    }

                    TextField(
                        "Volume",
                        value: $khAccess.state.volume,
                        format: .number.precision(.fractionLength(1))
                    )
                    .frame(width: 80)
                    .onSubmit { Task { await khAccess.send() } }
                    .labelsHidden()
                }
                GridRow {
                    Text("Logo")

                    Slider(value: $khAccess.state.logoBrightness, in: 0...125, step: 5)
                    { editing in
                        if !editing { Task { await khAccess.send() } }
                    }

                    TextField(
                        "Logo",
                        value: $khAccess.state.logoBrightness,
                        format: .number.rounded()
                    )
                    .frame(width: 80)
                    .onSubmit { Task { await khAccess.send() } }
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

#Preview {
    MenuBarView().environment(KHAccess())
}
