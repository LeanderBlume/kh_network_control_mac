//
//  ContentView.swift
//  KH Volume slider
//
//  Created by Leander Blume on 21.12.24.
//

import Foundation
import SwiftUI

typealias KHAccess = KHAccessDummy


struct ContentView: View {
    @State var khAccess = KHAccess()

    var body: some View {
        VStack {
            #if os(iOS)
            ZStack(alignment: .center) {
                StatusDisplay(status: khAccess.status)

                HStack {
                    Button("Fetch") {
                        Task {
                            try await khAccess.checkSpeakersAvailable()
                        }
                    }

                    Spacer()

                    Button("Rescan") {
                        Task {
                            khAccess.clearDevices()
                            try await khAccess.checkSpeakersAvailable()
                        }
                    }
                }
                .disabled(khAccess.status == .checkingSpeakerAvailability)
            }
            .scenePadding()
            #endif

            TabView {
                Tab("Volume", systemImage: "speaker.wave.3") {
                    VolumeTab(khAccess: khAccess)
                        .padding(.horizontal).padding(.bottom)
                        .disabled(khAccess.status != .clean)
                }
                Tab("DSP", systemImage: "slider.vertical.3") {
                    EqPanel(khAccess: khAccess)
                        .padding()
                        .disabled(khAccess.status != .clean)
                }
                Tab("Hardware", systemImage: "hifispeaker") {
                    HardwareTab(khAccess: khAccess)
                        .padding(.horizontal).padding(.bottom)
                        .disabled(khAccess.status != .clean)
                }
            }
            #if os(macOS)
            .scenePadding()
            .frame(minWidth: 450)
            #endif
            .onAppear {
                Task {
                    try await khAccess.checkSpeakersAvailable()
                }
            }
            .textFieldStyle(.roundedBorder)
            
            #if os(macOS)
            HStack {
                Button("Fetch") {
                    Task {
                        try await khAccess.checkSpeakersAvailable()
                    }
                }
                .disabled(khAccess.status == .checkingSpeakerAvailability)
                
                
                Button("Rescan") {
                    Task {
                        khAccess.clearDevices()
                        try await khAccess.checkSpeakersAvailable()
                    }
                }
                .disabled(khAccess.status == .checkingSpeakerAvailability)
                
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
    ContentView()
}
