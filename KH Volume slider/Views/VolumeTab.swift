//
//  VolumeSlider.swift
//  KH Volume slider
//
//  Created by Leander Blume on 26.01.25.
//

import SwiftUI

struct VolumeTab: View {
    @Environment(KHAccess.self) private var khAccess: KHAccess

    var body: some View {
        @Bindable var khAccess = khAccess

        VStack {
            Text("\(Int(khAccess.state.volume)) dB")
            Slider(value: $khAccess.state.volume, in: 0...120, step: 3) {
                Text("")
            } minimumValueLabel: {
                Text("0")
            } maximumValueLabel: {
                Text("120")
            } onEditingChanged: { editing in
                if !editing {
                    Task {
                        await khAccess.send()
                    }
                }
            }
            .disabled(!khAccess.status.isClean())

            #if os(iOS)
            // Text("\(Int(khAccess.volume))")

            Stepper("+/- 3 db", value: $khAccess.state.volume, in: 0...120, step: 3) {
                editing in
                if editing {
                    return
                }
                Task {
                    await khAccess.send()
                }
            }
            #endif

            Toggle(
                "Mute",
                systemImage: "speaker.slash.fill",
                isOn: $khAccess.state.muted
            )
            .toggleStyle(.button)
            .onChange(of: khAccess.state.muted) {
                Task {
                    await khAccess.send()
                }
            }
            .disabled(!khAccess.status.isClean())
        }
    }
}
