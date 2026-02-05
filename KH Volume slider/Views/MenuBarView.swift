import Foundation
import SwiftUI

struct MenuBarView: View {
    @Environment(KHAccess.self) private var khAccess: KHAccess
    @Environment(\.openWindow) private var openWindow

    @ViewBuilder
    var buttonBarTop: some View {
        @Bindable var khAccess = khAccess

        HStack {
            Button("Rescan", systemImage: "bonjour") {
                Task {
                    await khAccess.scan()
                    await khAccess.setup()
                }
            }
            
            Spacer()

            Button("Fetch", systemImage: "arrow.clockwise") {
                Task { await khAccess.fetch() }
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
                        "Muted",
                        systemImage: "speaker.slash.fill",
                        isOn: $khAccess.state.muted
                    )
                    // .toggleStyle(.button)
                    // .toggleStyle(.switch)
                    .onChange(of: khAccess.state.muted) {
                        Task { await khAccess.send() }
                    }
                    .disabled(khAccess.status != .ready)
                    .labelsHidden()
                }
                GridRow {
                    EqSlidermacOS(
                        name: "Volume",
                        value: $khAccess.state.volume,
                        range: 0...120
                    )
                }
                GridRow {
                    EqSlidermacOS(
                        name: "Logo",
                        value: $khAccess.state.logoBrightness,
                        range: 0...125
                    )
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
