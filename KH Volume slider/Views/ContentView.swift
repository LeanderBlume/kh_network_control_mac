//
//  ContentView.swift
//  KH Volume slider
//
//  Created by Leander Blume on 21.12.24.
//

import Foundation
import SwiftUI

struct ContentView: View {
    @Environment(KHAccess.self) private var khAccess: KHAccess
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack {
            #if os(iOS)
                ZStack(alignment: .center) {
                    StatusDisplay(status: khAccess.status)

                    HStack {
                        Button("Fetch") {
                            Task {
                                await khAccess.fetch()
                            }
                        }

                        Spacer()

                        Button("Rescan") {
                            Task {
                                await khAccess.scan()
                                await khAccess.setup()
                            }
                        }
                    }
                    .disabled(khAccess.status.isBusy())
                }
                .scenePadding()
            #endif

            TabView {
                Tab("Volume", systemImage: "speaker.wave.3") {
                    VolumeTab()
                        .scenePadding()
                        .disabled(!khAccess.status.isClean())
                }
                Tab("DSP", systemImage: "slider.vertical.3") {
                    EqTab()
                        .scenePadding()
                        .disabled(!khAccess.status.isClean())
                }
                Tab("Hardware", systemImage: "hifispeaker") {
                    HardwareTab()
                        .scenePadding()
                        .disabled(!khAccess.status.isClean())
                }
                #if os(iOS)
                    Tab("Browser", systemImage: "list.bullet.indent") {
                        ParameterTab()
                    }
                #endif
                Tab("Backup", systemImage: "heart") {
                    Backupper()
                }
            }
            #if os(macOS)
                .scenePadding()
                .frame(minWidth: 450)
            #endif
            .onAppear {
                Task {
                    await khAccess.setup()
                }
            }
            .textFieldStyle(.roundedBorder)

            #if os(macOS)
                HStack {
                    Button("Fetch") {
                        Task {
                            await khAccess.fetch()
                        }
                    }
                    .disabled(khAccess.status.isBusy())

                    Button("Rescan") {
                        Task {
                            await khAccess.scan()
                            await khAccess.setup()
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
    ContentView().environment(KHAccess())
}
