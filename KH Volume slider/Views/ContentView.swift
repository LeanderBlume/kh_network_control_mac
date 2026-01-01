//
//  ContentView.swift
//  KH Volume slider
//
//  Created by Leander Blume on 21.12.24.
//

import Foundation
import SwiftUI

struct ContentView: View {
    @State var khAccess: KHAccess

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack {
            #if os(iOS)
                ZStack(alignment: .center) {
                    StatusDisplay(status: khAccess.status)

                    HStack {
                        Button("Fetch") {
                            Task {
                                try await khAccess.fetch()
                            }
                        }

                        Spacer()

                        Button("Rescan") {
                            Task {
                                try await khAccess.scan()
                            }
                        }
                    }
                    .disabled(khAccess.status.isBusy())
                }
                .scenePadding()
            #endif

            TabView {
                Tab("Volume", systemImage: "speaker.wave.3") {
                    VolumeTab(khAccess: khAccess)
                        .scenePadding()
                        .disabled(!khAccess.status.isClean())
                }
                Tab("DSP", systemImage: "slider.vertical.3") {
                    EqPanel(khAccess: khAccess)
                        .scenePadding()
                        .disabled(!khAccess.status.isClean())
                }
                Tab("Hardware", systemImage: "hifispeaker") {
                    HardwareTab(khAccess: khAccess)
                        .scenePadding()
                        .disabled(!khAccess.status.isClean())
                }
                #if os(iOS)
                    Tab("Browser", systemImage: "list.bullet.indent") {
                        SSCTreeView(khAccess: khAccess)
                    }
                #endif
            }
            #if os(macOS)
                .scenePadding()
                .frame(minWidth: 450)
            #endif
            .onAppear {
                Task {
                    try await khAccess.checkSpeakersAvailable()
                    if khAccess.status.isClean() {
                        try await khAccess.fetch()
                    }
                }
            }
            .textFieldStyle(.roundedBorder)

            #if os(macOS)
                HStack {
                    Button("Fetch") {
                        Task {
                            try await khAccess.fetch()
                        }
                    }
                    .disabled(khAccess.status.isBusy())

                    Button("Rescan") {
                        Task {
                            try await khAccess.scan()
                        }
                    }
                    .disabled(khAccess.status.isBusy())

                    Button("Browse") {
                        openWindow(id: "tree-viewer")
                    }

                    Spacer()

                    StatusDisplay(status: khAccess.status)

                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                }
                .padding([.leading, .bottom, .trailing])
            #endif
        }
    }
}

#Preview {
    ContentView(khAccess: KHAccess())
}
