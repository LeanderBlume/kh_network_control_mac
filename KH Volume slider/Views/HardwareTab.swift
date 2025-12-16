//
//  UIView2.swift
//  KH Volume slider
//
//  Created by Leander Blume on 26.01.25.
//

import SwiftUI

struct HardwareTab: View {
    @Bindable var khAccess: KHAccess

    var body: some View {
        #if os(macOS)
        HStack {
            Text("Logo brightness")
            Slider(value: $khAccess.logoBrightness, in: 0...125) {
                Text("")
            } onEditingChanged: { editing in
                if !editing {
                    Task {
                        try await khAccess.send()
                    }
                }
            }
            .disabled(!khAccess.status.isClean())

            TextField(
                "Logo brightness",
                value: $khAccess.logoBrightness,
                format: .number.precision(.fractionLength(0))
            )
            .frame(width: 80)
            .onSubmit {
                Task {
                    try await khAccess.send()
                }
            }
        }
        .scenePadding()
        #elseif os(iOS)
        VStack {
            Text("Logo brightness")
            
            HStack {
                Slider(value: $khAccess.logoBrightness, in: 0...125) {
                    Text("")
                } onEditingChanged: { editing in
                    if !editing {
                        Task {
                            try await khAccess.send()
                        }
                    }
                }
                .disabled(khAccess.status == .speakersUnavailable)
                
                TextField(
                    "Logo brightness",
                    value: $khAccess.logoBrightness,
                    format: .number.precision(.fractionLength(0))
                )
                .frame(width: 80)
                .onSubmit {
                    Task {
                        try await khAccess.send()
                    }
                }
            }
        }
        .scenePadding()
        #endif
    }
}
